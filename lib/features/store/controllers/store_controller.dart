import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/category/controllers/category_controller.dart';
import 'package:pickles_and_pies/features/language/controllers/language_controller.dart';
import 'package:pickles_and_pies/features/location/controllers/location_controller.dart';
import 'package:pickles_and_pies/features/store/domain/models/cart_suggested_item_model.dart';
import 'package:pickles_and_pies/features/category/domain/models/category_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/features/store/domain/models/recommended_product_model.dart';
import 'package:pickles_and_pies/features/store/data/cache/store_cache_service.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_banner_model.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_details_result.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';
import 'package:pickles_and_pies/features/review/domain/models/review_model.dart';
import 'package:pickles_and_pies/features/location/domain/models/zone_response_model.dart';
import 'package:pickles_and_pies/features/checkout/controllers/checkout_controller.dart';
import 'package:pickles_and_pies/helper/address_helper.dart';
import 'package:pickles_and_pies/helper/date_converter.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pickles_and_pies/common/widgets/custom_snackbar.dart';
import 'package:pickles_and_pies/features/home/screens/home_screen.dart';
import 'package:pickles_and_pies/features/store/domain/services/store_service_interface.dart';
import 'package:pickles_and_pies/helper/module_helper.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current StoreController flow understood:
/// - Restaurant lists (getStoreList with offset pagination, filterType, storeType)
/// - Store sections (popular, latest, topOffer, featured, visitAgain, recommended)
/// - Store details (getStoreDetails with checkout init, distance calc, location updates)
/// - Store products (getStoreItemList with category, type, price, rating, filters, pagination)
/// - Store search (getStoreSearchItemList with text, pagination)
/// - Filters (setFilterType, setStoreType, setCategoryIndex, rating, price, available, discounted)
class StoreController extends GetxController implements GetxService {
  final StoreServiceInterface storeServiceInterface;
  final StoreCacheService storeCacheService;

  StoreController({
    required this.storeServiceInterface,
    required this.storeCacheService,
  });

  final Map<String, Future<StoreDetailsResult?>> _inFlightStoreRequests =
      <String, Future<StoreDetailsResult?>>{};
  String? _activeStoreIdentityKey;
  bool _controllerClosed = false;

  @override
  void onClose() {
    _controllerClosed = true;
    _activeStoreIdentityKey = null;
    super.onClose();
  }

  // ==========================================================================
  // SHARED PREFERENCES ACCESS
  // ==========================================================================
  SharedPreferences? get _prefs {
    try {
      return Get.find<SharedPreferences>();
    } catch (e) {
      return null;
    }
  }

  // ==========================================================================
  // EXISTING STATE VARIABLES (PRESERVED)
  // ==========================================================================
  StoreModel? _storeModel;
  StoreModel? get storeModel => _storeModel;

  List<Store>? _popularStoreList;
  List<Store>? get popularStoreList => _popularStoreList;

  List<Store>? _latestStoreList;
  List<Store>? get latestStoreList => _latestStoreList;

  List<Store>? _topOfferStoreList;
  List<Store>? get topOfferStoreList => _topOfferStoreList;

  List<Store>? _featuredStoreList;
  List<Store>? get featuredStoreList => _featuredStoreList;

  List<Store>? _visitAgainStoreList;
  List<Store>? get visitAgainStoreList => _visitAgainStoreList;

  Store? _store;
  Store? get store => _store;

  ItemModel? _storeItemModel;
  ItemModel? get storeItemModel => _storeItemModel;

  ItemModel? _storeSearchItemModel;
  ItemModel? get storeSearchItemModel => _storeSearchItemModel;

  int _categoryIndex = 0;
  int get categoryIndex => _categoryIndex;

  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _filterType = 'all';
  String get filterType => _filterType;

  String _storeType = 'all';
  String get storeType => _storeType;

  List<ReviewModel>? _storeReviewList;
  List<ReviewModel>? get storeReviewList => _storeReviewList;

  String _type = 'all';
  String get type => _type;

  String _searchType = 'all';
  String get searchType => _searchType;

  String _searchText = '';
  String get searchText => _searchText;

  bool _currentState = true;
  bool get currentState => _currentState;

  bool _showFavButton = true;
  bool get showFavButton => _showFavButton;

  List<XFile> _pickedPrescriptions = [];
  List<XFile> get pickedPrescriptions => _pickedPrescriptions;

  RecommendedItemModel? _recommendedItemModel;
  RecommendedItemModel? get recommendedItemModel => _recommendedItemModel;

  CartSuggestItemModel? _cartSuggestItemModel;
  CartSuggestItemModel? get cartSuggestItemModel => _cartSuggestItemModel;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  List<StoreBannerModel>? _storeBanners;
  List<StoreBannerModel>? get storeBanners => _storeBanners;

  List<Store>? _recommendedStoreList;
  List<Store>? get recommendedStoreList => _recommendedStoreList;

  String _topOfferFilter = '';
  String get topOfferFilter => _topOfferFilter;

  String _topOfferSort = '';
  String get topOfferSort => _topOfferSort;

  bool _isAvailableItems = false;
  bool get isAvailableItems => _isAvailableItems;

  bool _isDiscountedItems = false;
  bool get isDiscountedItems => _isDiscountedItems;

  List<String>? _filter = [];
  List<String>? get filter => _filter;

  int _rating = -1;
  int get rating => _rating;

  double? _lowerValue;
  double? get lowerValue => _lowerValue;

  double? _upperValue;
  double? get upperValue => _upperValue;

  double _lowerLimit = 0;
  double get getLowerLimit => _lowerLimit;

  double _upperLimit = 99999;
  double get getUpperLimit => _upperLimit;

  // ==========================================================================
  // CACHE KEY GENERATORS
  // ==========================================================================
  String _getStoreListCacheKey(int offset) => 'cached_store_list_${offset}_${_filterType}_$_storeType';
  String _getPopularStoreCacheKey(String type) => 'cached_popular_stores_$type';
  String _getLatestStoreCacheKey(String type) => 'cached_latest_stores_$type';
  String _getTopOfferStoreCacheKey() => 'cached_top_offer_stores_${_topOfferFilter}_$_topOfferSort';
  String _getFeaturedStoreCacheKey() => 'cached_featured_stores';
  String _getVisitAgainStoreCacheKey() => 'cached_visit_again_stores';
  String _getRecommendedStoreCacheKey() => 'cached_recommended_stores';

  String _getStoreItemsCacheKey(int? storeID, int offset) {
    int categoryId = 0;
    if (_store != null && _store!.categoryIds != null && _store!.categoryIds!.isNotEmpty && _categoryIndex != 0 && _categoryList != null && _categoryList!.length > _categoryIndex) {
      categoryId = _categoryList![_categoryIndex].id ?? 0;
    }
    String filterStr = _filter?.join('_') ?? 'no_filter';
    String ratingStr = _rating == -1 ? 'none' : _rating.toString();
    String lowerStr = _lowerValue?.toStringAsFixed(0) ?? 'none';
    String upperStr = _upperValue?.toStringAsFixed(0) ?? 'none';
    return 'cached_store_items_${storeID}_${categoryId}_${_type}_${filterStr}_${ratingStr}_${lowerStr}_${upperStr}_$offset';
  }

  String _getStoreSearchCacheKey(String? storeID, String searchText, String type, int offset) {
    int categoryId = 0;
    if (_store != null && _store!.categoryIds != null && _store!.categoryIds!.isNotEmpty && _categoryIndex != 0 && _categoryList != null && _categoryList!.length > _categoryIndex) {
      categoryId = _categoryList![_categoryIndex].id ?? 0;
    }
    String safeSearch = searchText.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'cached_store_search_${storeID}_${safeSearch}_${type}_${categoryId}_$offset';
  }

  // ==========================================================================
  // CACHE LOAD HELPERS
  // ==========================================================================
  StoreModel? _loadStoreModelFromCache(String key) {
    try {
      String? cache = _prefs?.getString(key);
      if (cache != null && cache.isNotEmpty) {
        return StoreModel.fromJson(jsonDecode(cache));
      }
    } catch (e) {
      _prefs?.remove(key);
    }
    return null;
  }

  List<Store>? _loadStoreListFromCache(String key) {
    try {
      String? cache = _prefs?.getString(key);
      if (cache != null && cache.isNotEmpty) {
        Map<String, dynamic> decoded = jsonDecode(cache);
        if (decoded['stores'] != null) {
          List<Store> stores = [];
          decoded['stores'].forEach((v) => stores.add(Store.fromJson(v)));
          return stores;
        }
      }
    } catch (e) {
      _prefs?.remove(key);
    }
    return null;
  }

  ItemModel? _loadItemModelFromCache(String key) {
    try {
      String? cache = _prefs?.getString(key);
      if (cache != null && cache.isNotEmpty) {
        return ItemModel.fromJson(jsonDecode(cache));
      }
    } catch (e) {
      _prefs?.remove(key);
    }
    return null;
  }

  // ==========================================================================
  // CACHE SAVE HELPERS
  // ==========================================================================
  void _saveStoreModelToCache(String key, StoreModel model) {
    try {
      _prefs?.setString(key, jsonEncode(model.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('------------${e.toString()}');
      }
    }
  }

  void _saveStoreListToCache(String key, List<Store> stores) {
    try {
      _prefs?.setString(key, jsonEncode({'stores': stores.map((v) => v.toJson()).toList()}));
    } catch (e) {
      if (kDebugMode) {
        print('------------${e.toString()}');
      }
    }
  }

  void _saveItemModelToCache(String key, ItemModel model) {
    try {
      _prefs?.setString(key, jsonEncode(model.toJson()));
    } catch (e) {
      if (kDebugMode) {
        print('------------${e.toString()}');
      }
    }
  }

  // ==========================================================================
  // SMART UPDATE COMPARISON HELPERS
  // ==========================================================================
  bool _isStoreModelEqual(StoreModel? a, StoreModel? b) {
    if (a == null || b == null) return false;
    if (a.totalSize != b.totalSize) return false;
    if (a.offset != b.offset) return false;
    if (a.stores?.length != b.stores?.length) return false;
    int compareCount = (a.stores?.length ?? 0) < 5 ? (a.stores?.length ?? 0) : 5;
    for (int i = 0; i < compareCount; i++) {
      if (a.stores![i].id != b.stores![i].id) return false;
    }
    return true;
  }

  bool _isStoreListEqual(List<Store>? a, List<Store>? b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    int compareCount = a.length < 5 ? a.length : 5;
    for (int i = 0; i < compareCount; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  bool _isItemModelEqual(ItemModel? a, ItemModel? b) {
    if (a == null || b == null) return false;
    if (a.totalSize != b.totalSize) return false;
    if (a.offset != b.offset) return false;
    if (a.items?.length != b.items?.length) return false;
    int compareCount = (a.items?.length ?? 0) < 5 ? (a.items?.length ?? 0) : 5;
    for (int i = 0; i < compareCount; i++) {
      if (a.items![i].id != b.items![i].id) return false;
    }
    return true;
  }

  // ==========================================================================
  // CACHE INVALIDATION HELPERS
  // ==========================================================================
  void _invalidateStoreListCache() {
    try {
      Set<String> keys = _prefs?.getKeys() ?? {};
      for (String key in keys) {
        if (key.startsWith('cached_store_list_')) {
          _prefs?.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('------------${e.toString()}');
      }
    }
  }

  void _invalidateStoreItemCache() {
    try {
      Set<String> keys = _prefs?.getKeys() ?? {};
      for (String key in keys) {
        if (key.startsWith('cached_store_items_')) {
          _prefs?.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('------------${e.toString()}');
      }
    }
  }

  void _invalidateStoreSearchCache() {
    try {
      Set<String> keys = _prefs?.getKeys() ?? {};
      for (String key in keys) {
        if (key.startsWith('cached_store_search_')) {
          _prefs?.remove(key);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('------------${e.toString()}');
      }
    }
  }

  // ==========================================================================
  // EXISTING UTILITY METHODS (PRESERVED)
  // ==========================================================================
  double getRestaurantDistance(LatLng storeLatLng){
    double distance = 0;
    if(AddressHelper.getUserAddressFromSharedPref() != null) {
      distance = Geolocator.distanceBetween(storeLatLng.latitude, storeLatLng.longitude,
          double.parse(AddressHelper.getUserAddressFromSharedPref()?.latitude ?? '0'),
          double.parse(AddressHelper.getUserAddressFromSharedPref()?.longitude ?? '0')) / 1000;
    }
    return distance;
  }

  String filteringUrl(String slug){
    return storeServiceInterface.filterRestaurantLinkUrl(slug, _store!);
  }

  void pickPrescriptionImage({required bool isRemove, required bool isCamera}) async {
    if(isRemove) {
      _pickedPrescriptions = [];
    }else {
      XFile? xFile = await ImagePicker().pickImage(source: isCamera ? ImageSource.camera : ImageSource.gallery, imageQuality: 50);
      if(xFile != null) {
        _pickedPrescriptions.add(xFile);
      }
      update();
    }
  }

  void removePrescriptionImage(int index) {
    _pickedPrescriptions.removeAt(index);
    update();
  }

  void changeFavVisibility(){
    _showFavButton = !_showFavButton;
    update();
  }

  void hideAnimation(){
    _currentState = false;
  }

  void showButtonAnimation(){
    Future.delayed(const Duration(seconds: 3), () {
      _currentState = true;
      update();
    });
  }

  Future<void> getRestaurantRecommendedItemList(int? storeId, bool reload) async {
    if(reload) {
      _storeModel = null;
      update();
    }
    RecommendedItemModel? recommendedItemModel = await storeServiceInterface.getStoreRecommendedItemList(storeId);
    if (recommendedItemModel != null) {
      _recommendedItemModel = recommendedItemModel;
    }
    update();
  }

  Future<void> getCartStoreSuggestedItemList(int? storeId) async {
    CartSuggestItemModel? cartSuggestItemModel = await storeServiceInterface.getCartStoreSuggestedItemList(storeId, Get.find<LocalizationController>().locale.languageCode,
        ModuleHelper.getModule(), ModuleHelper.getCacheModule()?.id, ModuleHelper.getModule()?.id);
    if (cartSuggestItemModel != null) {
      _cartSuggestItemModel = cartSuggestItemModel;
    }
    update();
  }

  Future<void> getStoreBannerList(int? storeId) async {
    List<StoreBannerModel>? storeBanners = await storeServiceInterface.getStoreBannerList(storeId);
    if (storeBanners != null) {
      _storeBanners = [];
      _storeBanners!.addAll(storeBanners);
    }
    update();
  }

  // ==========================================================================
  // 1) HOME RESTAURANT LIST FLOW - OFFLINE FIRST + SWR
  // ==========================================================================
  Future<void> getStoreList(int offset, bool reload, {DataSourceEnum source = DataSourceEnum.local}) async {
    String cacheKey = _getStoreListCacheKey(offset);

    if(reload) {
      StoreModel? cachedModel = _loadStoreModelFromCache(cacheKey);
      if (cachedModel != null) {
        // SHOW CACHE IMMEDIATELY - do not clear existing data
        _prepareStoreModel(cachedModel, offset);
      } else {
        _storeModel = null;
      }
      update();
    }

    StoreModel? storeModel;
    if(source == DataSourceEnum.local && offset == 1) {
      // STALE CACHE LOAD (only if not already handled by reload block)
      if (!reload) {
        StoreModel? cachedModel = _loadStoreModelFromCache(cacheKey);
        // SHOW CACHE IMMEDIATELY
        if (cachedModel != null) {
          _prepareStoreModel(cachedModel, offset);
        }
      }
      // BACKGROUND REVALIDATION
      getStoreList(offset, false, source: DataSourceEnum.client);
    } else {
      storeModel = await storeServiceInterface.getStoreList(offset, _filterType, _storeType, source: DataSourceEnum.client);
      if (storeModel != null) {
        // SAVE FRESH DATA
        _saveStoreModelToCache(cacheKey, storeModel);
        // SMART UPDATE - only update UI if data changed
        if (offset == 1) {
          if (!_isStoreModelEqual(_storeModel, storeModel)) {
            // FINAL UI UPDATE
            _prepareStoreModel(storeModel, offset);
          }
        } else {
          // For pagination, always append with deduplication
          _prepareStoreModel(storeModel, offset);
        }
      }
    }
  }

  void _prepareStoreModel(StoreModel? storeModel, int offset) {
    if (storeModel != null) {
      if (offset == 1) {
        _storeModel = storeModel;
      }else {
        _storeModel!.totalSize = storeModel.totalSize;
        _storeModel!.offset = storeModel.offset;
        // Avoid duplicate appending when cache + API return same page
        if (storeModel.stores != null) {
          for (var newStore in storeModel.stores!) {
            bool exists = _storeModel!.stores!.any((s) => s.id == newStore.id);
            if (!exists) {
              _storeModel!.stores!.add(newStore);
            }
          }
        }
      }
      update();
    }
  }

  void setFilterType(String type) {
    _filterType = type;
    _invalidateStoreListCache();
    getStoreList(1, true);
  }

  void setStoreType(String type) {
    _storeType = type;
    _invalidateStoreListCache();
    getStoreList(1, true);
  }

  void resetStoreData() {
    _filterType = 'all';
    _storeType = 'all';
  }

  // ==========================================================================
  // 2) RESTAURANT SECTIONS FLOW - OFFLINE FIRST + SWR
  // ==========================================================================
  Future<void> getPopularStoreList(bool reload, String type, bool notify, {DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    _type = type;
    String cacheKey = _getPopularStoreCacheKey(type);

    if(reload) {
      _popularStoreList = null;
    }
    if(notify) {
      update();
    }
    if(_popularStoreList == null || reload || fromRecall) {
      List<Store>? popularStoreList;
      if(dataSource == DataSourceEnum.local) {
        // STALE CACHE LOAD
        List<Store>? cachedList = _loadStoreListFromCache(cacheKey);
        // SHOW CACHE IMMEDIATELY
        if (cachedList != null) {
          _popularStoreList = [];
          _popularStoreList!.addAll(cachedList);
          update();
        }
        // BACKGROUND REVALIDATION
        getPopularStoreList(false, type, notify, dataSource: DataSourceEnum.client, fromRecall: true);
      } else {
        popularStoreList = await storeServiceInterface.getPopularStoreList(type, source: DataSourceEnum.client);
        if (popularStoreList != null) {
          // SAVE FRESH DATA
          _saveStoreListToCache(cacheKey, popularStoreList);
          // SMART UPDATE
          if (!_isStoreListEqual(_popularStoreList, popularStoreList)) {
            // FINAL UI UPDATE
            _popularStoreList = [];
            _popularStoreList!.addAll(popularStoreList);
            update();
          }
        }
      }
    }
  }

  Future<void> getLatestStoreList(bool reload, String type, bool notify, {DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    _type = type;
    String cacheKey = _getLatestStoreCacheKey(type);

    if(reload){
      _latestStoreList = null;
    }
    if(notify) {
      update();
    }
    if(_latestStoreList == null || reload || fromRecall) {
      List<Store>? latestStoreList;
      if(dataSource == DataSourceEnum.local) {
        // STALE CACHE LOAD
        List<Store>? cachedList = _loadStoreListFromCache(cacheKey);
        // SHOW CACHE IMMEDIATELY
        if (cachedList != null) {
          _latestStoreList = [];
          _latestStoreList!.addAll(cachedList);
          update();
        }
        // BACKGROUND REVALIDATION
        getLatestStoreList(false, type, notify, fromRecall: true, dataSource: DataSourceEnum.client);
      } else {
        latestStoreList = await storeServiceInterface.getLatestStoreList(type, source: DataSourceEnum.client);
        if (latestStoreList != null) {
          // SAVE FRESH DATA
          _saveStoreListToCache(cacheKey, latestStoreList);
          // SMART UPDATE
          if (!_isStoreListEqual(_latestStoreList, latestStoreList)) {
            // FINAL UI UPDATE
            _latestStoreList = [];
            _latestStoreList!.addAll(latestStoreList);
            update();
          }
        }
      }
    }
  }

  Future<void> getTopOfferStoreList(bool reload, bool notify, {DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    String cacheKey = _getTopOfferStoreCacheKey();

    if(reload){
      _topOfferStoreList = null;
    }
    if(notify) {
      update();
    }
    if(_topOfferStoreList == null || reload || fromRecall) {
      List<Store>? latestStoreList;
      if(dataSource == DataSourceEnum.local) {
        // STALE CACHE LOAD
        List<Store>? cachedList = _loadStoreListFromCache(cacheKey);
        // SHOW CACHE IMMEDIATELY
        if (cachedList != null) {
          _topOfferStoreList = [];
          _topOfferStoreList!.addAll(cachedList);
          update();
        }
        // BACKGROUND REVALIDATION
        getTopOfferStoreList(false, notify, dataSource: DataSourceEnum.client, fromRecall: true);
      } else {
        latestStoreList = await storeServiceInterface.getTopOfferStoreList(source: DataSourceEnum.client, filterBy: _topOfferFilter, sortBy: _topOfferSort);
        if (latestStoreList != null) {
          // SAVE FRESH DATA
          _saveStoreListToCache(cacheKey, latestStoreList);
          // SMART UPDATE
          if (!_isStoreListEqual(_topOfferStoreList, latestStoreList)) {
            // FINAL UI UPDATE
            _topOfferStoreList = [];
            _topOfferStoreList!.addAll(latestStoreList);
            update();
          }
        }
      }
    }
  }

  void setTopOfferFilter(String type) {
    _topOfferFilter = type;
    getTopOfferStoreList(true, false);
  }

  void setTopOfferSort(String sort) {
    _topOfferSort = sort;
    getTopOfferStoreList(true, false);
  }

  Future<void> getFeaturedStoreList({DataSourceEnum dataSource = DataSourceEnum.local}) async {
    String cacheKey = _getFeaturedStoreCacheKey();
    List<Store>? stores;
    if(dataSource == DataSourceEnum.local) {
      // STALE CACHE LOAD
      List<Store>? cachedList = _loadStoreListFromCache(cacheKey);
      // SHOW CACHE IMMEDIATELY
      if (cachedList != null) {
        _prepareFeaturedStore(cachedList);
      }
      // BACKGROUND REVALIDATION
      getFeaturedStoreList(dataSource: DataSourceEnum.client);
    } else {
      stores = await storeServiceInterface.getFeaturedStoreList(source: dataSource);
      if (stores != null) {
        // SAVE FRESH DATA
        _saveStoreListToCache(cacheKey, stores);
        // SMART UPDATE - compare filtered results
        List<Store> newFiltered = _computeFeaturedStores(stores);
        List<Store>? oldFiltered = _featuredStoreList;
        if (oldFiltered == null || !_isStoreListEqual(oldFiltered, newFiltered)) {
          _featuredStoreList = newFiltered.isEmpty ? null : newFiltered;
          update();
        }
      }
    }
  }

  List<Store> _computeFeaturedStores(List<Store>? stores) {
    List<Store> filtered = [];
    if (stores != null) {
      List<Modules> moduleList = [];
      moduleList.addAll(storeServiceInterface.moduleList());
      for (Store store in stores) {
        for (var module in moduleList) {
          if(module.id == store.moduleId){
            if(module.pivot!.zoneId == store.zoneId){
              filtered.add(store);
            }
          }
        }
      }
    }
    return filtered;
  }

  void _prepareFeaturedStore(List<Store>? stores) {
    if (stores != null) {
      _featuredStoreList = [];
      List<Modules> moduleList = [];
      moduleList.addAll(storeServiceInterface.moduleList());
      for (Store store in stores) {
        for (var module in moduleList) {
          if(module.id == store.moduleId){
            if(module.pivot!.zoneId == store.zoneId){
              _featuredStoreList!.add(store);
            }
          }
        }
      }
    }
    update();
  }

  Future<void> getVisitAgainStoreList({bool fromModule = false, DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    String cacheKey = _getVisitAgainStoreCacheKey();

    if(fromModule && !fromRecall) {
      _visitAgainStoreList = null;
    }
    List<Store>? stores;
    if(dataSource == DataSourceEnum.local) {
      // STALE CACHE LOAD
      List<Store>? cachedList = _loadStoreListFromCache(cacheKey);
      // SHOW CACHE IMMEDIATELY
      if (cachedList != null) {
        _prepareVisitAgainStore(cachedList);
      }
      // BACKGROUND REVALIDATION
      getVisitAgainStoreList(dataSource: DataSourceEnum.client, fromRecall: true);
    } else {
      stores = await storeServiceInterface.getVisitAgainStoreList(source: DataSourceEnum.client);
      if (stores != null) {
        // SAVE FRESH DATA
        _saveStoreListToCache(cacheKey, stores);
        // SMART UPDATE - compare filtered results
        List<Store> newFiltered = _computeVisitAgainStores(stores);
        List<Store>? oldFiltered = _visitAgainStoreList;
        if (oldFiltered == null || !_isStoreListEqual(oldFiltered, newFiltered)) {
          _visitAgainStoreList = newFiltered.isEmpty ? null : newFiltered;
          update();
        }
      }
    }
  }

  List<Store> _computeVisitAgainStores(List<Store>? stores) {
    List<Store> filtered = [];
    if (stores != null) {
      List<Modules> moduleList = [];
      moduleList.addAll(storeServiceInterface.moduleList());
      for (var store in stores) {
        for (var module in moduleList) {
          if(module.id == store.moduleId){
            if(module.pivot!.zoneId == store.zoneId){
              filtered.add(store);
            }
          }
        }
      }
    }
    return filtered;
  }

  void _prepareVisitAgainStore(List<Store>? stores) {
    if (stores != null) {
      _visitAgainStoreList = [];
      List<Modules> moduleList = [];
      moduleList.addAll(storeServiceInterface.moduleList());
      for (var store in stores) {
        for (var module in moduleList) {
          if(module.id == store.moduleId){
            if(module.pivot!.zoneId == store.zoneId){
              _visitAgainStoreList!.add(store);
            }
          }
        }
      }
    }
    update();
  }

  void setCategoryList() {
    if(Get.find<CategoryController>().categoryList != null && _store != null) {
      _categoryList = [];
      _categoryList!.add(CategoryModel(id: 0, name: 'all'.tr));
      for (var category in Get.find<CategoryController>().categoryList!) {
        if(_store!.categoryIds!.contains(category.id)) {
          _categoryList!.add(category);
        }
      }
    }
  }

  // ==========================================================================
  // 3) STORE DETAILS FLOW - ENTERPRISE CACHE-FIRST + SWR
  // ==========================================================================

  /// Synchronously hydrates the active store from L1/L2 before the first
  /// StoreScreen build. A Store coming from a list is only a visual fallback;
  /// it is never persisted as full details.
  Store? prepareStoreDetails(
    Store requestedStore, {
    bool useListFallback = true,
    bool fromCart = false,
    String slug = '',
  }) {
    final storeId = requestedStore.id;
    if (storeId == null || storeId <= 0) return null;

    final identity = StoreCacheIdentity.current(storeId: storeId);
    _activeStoreIdentityKey = identity.diskKey;
    final entry = storeCacheService.getSync(identity);
    final cachedStore = entry?.toStore();

    if (cachedStore != null) {
      _store = cachedStore;
      _isLoading = false;
      _applyStoreSideEffects(cachedStore, fromCart: fromCart, slug: slug);
    } else if (useListFallback && requestedStore.name != null) {
      _store = requestedStore;
      _isLoading = false;
    } else if (_store?.id != storeId) {
      _store = null;
    }
    return _store;
  }

  Future<Store?> getStoreDetails(
    Store requestedStore,
    bool fromModule, {
    bool fromCart = false,
    String slug = '',
    bool forceRefresh = false,
  }) async {
    final storeId = requestedStore.id;
    if (storeId == null || storeId <= 0) return null;

    _categoryIndex = 0;
    final identity = StoreCacheIdentity.current(storeId: storeId);
    final requestKey = identity.diskKey;
    _activeStoreIdentityKey = requestKey;

    StoreCacheEntry? cacheEntry;
    Store? cachedStore;
    if (!forceRefresh) {
      cacheEntry = storeCacheService.getSync(identity);
      cachedStore = cacheEntry?.toStore();
    }

    if (cachedStore != null) {
      _store = cachedStore;
      _isLoading = false;
      _applyStoreSideEffects(cachedStore, fromCart: fromCart, slug: slug);
      _safeUpdate();
    } else if (requestedStore.name != null) {
      // Instant list fallback only. The dedicated API request still runs.
      _store = requestedStore;
      _isLoading = false;
      _safeUpdate();
    } else {
      if (_store?.id != storeId) _store = null;
      _isLoading = _store == null;
      _safeUpdate();
    }

    final hadDisplayData = _store?.id == storeId && _store?.name != null;
    final result = await _fetchStoreDetailsSingleFlight(
      identity: identity,
      fromCart: fromCart,
      slug: slug,
      handleError: !hadDisplayData,
    );

    if (result != null) {
      await storeCacheService.save(
        identity: identity,
        fullJson: result.rawJson,
      );
    }

    if (_controllerClosed || _activeStoreIdentityKey != requestKey) {
      return result?.store ?? cachedStore ?? requestedStore;
    }

    if (result != null) {
      final oldHash = cacheEntry == null
          ? null
          : _storePayloadHash(cacheEntry.data);
      if (oldHash != _storePayloadHash(result.rawJson)) {
        _store = result.store;
        await _applyStoreSideEffects(
          result.store,
          fromCart: fromCart,
          slug: slug,
        );
        if (fromModule) {
          HomeScreen.loadData(true);
        }
      }
    }

    _isLoading = false;
    _setOrderTypeFromStore();
    _safeUpdate();
    return _store;
  }

  Future<StoreDetailsResult?> _fetchStoreDetailsSingleFlight({
    required StoreCacheIdentity identity,
    required bool fromCart,
    required String slug,
    required bool handleError,
  }) {
    final requestKey = identity.diskKey;
    final existing = _inFlightStoreRequests[requestKey];
    if (existing != null) {
      if (kDebugMode) {
        debugPrint('[StoreCache] REQUEST DEDUPLICATED store=${identity.storeId}');
      }
      return existing;
    }

    if (kDebugMode) {
      debugPrint('[StoreCache] API FETCH store=${identity.storeId}');
    }
    final future = storeServiceInterface.getStoreDetails(
      identity.storeId.toString(),
      fromCart,
      slug,
      identity.languageCode,
      ModuleHelper.getModule(),
      ModuleHelper.getCacheModule()?.id,
      identity.moduleId,
      handleError: handleError,
    );
    _inFlightStoreRequests[requestKey] = future;
    future.whenComplete(() {
      if (identical(_inFlightStoreRequests[requestKey], future)) {
        _inFlightStoreRequests.remove(requestKey);
      }
    });
    return future;
  }

  Future<void> _applyStoreSideEffects(
    Store store, {
    required bool fromCart,
    required String slug,
  }) async {
    if (_controllerClosed) return;
    try {
      if (Get.isRegistered<CheckoutController>()) {
        await Get.find<CheckoutController>().initializeTimeSlot(store);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[StoreCache] time-slot init skipped: $error');
      }
    }

    final storeLatitude = double.tryParse(store.latitude ?? '');
    final storeLongitude = double.tryParse(store.longitude ?? '');
    if (storeLatitude != null && storeLongitude != null) {
      if (!fromCart && slug.isEmpty) {
        final address = AddressHelper.getUserAddressFromSharedPref();
        final customerLatitude = double.tryParse(address?.latitude ?? '');
        final customerLongitude = double.tryParse(address?.longitude ?? '');
        if (customerLatitude != null && customerLongitude != null) {
          try {
            Get.find<CheckoutController>().getDistanceInKM(
              LatLng(customerLatitude, customerLongitude),
              LatLng(storeLatitude, storeLongitude),
            );
          } catch (_) {
            // Distance is supplementary and must never block cached rendering.
          }
        }
      } else if (slug.isNotEmpty) {
        try {
          await Get.find<LocationController>().setStoreAddressToUserAddress(
            LatLng(storeLatitude, storeLongitude),
          );
        } catch (_) {
          // Deep-link location synchronization is best-effort.
        }
      }
    }
    _setOrderTypeFromStore();
  }

  void _setOrderTypeFromStore() {
    try {
      Get.find<CheckoutController>().setOrderType(
        _store?.delivery == true ? 'delivery' : 'take_away',
        notify: false,
      );
    } catch (_) {
      // Checkout may not have been instantiated in isolated tests.
    }
  }

  int _storePayloadHash(Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    const int prime = 0x01000193;
    int hash = 0x811c9dc5;
    for (int index = 0; index < encoded.length; index++) {
      hash ^= encoded.codeUnitAt(index);
      hash = (hash * prime) & 0xFFFFFFFF;
    }
    return hash;
  }

  void _safeUpdate() {
    if (!_controllerClosed) update();
  }

  /// Exposed for tests only – resets the deduplication map when callers want
  /// to verify the single-flight behaviour deterministically.
  @visibleForTesting
  void debugResetStoreDetailsDeduplication() {
    _inFlightStoreRequests.clear();
    _activeStoreIdentityKey = null;
  }

  Future<void> clearStoreCache(int storeId) =>
      storeCacheService.clearStoreCache(storeId);

  Future<void> invalidateStoreCache(int storeId) =>
      storeCacheService.invalidateStoreCache(storeId);

  Future<void> clearAllStoreDetailsCache() =>
      storeCacheService.clearAllStoreDetailsCache();

  Future<void> getRecommendedStoreList({DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    String cacheKey = _getRecommendedStoreCacheKey();

    if(!fromRecall) {
      _recommendedStoreList = null;
    }
    List<Store>? recommendedStoreList;
    if(dataSource == DataSourceEnum.local) {
      // STALE CACHE LOAD
      List<Store>? cachedList = _loadStoreListFromCache(cacheKey);
      // SHOW CACHE IMMEDIATELY
      if (cachedList != null) {
        _recommendedStoreList = [];
        _recommendedStoreList!.addAll(cachedList);
        update();
      }
      // BACKGROUND REVALIDATION
      getRecommendedStoreList(dataSource: DataSourceEnum.client, fromRecall: true);
    } else {
      recommendedStoreList = await storeServiceInterface.getRecommendedStoreList(source: DataSourceEnum.client);
      if (recommendedStoreList != null) {
        // SAVE FRESH DATA
        _saveStoreListToCache(cacheKey, recommendedStoreList);
        // SMART UPDATE
        if (!_isStoreListEqual(_recommendedStoreList, recommendedStoreList)) {
          // FINAL UI UPDATE
          _recommendedStoreList = [];
          _recommendedStoreList!.addAll(recommendedStoreList);
          update();
        }
      }
    }
  }

  // ==========================================================================
  // 4) STORE PRODUCTS FLOW - OFFLINE FIRST + SWR
  // ==========================================================================
  Future<void> getStoreItemList(int? storeID, int offset, String type, bool notify) async {
    String cacheKey = _getStoreItemsCacheKey(storeID, offset);

    if(offset == 1 || _storeItemModel == null) {
      _type = type;
      _storeItemModel = null;
      if(notify) {
        update();
      }
    }

    // STALE CACHE LOAD
    ItemModel? cachedModel = _loadItemModelFromCache(cacheKey);

    // SHOW CACHE IMMEDIATELY
    if (cachedModel != null && cachedModel.items != null && cachedModel.items!.isNotEmpty) {
      if (offset == 1) {
        _storeItemModel = cachedModel;
      } else if (_storeItemModel != null) {
        _storeItemModel!.items!.addAll(cachedModel.items!);
        _storeItemModel!.totalSize = cachedModel.totalSize;
        _storeItemModel!.offset = cachedModel.offset;
        _storeItemModel!.minPrice = cachedModel.minPrice;
        _storeItemModel!.maxPrice = cachedModel.maxPrice;
      }
      setLowerAndUpperLimit(lowerLimit: _storeItemModel?.minPrice?.toDouble() ?? 0, upperLimit: _storeItemModel?.maxPrice?.toDouble() ?? 99999);
      update();
    }

    // BACKGROUND REVALIDATION
    ItemModel? storeItemModel = await storeServiceInterface.getStoreItemList(
      storeID: storeID, offset: offset,
      categoryID: (_store != null && _store!.categoryIds!.isNotEmpty && _categoryIndex != 0) ? _categoryList![_categoryIndex].id : 0,
      type: type,
      filter: _filter,
      rating: _rating == -1 ? null : _rating,
      lowerValue: _lowerValue == 0 ? null : _lowerValue,
      upperValue: _upperValue == 0 ? null : _upperValue,
    );

    if (storeItemModel != null) {
      // SAVE FRESH DATA
      _saveItemModelToCache(cacheKey, storeItemModel);

      if (offset == 1) {
        // SMART UPDATE
        if (!_isItemModelEqual(_storeItemModel, storeItemModel)) {
          // FINAL UI UPDATE
          _storeItemModel = storeItemModel;
          setLowerAndUpperLimit(lowerLimit: _storeItemModel?.minPrice?.toDouble() ?? 0, upperLimit: _storeItemModel?.maxPrice?.toDouble() ?? 99999);
          update();
        }
      } else {
        // For pagination: check if cache was already appended
        bool cacheMatched = cachedModel != null && _isItemModelEqual(cachedModel, storeItemModel);
        if (!cacheMatched) {
          // Remove cached items that were appended to avoid duplication
          if (cachedModel != null && cachedModel.items != null) {
            int cachedItemCount = cachedModel.items!.length;
            int currentCount = _storeItemModel?.items?.length ?? 0;
            if (currentCount >= cachedItemCount) {
              _storeItemModel!.items!.removeRange(currentCount - cachedItemCount, currentCount);
            }
          }
          // Append fresh API data
          if (_storeItemModel != null) {
            _storeItemModel!.items!.addAll(storeItemModel.items!);
            _storeItemModel!.totalSize = storeItemModel.totalSize;
            _storeItemModel!.offset = storeItemModel.offset;
            _storeItemModel!.minPrice = storeItemModel.minPrice;
            _storeItemModel!.maxPrice = storeItemModel.maxPrice;
          } else {
            _storeItemModel = storeItemModel;
          }
          setLowerAndUpperLimit(lowerLimit: _storeItemModel?.minPrice?.toDouble() ?? 0, upperLimit: _storeItemModel?.maxPrice?.toDouble() ?? 99999);
          update();
        }
      }
    }
  }

  // ==========================================================================
  // 5) STORE SEARCH FLOW - OFFLINE FIRST + SWR
  // ==========================================================================
  Future<void> getStoreSearchItemList(String searchText, String? storeID, int offset, String type) async {
    String cacheKey = _getStoreSearchCacheKey(storeID, searchText, type, offset);

    if(searchText.isEmpty) {
      showCustomSnackBar('write_item_name'.tr);
    }else {
      _isSearching = true;
      _searchText = searchText;
      _type = type;
      if(offset == 1 || _storeSearchItemModel == null) {
        _searchType = type;
        _storeSearchItemModel = null;
        update();
      }

      // STALE CACHE LOAD
      ItemModel? cachedModel = _loadItemModelFromCache(cacheKey);

      // SHOW CACHE IMMEDIATELY
      if (cachedModel != null && cachedModel.items != null && cachedModel.items!.isNotEmpty) {
        if (offset == 1) {
          _storeSearchItemModel = cachedModel;
        } else if (_storeSearchItemModel != null) {
          _storeSearchItemModel!.items!.addAll(cachedModel.items!);
          _storeSearchItemModel!.totalSize = cachedModel.totalSize;
          _storeSearchItemModel!.offset = cachedModel.offset;
        }
        update();
      }

      // BACKGROUND REVALIDATION
      ItemModel? storeSearchItemModel = await storeServiceInterface.getStoreSearchItemList(searchText, storeID, offset, type,
          (_store != null && _store!.categoryIds!.isNotEmpty && _categoryIndex != 0) ? _categoryList![_categoryIndex].id : 0);

      if (storeSearchItemModel != null) {
        // SAVE FRESH DATA
        _saveItemModelToCache(cacheKey, storeSearchItemModel);

        if (offset == 1) {
          // SMART UPDATE
          if (!_isItemModelEqual(_storeSearchItemModel, storeSearchItemModel)) {
            // FINAL UI UPDATE
            _storeSearchItemModel = storeSearchItemModel;
            update();
          }
        } else {
          // For pagination: check if cache was already appended
          bool cacheMatched = cachedModel != null && _isItemModelEqual(cachedModel, storeSearchItemModel);
          if (!cacheMatched) {
            // Remove cached items that were appended to avoid duplication
            if (cachedModel != null && cachedModel.items != null) {
              int cachedItemCount = cachedModel.items!.length;
              int currentCount = _storeSearchItemModel?.items?.length ?? 0;
              if (currentCount >= cachedItemCount) {
                _storeSearchItemModel!.items!.removeRange(currentCount - cachedItemCount, currentCount);
              }
            }
            // Append fresh API data
            if (_storeSearchItemModel != null) {
              _storeSearchItemModel!.items!.addAll(storeSearchItemModel.items!);
              _storeSearchItemModel!.totalSize = storeSearchItemModel.totalSize;
              _storeSearchItemModel!.offset = storeSearchItemModel.offset;
            } else {
              _storeSearchItemModel = storeSearchItemModel;
            }
            update();
          }
        }
      }
      update();
    }
  }

  void changeSearchStatus({bool isUpdate = true}) {
    _isSearching = !_isSearching;
    if(isUpdate) {
      update();
    }
  }

  void initSearchData() {
    _storeSearchItemModel = ItemModel(items: []);
    _searchText = '';
  }

  void setCategoryIndex(int index, {bool itemSearching = false}) {
    _categoryIndex = index;
    _invalidateStoreItemCache();
    _invalidateStoreSearchCache();
    if(itemSearching){
      _storeSearchItemModel = null;
      getStoreSearchItemList(_searchText, _store!.id.toString(), 1, type);
    } else {
      _storeItemModel = null;
      getStoreItemList(_store!.id, 1, Get.find<StoreController>().type, false);
    }
    update();
  }

  // ==========================================================================
  // 6) USER ACTION FILTER METHODS WITH CACHE INVALIDATION
  // ==========================================================================
  void setRating(int rate) {
    _rating = rate;
    _invalidateStoreItemCache();
    _invalidateStoreSearchCache();
    update();
  }

  void toggleAvailableItems() {
    _isAvailableItems = !_isAvailableItems;
    if(_isAvailableItems) {
      _filter!.add("available_now");
    } else {
      _filter!.remove("available_now");
    }
    _invalidateStoreItemCache();
    _invalidateStoreSearchCache();
    update();
  }

  void toggleDiscountedItems() {
    _isDiscountedItems = !_isDiscountedItems;
    if(_isDiscountedItems) {
      _filter!.add("discounted");
    } else {
      _filter!.remove("discounted");
    }
    _invalidateStoreItemCache();
    _invalidateStoreSearchCache();
    update();
  }

  void setLowerAndUpperValue({double? lower, double? upper, bool reload = false}) {
    if(lower != null){
      _lowerValue = lower.clamp(getLowerLimit, getUpperLimit);
    }
    if(upper != null){
      _upperValue = upper.clamp(getLowerLimit, getUpperLimit);
    }
    if(reload){
      _invalidateStoreItemCache();
      _invalidateStoreSearchCache();
      update();
    }
  }

  void setLowerAndUpperLimit({double? lowerLimit, double? upperLimit, bool reload = true}) {
    if(lowerLimit != null) _lowerLimit = lowerLimit;
    if(upperLimit != null) _upperLimit = upperLimit;

    _lowerValue = _lowerValue?.clamp(_lowerLimit, _upperLimit);
    _upperValue = _upperValue?.clamp(_lowerLimit, _upperLimit);

    if(reload) {
      _invalidateStoreItemCache();
      _invalidateStoreSearchCache();
      update();
    }
  }

  void resetFilter({bool isUpdate = true}) {
    _isAvailableItems = false;
    _isDiscountedItems = false;
    _rating = -1;
    _lowerValue = null;
    _upperValue = null;
    _filter = [];
    _invalidateStoreItemCache();
    _invalidateStoreSearchCache();
    if(isUpdate) {
      update();
    }
  }

  // ==========================================================================
  // EXISTING UTILITY METHODS (PRESERVED)
  // ==========================================================================
  bool isStoreClosed(bool today, bool active, List<Schedules>? schedules) {
    if(!active) {
      return true;
    }
    DateTime date = DateTime.now();
    if(!today) {
      date = date.add(const Duration(days: 1));
    }
    int weekday = date.weekday;
    if(weekday == 7) {
      weekday = 0;
    }
    for(int index=0; index<schedules!.length; index++) {
      if(weekday == schedules[index].day) {
        return false;
      }
    }
    return true;
  }

  bool isStoreOpenNow(bool active, List<Schedules>? schedules) {
    if(isStoreClosed(true, active, schedules)) {
      return false;
    }
    int weekday = DateTime.now().weekday;
    if(weekday == 7) {
      weekday = 0;
    }
    for(int index=0; index<schedules!.length; index++) {
      if(weekday == schedules[index].day
          && DateConverter.isAvailable(schedules[index].openingTime, schedules[index].closingTime)) {
        return true;
      }
    }
    return false;
  }

  bool isOpenNow(Store store) => store.open == 1 && store.active!;

  double? getDiscount(Store store) => store.discount != null ? store.discount!.discount : 0;

  String? getDiscountType(Store store) => store.discount != null ? store.discount!.discountType : 'percent';

  void shareStore() {
    if(ResponsiveHelper.isDesktop(Get.context)){
      String shareUrl = '${AppConstants.webHostedUrl}${filteringUrl(store!.slug ?? '')}';

      Clipboard.setData(ClipboardData(text: shareUrl));
      showCustomSnackBar('store_url_copied'.tr, isError: false);
    } else {
      String shareUrl = '${AppConstants.webHostedUrl}${filteringUrl(store!.slug ?? '')}';
      SharePlus.instance.share(ShareParams(text: shareUrl));
    }
  }
}