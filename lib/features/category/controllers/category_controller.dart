import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/category/domain/models/category_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/features/category/domain/services/category_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryController extends GetxController implements GetxService {
  final CategoryServiceInterface categoryServiceInterface;
  CategoryController({required this.categoryServiceInterface});

  // ============================================================
  //  CACHE KEYS + TTL — Static versioned keys
  // ============================================================
  static const String categoryCacheKey = "cache_categories_v1";
  static const String categoryCacheTimeKey = "cache_categories_timestamp";

  static String _subCategoryKey(int id) => 'cache_sub_categories_${id}_v1';
  static String _subCategoryTimeKey(int id) => 'cache_sub_categories_${id}_timestamp';

  static String _itemKey(int id, int page, String type) =>
      'cache_items_${id}_page_${page}_type_${type}_v1';
  static String _itemTimeKey(int id, int page, String type) =>
      'cache_items_${id}_page_${page}_type_${type}_timestamp';

  static String _storeKey(int id, int page, String type) =>
      'cache_stores_${id}_page_${page}_type_${type}_v1';
  static String _storeTimeKey(int id, int page, String type) =>
      'cache_stores_${id}_page_${page}_type_${type}_timestamp';

  // ============================================================
  //  STATE — أسماء المتغيرات العامة لم تتغير
  // ============================================================
  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  List<CategoryModel>? _subCategoryList;
  List<CategoryModel>? get subCategoryList => _subCategoryList;

  List<Item>? _categoryItemList;
  List<Item>? get categoryItemList => _categoryItemList;

  List<Store>? _categoryStoreList;
  List<Store>? get categoryStoreList => _categoryStoreList;

  List<Item>? _searchItemList = [];
  List<Item>? get searchItemList => _searchItemList;

  List<Store>? _searchStoreList = [];
  List<Store>? get searchStoreList => _searchStoreList;

  List<bool>? _interestSelectedList;
  List<bool>? get interestSelectedList => _interestSelectedList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _pageSize;
  int? get pageSize => _pageSize;

  int? _restPageSize;
  int? get restPageSize => _restPageSize;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  int _subCategoryIndex = 0;
  int get subCategoryIndex => _subCategoryIndex;

  String _type = 'all';
  String get type => _type;

  bool _isStore = false;
  bool get isStore => _isStore;

  String? _searchText = '';
  String? get searchText => _searchText;

  int _offset = 1;
  int get offset => _offset;

  // ============================================================
  //  NEW: منع تكرار الـ API Calls + حماية من Stale Responses
  // ============================================================
  // Single-flight flags (شاملة لكل النوع)
  bool _isRefreshingCategory = false;
  bool _isRefreshingSubCategory = false;

  // Per-key dedup لـ Items/Stores لتفادي block الـ categories المختلفة
  final Set<String> _inflightItemKeys = <String>{};
  final Set<String> _inflightStoreKeys = <String>{};

  // Generation token — يمنع الـ Stale Response من overwrite الـ UI
  int _itemsGeneration = 0;
  int _storesGeneration = 0;

  // حد أقصى لعدد Cache Entries قبل الـ Eviction
  // static const int _maxItemCacheEntries = 120;
  // static const int _maxStoreCacheEntries = 60;

  String _itemFlightKey(int id, int page, String type) =>
      'item_${id}_${page}_$type';
  String _storeFlightKey(int id, int page, String type) =>
      'store_${id}_${page}_$type';

  // ============================================================
  //  NEW: Search Debounce Timer (300ms)
  // ============================================================
  Timer? _searchDebounce;

  // ============================================================
  //  UNCHANGED — clearCategoryList
  // ============================================================
  void clearCategoryList() {
    _categoryList = null;
  }

  // ============================================================
  //  ⭐ MODIFIED: getCategoryList — SWR مع diff + dedupe
  // ============================================================
  Future<void> getCategoryList(bool reload, {bool allCategory = false, DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    if (_categoryList == null || reload || fromRecall) {
      if (reload) {
        _categoryList = null;
      }

      // ---------- PHASE 1: cache first ----------
      bool hasCache = false;
      List<CategoryModel>? cached = const [];

      if (dataSource == DataSourceEnum.local && !fromRecall) {
        cached = await getCategoryCache() ?? const [];
        if (cached.isNotEmpty) {
          _prepareCategoryList(cached);
          hasCache = true;
          if (kDebugMode) {
            print('[CATEGORY_CACHE] Loaded ${cached.length} categories');
          }
        }
      }

      if (!hasCache && dataSource == DataSourceEnum.local && !fromRecall) {
        _isLoading = true;
        update();
      }

      // ---------- PHASE 2: dedupe single-flight ----------
      if (_isRefreshingCategory) {
        if (_isLoading) {
          _isLoading = false;
          update();
        }
        return;
      }
      _isRefreshingCategory = true;

      try {
        // ---------- PHASE 3: background revalidation ----------
        final fresh = await categoryServiceInterface.getCategoryList(
          allCategory,
          source: DataSourceEnum.client,
        );

        if (fresh != null && fresh.isNotEmpty) {
          if (_hasCategoryListChanged(cached.isEmpty ? null : cached, fresh)) {
            await saveCategoryCache(fresh);
            _prepareCategoryList(fresh);
            if (kDebugMode) {
              print('[CATEGORY_API] Categories updated');
            }
          }
          // else: silent — no rebuild
        } else if (hasCache) {
          // API failed → silent offline mode
          if (kDebugMode) {
            print('[CATEGORY_CACHE] Offline Mode');
          }
        }
      } catch (_) {
        if (hasCache){
           if (kDebugMode) {
             print('[CATEGORY_CACHE] Offline Mode');
           }
        }
      } finally {
        _isRefreshingCategory = false;
        if (_isLoading) {
          _isLoading = false;
          update();
        }
      }
    }
  }

  // ============================================================
  //  ⭐ MODIFIED: _prepareCategoryList — clear()+addAll() + conditional update
  // ============================================================
  void _prepareCategoryList(List<CategoryModel>? categoryList) {
    if (categoryList == null) return;

    // Diff: تخطّي الـ rebuild لو البيانات ما تغيرتش — يحفظ GC + UI work
    if (!_hasCategoryListChanged(_categoryList, categoryList)) {
      return;
    }

    _categoryList ??= [];
    _categoryList!.clear();
    _categoryList!.addAll(categoryList);

    _interestSelectedList ??= [];
    _interestSelectedList!.clear();
    for (int i = 0; i < _categoryList!.length; i++) {
      _interestSelectedList!.add(false);
    }
    update();
  }

  bool _hasCategoryListChanged(List<CategoryModel>? old, List<CategoryModel>? fresh) {
    if (old == null || fresh == null) return true;
    if (old.length != fresh.length) return true;
    for (int i = 0; i < old.length; i++) {
      final o = old[i];
      final n = fresh[i];
      if (o.id != n.id || o.name != n.name || o.imageFullUrl != n.imageFullUrl) {
        return true;
      }
    }
    return false;
  }

  // ============================================================
  //  ⭐ MODIFIED: getSubCategoryList — SWR + per-ID cache
  // ============================================================
  Future<void> getSubCategoryList(String? categoryID) async {
    if (categoryID == null) return;
    _subCategoryIndex = 0;

    final id = int.tryParse(categoryID);
    if (id == null) return;

    // ---------- PHASE 1: cache first (per-category) ----------
    bool hasCache = false;
    List<CategoryModel>? cached = await getSubCategoryCache(id);

    if (cached != null && cached.isNotEmpty) {
      _subCategoryList = null;
      _categoryItemList = null;
      _prepareSubCategoryList(categoryID, cached);
      hasCache = true;
      if (kDebugMode) {
        print('[CATEGORY_CACHE] Loaded sub categories');
      }
    } else {
      _subCategoryList = null;
      _categoryItemList = null;
    }

    // Trigger items fetch in parallel (also SWR-protected)
    unawaited(getCategoryItemList(categoryID, 1, 'all', false));

    // ---------- PHASE 2: dedupe + background refresh ----------
    if (_isRefreshingSubCategory) return;
    _isRefreshingSubCategory = true;

    try {
      final fresh = await categoryServiceInterface.getSubCategoryList(categoryID);

      if (fresh != null) {
        if (_hasCategoryListChanged(cached, fresh)) {
          await saveSubCategoryCache(id, fresh);
          _prepareSubCategoryList(categoryID, fresh);
        }
      } else if (hasCache) {
        if (kDebugMode) {
          print('[CATEGORY_CACHE] Offline Mode');
        }
      }
    } catch (_) {
      if (hasCache){
         if (kDebugMode) {
           print('[CATEGORY_CACHE] Offline Mode');
         }
      }
    } finally {
      _isRefreshingSubCategory = false;
    }
  }

  void _prepareSubCategoryList(String? categoryID, List<CategoryModel>? subCategoryList) {
    if (subCategoryList == null) return;
    final id = int.tryParse(categoryID ?? '');
    if (id == null) return;

    _subCategoryList ??= [];
    _subCategoryList!.clear();
    _subCategoryList!.add(CategoryModel(id: id, name: 'all'.tr));
    _subCategoryList!.addAll(subCategoryList);
    update();
  }

  void setSubCategoryIndex(int index, String? categoryID) {
    _subCategoryIndex = index;
    if (_isStore) {
      getCategoryStoreList(
        _subCategoryIndex == 0 ? categoryID : _subCategoryList![index].id.toString(),
        1,
        _type,
        true,
      );
    } else {
      getCategoryItemList(
        _subCategoryIndex == 0 ? categoryID : _subCategoryList![index].id.toString(),
        1,
        _type,
        true,
      );
    }
  }

  // ============================================================
  //  ⭐ MODIFIED: getCategoryItemList — SWR + per-(id, page, type) cache
  // ============================================================
  Future<void> getCategoryItemList(String? categoryID, int offset, String type, bool notify) async {
    _offset = offset;
    final id = int.tryParse(categoryID ?? '');
    if (id == null) return;

    if (offset == 1) {
      if (_type == type) {
        _isSearching = false;
      }
      _type = type;
      if (notify) {
        update();
      }
    }

    // ---------- PHASE 1: cache first (per-id,page,type) ----------
    bool hasCache = false;
    ItemModel? cachedModel = await getItemCache(id, offset, type);

    if (cachedModel != null) {
      _prepareCategoryItemList(offset, cachedModel, false);
      hasCache = true;
      if (kDebugMode) {
        print('[CATEGORY_CACHE] Loaded ${cachedModel.items?.length ?? 0} items');
      }
    } else if (offset == 1) {
      // لا كاش للصفحة الأولى → نظهر loading
      _categoryItemList = null;
      if (notify) update();
    }

    // ---------- PHASE 2: per-key dedup + generation token ----------
    final flightKey = _itemFlightKey(id, offset, type);
    final myGen = ++_itemsGeneration;
    if (_inflightItemKeys.contains(flightKey)) {
      if (offset == 1 && _isLoading) {
        _isLoading = false;
        update();
      }
      return;
    }
    _inflightItemKeys.add(flightKey);

    try {
      final freshModel = await categoryServiceInterface.getCategoryItemList(categoryID, offset, type);

      // Stale-response guard: لو المستخدم غيّر category/type بعد الـ request
      if (myGen != _itemsGeneration) return;

      if (freshModel != null) {
        if (_hasItemModelChanged(cachedModel, freshModel)) {
          await saveItemCache(id, offset, type, freshModel);
          _prepareCategoryItemList(offset, freshModel, true);
        }
      } else if (hasCache) {
        if (kDebugMode) {
          print('[CATEGORY_CACHE] Offline Mode');
        }
      }
    } catch (_) {
      if (myGen == _itemsGeneration && hasCache) {
        if (kDebugMode) {
          print('[CATEGORY_CACHE] Offline Mode');
        }
      }
      if (myGen == _itemsGeneration && offset == 1 && _isLoading) {
        _isLoading = false;
        update();
      }
    } finally {
      _inflightItemKeys.remove(flightKey);
    }
  }

  void _prepareCategoryItemList(int offset, ItemModel? model, bool fromApi) {
    if (model == null) return;

    _categoryItemList ??= [];
    if (offset == 1) {
      _categoryItemList!.clear();
    }
    if (model.items != null) {
      _categoryItemList!.addAll(model.items!);
    }
    _pageSize = model.totalSize;
    if (fromApi) _isLoading = false;
    if (model.items != null && (fromApi || offset == 1)) {
      update();
    } else if (fromApi) {
      update();
    }
  }

  bool _hasItemModelChanged(ItemModel? old, ItemModel? fresh) {
    if (old == null || fresh == null) return true;
    if ((old.totalSize ?? 0) != (fresh.totalSize ?? 0)) return true;
    final oi = old.items ?? const <Item>[];
    final fi = fresh.items ?? const <Item>[];
    if (oi.length != fi.length) return true;
    for (int i = 0; i < oi.length; i++) {
      if (oi[i].id != fi[i].id) return true;
    }
    return false;
  }

  // ============================================================
  //  ⭐ MODIFIED: getCategoryStoreList — SWR + per-(id, page, type) cache
  // ============================================================
  Future<void> getCategoryStoreList(String? categoryID, int offset, String type, bool notify) async {
    _offset = offset;
    final id = int.tryParse(categoryID ?? '');
    if (id == null) return;

    if (offset == 1) {
      if (_type == type) {
        _isSearching = false;
      }
      _type = type;
      if (notify) {
        update();
      }
    }

    // ---------- PHASE 1: cache first (per-id,page,type) ----------
    bool hasCache = false;
    StoreModel? cachedModel = await getStoreCache(id, offset, type);

    if (cachedModel != null) {
      _prepareCategoryStoreList(offset, cachedModel, false);
      hasCache = true;
      if (kDebugMode) {
        print('[CATEGORY_CACHE] Loaded ${cachedModel.stores?.length ?? 0} stores');
      }
    } else if (offset == 1) {
      _categoryStoreList = null;
      if (notify) update();
    }

    // ---------- PHASE 2: per-key dedup + generation token ----------
    final flightKey = _storeFlightKey(id, offset, type);
    final myGen = ++_storesGeneration;
    if (_inflightStoreKeys.contains(flightKey)) {
      if (offset == 1 && _isLoading) {
        _isLoading = false;
        update();
      }
      return;
    }
    _inflightStoreKeys.add(flightKey);

    try {
      final freshModel = await categoryServiceInterface.getCategoryStoreList(categoryID, offset, type);

      // Stale-response guard
      if (myGen != _storesGeneration) return;

      if (freshModel != null) {
        if (_hasStoreModelChanged(cachedModel, freshModel)) {
          await saveStoreCache(id, offset, type, freshModel);
          _prepareCategoryStoreList(offset, freshModel, true);
        }
      } else if (hasCache) {
        if (kDebugMode) {
          print('[CATEGORY_CACHE] Offline Mode');
        }
      }
    } catch (_) {
      if (myGen == _storesGeneration && hasCache) {
        if (kDebugMode) {
          print('[CATEGORY_CACHE] Offline Mode');
        }
      }
      if (myGen == _storesGeneration && offset == 1 && _isLoading) {
        _isLoading = false;
        update();
      }
    } finally {
      _inflightStoreKeys.remove(flightKey);
    }
  }

  void _prepareCategoryStoreList(int offset, StoreModel? model, bool fromApi) {
    if (model == null) return;

    _categoryStoreList ??= [];
    if (offset == 1) {
      _categoryStoreList!.clear();
    }
    if (model.stores != null) {
      _categoryStoreList!.addAll(model.stores!);
    }
    _restPageSize = model.totalSize;
    if (fromApi) _isLoading = false;
    if (model.stores != null && (fromApi || offset == 1)) {
      update();
    } else if (fromApi) {
      update();
    }
  }

  bool _hasStoreModelChanged(StoreModel? old, StoreModel? fresh) {
    if (old == null || fresh == null) return true;
    if ((old.totalSize ?? 0) != (fresh.totalSize ?? 0)) return true;
    final oi = old.stores ?? const <Store>[];
    final fi = fresh.stores ?? const <Store>[];
    if (oi.length != fi.length) return true;
    for (int i = 0; i < oi.length; i++) {
      if (oi[i].id != fi[i].id) return true;
    }
    return false;
  }

  // ============================================================
  //  ⭐ MODIFIED: searchData — Debounce 300ms بدون Cache
  // ============================================================
  void searchData(String? query, String? categoryID, String type) {
    // Debounce — يلغي الـ search السابق وينتظر 300ms قبل التنفيذ
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query, categoryID, type);
    });
  }

  Future<void> _performSearch(String? query, String? categoryID, String type) async {
    if ((_isStore && query!.isNotEmpty) || (!_isStore && query!.isNotEmpty)) {
      _searchText = query;
      _type = type;
      _isStore ? _searchStoreList = null : _searchItemList = null;
      _isSearching = true;
      update();

      Response response = await categoryServiceInterface.getSearchData(query, categoryID, _isStore, type);
      if (response.statusCode == 200) {
        if (query.isEmpty) {
          _isStore ? _searchStoreList = [] : _searchItemList = [];
        } else {
          if (_isStore) {
            _searchStoreList = [];
            _searchStoreList!.addAll(StoreModel.fromJson(response.body).stores!);
            update();
          } else {
            _searchItemList = [];
            _searchItemList!.addAll(ItemModel.fromJson(response.body).items!);
          }
        }
      }
      update();
    }
  }

  void toggleSearch() {
    _isSearching = !_isSearching;
    _searchItemList = [];
    if (_categoryItemList != null) {
      _searchItemList!.addAll(_categoryItemList!);
    }
    update();
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  // ============================================================
  //  UNCHANGED — saveInterest / addInterestSelection / setRestaurant
  // ============================================================
  Future<bool> saveInterest(List<int?> interests) async {
    _isLoading = true;
    update();
    bool isSuccess = await categoryServiceInterface.saveUserInterests(interests);
    _isLoading = false;
    update();
    return isSuccess;
  }

  void addInterestSelection(int index) {
    _interestSelectedList![index] = !_interestSelectedList![index];
    update();
  }

  void setRestaurant(bool isRestaurant) {
    _isStore = isRestaurant;
    update();
  }

  // ============================================================
  //  ⭐ NEW: Cache helpers — CategoryList
  // ============================================================
  Future<void> saveCategoryCache(List<CategoryModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(categoryCacheKey, encoded);
      await prefs.setInt(categoryCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<List<CategoryModel>?> getCategoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(categoryCacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCategoryCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(categoryCacheKey);
      await prefs.remove(categoryCacheTimeKey);
    } catch (_) {}
  }

  // ============================================================
  //  ⭐ NEW: Cache helpers — SubCategoryList (per-ID)
  // ============================================================
  Future<void> saveSubCategoryCache(int id, List<CategoryModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_subCategoryKey(id), encoded);
      await prefs.setInt(_subCategoryTimeKey(id), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<List<CategoryModel>?> getSubCategoryCache(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_subCategoryKey(id));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSubCategoryCache(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_subCategoryKey(id));
      await prefs.remove(_subCategoryTimeKey(id));
    } catch (_) {}
  }

  // ============================================================
  //  ⭐ NEW: Cache helpers — Items (per id+page+type)
  // ============================================================
  Future<void> saveItemCache(int id, int page, String type, ItemModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_itemKey(id, page, type), jsonEncode(model.toJson()));
      await prefs.setInt(_itemTimeKey(id, page, type), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<ItemModel?> getItemCache(int id, int page, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_itemKey(id, page, type));
      if (raw == null || raw.isEmpty) return null;
      return ItemModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearItemCache(int id, int page, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_itemKey(id, page, type));
      await prefs.remove(_itemTimeKey(id, page, type));
    } catch (_) {}
  }

  // ============================================================
  //  ⭐ NEW: Cache helpers — Stores (per id+page+type)
  // ============================================================
  Future<void> saveStoreCache(int id, int page, String type, StoreModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storeKey(id, page, type), jsonEncode(model.toJson()));
      await prefs.setInt(_storeTimeKey(id, page, type), DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<StoreModel?> getStoreCache(int id, int page, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storeKey(id, page, type));
      if (raw == null || raw.isEmpty) return null;
      return StoreModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearStoreCache(int id, int page, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storeKey(id, page, type));
      await prefs.remove(_storeTimeKey(id, page, type));
    } catch (_) {}
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }
}
