import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/common/widgets/cart_snackbar.dart';
import 'package:pickles_and_pies/common/widgets/confirmation_dialog.dart';
import 'package:pickles_and_pies/common/widgets/custom_snackbar.dart';
import 'package:pickles_and_pies/common/widgets/item_bottom_sheet.dart';
import 'package:pickles_and_pies/features/cart/controllers/cart_controller.dart';
import 'package:pickles_and_pies/features/cart/domain/models/cart_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/place_order_body_model.dart';
import 'package:pickles_and_pies/features/item/data/cache/item_list_cache_helper.dart';
import 'package:pickles_and_pies/features/item/data/cache/product_cache_helper.dart';
import 'package:pickles_and_pies/features/item/domain/models/basic_medicine_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/common_condition_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/features/item/domain/services/item_service_interface.dart';
import 'package:pickles_and_pies/features/item/screens/item_details_screen.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/helper/date_converter.dart';
import 'package:pickles_and_pies/helper/module_helper.dart';
import 'package:pickles_and_pies/helper/price_converter.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:pickles_and_pies/util/images.dart';

class ItemController extends GetxController implements GetxService {
  final ItemServiceInterface itemServiceInterface;
  ItemController({required this.itemServiceInterface});

  // List state
  List<Item>? _popularItemList;
  List<Item>? get popularItemList => _popularItemList;

  List<Item>? _reviewedItemList;
  List<Item>? get reviewedItemList => _reviewedItemList;

  List<Item>? _recommendedItemList;
  List<Item>? get recommendedItemList => _recommendedItemList;

  List<Item>? _discountedItemList;
  List<Item>? get discountedItemList => _discountedItemList;

  List<Categories>? _reviewedCategoriesList;
  List<Categories>? get reviewedCategoriesList => _reviewedCategoriesList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _pageSize = 0;
  int? get pageSize => _pageSize;

  List<String> _offsetList = [];

  int _offset = 1;
  int get offset => _offset;

  List<int>? _variationIndex;
  List<int>? get variationIndex => _variationIndex;

  List<List<bool?>> _selectedVariations = [];
  List<List<bool?>> get selectedVariations => _selectedVariations;

  int? _quantity = 1;
  int? get quantity => _quantity;

  List<bool> _addOnActiveList = [];
  List<bool> get addOnActiveList => _addOnActiveList;

  List<int?> _addOnQtyList = [];
  List<int?> get addOnQtyList => _addOnQtyList;

  final String _popularType = 'all';
  String get popularType => _popularType;

  final String _reviewedType = 'all';
  String get reviewType => _reviewedType;

  final String _discountedType = 'all';
  String get discountedType => _discountedType;

  static final List<String> _itemTypeList = ['all', 'veg', 'non_veg'];
  List<String> get itemTypeList => _itemTypeList;

  int _imageIndex = 0;
  int get imageIndex => _imageIndex;

  int _cartIndex = -1;
  int get cartIndex => _cartIndex;

  Item? _item;
  Item? get item => _item;

  int _productSelect = 0;
  int get productSelect => _productSelect;

  int _imageSliderIndex = 0;
  int get imageSliderIndex => _imageSliderIndex;

  List<bool> _collapseVariation = [];
  List<bool> get collapseVariation => _collapseVariation;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  bool _isReadMore = false;
  bool get isReadMore => _isReadMore;

  BasicMedicineModel? _basicMedicineModel;
  BasicMedicineModel? get basicMedicineModel => _basicMedicineModel;

  List<CommonConditionModel>? _commonConditions;
  List<CommonConditionModel>? get commonConditions => _commonConditions;

  int _selectedCommonCondition = 0;
  int get selectedCommonCondition => _selectedCommonCondition;

  List<Item>? _conditionWiseProduct;
  List<Item>? get conditionWiseProduct => _conditionWiseProduct;

  ItemModel? _featuredCategoriesItem;
  ItemModel? get featuredCategoriesItem => _featuredCategoriesItem;

  int _selectedCategory = 0;
  int get selectedCategory => _selectedCategory;

  static final List<String> _sortOptions = ['default', 'a_to_z', 'z_to_a', 'high', 'low'];
  List<String> get sortOptions => _sortOptions;

  String _selectedSortOption = 'default';
  String get selectedSortOption => _selectedSortOption;

  final List<String> _filter = [];
  List<String>? get filter => _filter;

  int? _rating;
  int? get rating => _rating;

  final List<int> _selectedCategoryIds = [];
  List<int> get selectedCategoryIds => _selectedCategoryIds;

  double _selectedMinPrice = 0;
  double get selectedMinPrice => _selectedMinPrice;

  double _selectedMaxPrice = 9999999999;
  double get selectedMaxPrice => _selectedMaxPrice;

  List<Categories>? _categoryList = [];
  List<Categories>? get categoryList => _categoryList;

  bool _isAvailableItems = false;
  bool get isAvailableItems => _isAvailableItems;

  bool _isUnAvailableItems = false;
  bool get isUnAvailableItems => _isUnAvailableItems;

  bool _isTopRated = false;
  bool get isTopRated => _isTopRated;

  bool _isMostLoved = false;
  bool get isMostLoved => _isMostLoved;

  bool _isPopular = false;
  bool get isPopular => _isPopular;

  bool _isLatest = false;
  bool get isLatest => _isLatest;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  final TextEditingController _searchController = TextEditingController(text: '');
  TextEditingController get searchController => _searchController;

  // Enterprise Product Cache – SWR state (item details)
  int? _lastLoadedItemId;
  bool _isRevalidating = false;
  bool get isRevalidating => _isRevalidating;

  void clearSearch({bool withUpdate = true}) {
    _searchController.text = '';
    _isSearching = false;
    if(withUpdate) {
      update();
    }
  }

  void toggleCategory(int? categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId!);
    }
    update();
  }

  void setMinAndMaxPrice(double min, double max, {bool withUpdate = true}) {
    _selectedMinPrice = min;
    _selectedMaxPrice = max;
    if(withUpdate) {
      update();
    }
  }

  void toggleAvailableItems() {
    _isAvailableItems = !_isAvailableItems;
    if(_isAvailableItems) {
      _filter.add("available_now");
    } else {
      _filter.remove("available_now");
    }
    update();
  }

  void toggleUnavailableItems() {
    _isUnAvailableItems = !_isUnAvailableItems;
    if(_isUnAvailableItems) {
      _filter.add("un_available_now");
    } else {
      _filter.remove("un_available_now");
    }
    update();
  }

  void toggleTopRated() {
    _isTopRated = !_isTopRated;
    if(_isTopRated) {
      _filter.add("top_rated");
    } else {
      _filter.remove("top_rated");
    }
    update();
  }

  void toggleMostLoved() {
    _isMostLoved = !_isMostLoved;
    if(_isMostLoved) {
      _filter.add("most_loved");
    } else {
      _filter.remove("most_loved");
    }
    update();
  }

  void togglePopular() {
    _isPopular = !_isPopular;
    if(_isPopular) {
      _filter.add("popular");
    } else {
      _filter.remove("popular");
    }
    update();
  }

  void toggleLatest() {
    _isLatest = !_isLatest;
    if(_isLatest) {
      _filter.add("latest");
    } else {
      _filter.remove("latest");
    }
    update();
  }

  void setSelectedRating(int rating) {
    _rating = rating;
    update();
  }

  void setSelectedSortOption(String option) {
    _selectedSortOption = option;

    for (var element in _sortOptions) {
      if(_filter.contains(element)) {
        _filter.remove(element);
      }else if(element == _selectedSortOption) {
        _filter.add(element);
      }
    }
    update();
  }

  void selectCategory(int index) {
    _selectedCategory = index;
    update();
  }

  void applyFilters({bool isPopular = false, bool isSpecial = false}) {
    if(isPopular){
      // Use local source so the in-memory cache renders instantly
      // before the background network refresh.
      getPopularItemList(notify: true, offset: '1', dataSource: DataSourceEnum.local);
    }else if(isSpecial){
      getDiscountedItemList(notify: true, offset: '1', dataSource: DataSourceEnum.local);
    }else{
      getReviewedItemList(notify: true, offset: '1', dataSource: DataSourceEnum.local);
    }
  }

  void resetFilters({bool isPopular = false, bool isSpecial = false}) {
    _selectedCategoryIds.clear();
    _filter.clear();
    _rating = null;
    _selectedMinPrice = 0;
    _selectedMaxPrice = 9999999999;
    _isAvailableItems = false;
    _isUnAvailableItems = false;
    _isTopRated = false;
    _isMostLoved = false;
    _isPopular = false;
    _isLatest = false;
    _selectedSortOption = 'default';
    _searchController.text = '';

    // Use local source so the in-memory cache renders instantly
    // (no shimmer) when navigating back from the popular / special / reviewed
    // listing screens to the home page.
    if (isPopular) {
      getPopularItemList(offset: '1', dataSource: DataSourceEnum.local);
    } else if(isSpecial) {
      getDiscountedItemList(offset: '1', dataSource: DataSourceEnum.local);
    } else {
      getReviewedItemList(offset: '1', dataSource: DataSourceEnum.local);
    }

    update();
  }

  void clearFilters({bool isPopular = false, bool isSpecial = false}) {
    _selectedCategoryIds.clear();
    _filter.clear();
    _rating = null;
    _selectedMinPrice = 0;
    _selectedMaxPrice = 9999999999;
    _isAvailableItems = false;
    _isUnAvailableItems = false;
    _isTopRated = false;
    _isMostLoved = false;
    _isPopular = false;
    _isLatest = false;
    _selectedSortOption = 'default';
    _searchController.text = '';

    // Use local source so the in-memory cache renders instantly.
    if (isPopular) {
      getPopularItemList(offset: '1', dataSource: DataSourceEnum.local, firstTimeCategoryLoad: true);
    } else if(isSpecial) {
      getDiscountedItemList(offset: '1', dataSource: DataSourceEnum.local, firstTimeCategoryLoad: true);
    } else {
      getReviewedItemList(offset: '1', dataSource: DataSourceEnum.local, firstTimeCategoryLoad: true);
    }
  }

  void selectCommonCondition(int index) {
    _selectedCommonCondition = index;
    getConditionsWiseItem(_commonConditions![index].id!, true);
    update();
  }

  void changeReadMore() {
    _isReadMore = !_isReadMore;
    update();
  }

  void setCurrentIndex(int index, bool notify) {
    _currentIndex = index;
    if(notify) {
      update();
    }
  }

  void clearItemLists() {
    _popularItemList = null;
    _reviewedItemList = null;
    _discountedItemList = null;
    _featuredCategoriesItem = null;
    _recommendedItemList = null;
  }

  /// Wipe every cached list. Call this on logout.
  Future<void> clearAllItemCaches() async {
    clearItemLists();
    await ItemListCacheHelper.invalidateAll();
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  bool hasMoreData({bool isPopular = false, bool isSpecial = false}) {
    if(isPopular){
      return _popularItemList != null && _popularItemList!.length < _pageSize!;
    }else if(isSpecial){
      return _discountedItemList != null && _discountedItemList!.length < _pageSize!;
    }else{
      return _reviewedItemList != null && _reviewedItemList!.length < _pageSize!;
    }
  }

  // GET POPULAR ITEM LIST – module-aware SWR via ItemListCacheHelper
  Future<void> getPopularItemList({
    required String offset,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool notify = false,
    bool firstTimeCategoryLoad = false,
  }) async {
    _isSearching = _searchController.text.isNotEmpty;
    if (notify) update();

    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      // Only wipe the list when doing a network-only fetch.
      // For DataSourceEnum.local we keep the current data on screen and let
      // _fetchPagedList paint the cached snapshot synchronously, which avoids
      // any "shimmer → items" flicker when returning from the popular-items
      // listing back to the home page.
      if (dataSource != DataSourceEnum.local) {
        _popularItemList = null;
        if (firstTimeCategoryLoad) _categoryList = null;
        if (notify) update();
      }
    }

    if (_offsetList.contains(offset)) {
      if (_isLoading) {
        _isLoading = false;
        update();
      }
      return;
    }
    _offsetList.add(offset);

    await _fetchPagedList<ItemModel>(
      cacheKey: ItemListCacheKeys.popularItems,
      dataSource: dataSource,
      offset: offset,
      networkFetch: () async {
        return await itemServiceInterface.getPopularItemList(
          type: _popularType,
          source: dataSource == DataSourceEnum.local
              ? DataSourceEnum.client
              : dataSource,
          offset: _offset,
          search: _searchController.text,
          categoryIds: _selectedCategoryIds,
          filter: _filter,
          rating: _rating,
          minPrice: _selectedMinPrice,
          maxPrice: _selectedMaxPrice,
        );
      },
      apply: (model) {
        if (offset == '1') {
          _popularItemList = [];
          if (firstTimeCategoryLoad) _categoryList = [];
        }
        _popularItemList!.addAll(model.items!);
        if (firstTimeCategoryLoad) _categoryList!.addAll(model.categories!);
        _pageSize = model.totalSize;
        _isLoading = false;
      },
    );
  }

  // GET REVIEWED ITEM LIST – module-aware SWR via ItemListCacheHelper
  Future<void> getReviewedItemList({
    required String offset,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool notify = false,
    bool firstTimeCategoryLoad = false,
  }) async {
    _isSearching = _searchController.text.isNotEmpty;
    if (notify) update();

    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      // See getPopularItemList for rationale on guarding the wipe.
      if (dataSource != DataSourceEnum.local) {
        _reviewedItemList = null;
        _reviewedCategoriesList = null;
        if (firstTimeCategoryLoad) _categoryList = null;
        if (notify) update();
      }
    }

    if (_offsetList.contains(offset)) {
      if (_isLoading) {
        _isLoading = false;
        update();
      }
      return;
    }
    _offsetList.add(offset);

    await _fetchPagedList<ItemModel>(
      cacheKey: ItemListCacheKeys.reviewedItems,
      dataSource: dataSource,
      offset: offset,
      networkFetch: () async {
        return await itemServiceInterface.getReviewedItemList(
          type: _reviewedType,
          source: dataSource == DataSourceEnum.local
              ? DataSourceEnum.client
              : dataSource,
          offset: _offset,
          search: _searchController.text,
          categoryIds: _selectedCategoryIds,
          filter: _filter,
          rating: _rating,
          minPrice: _selectedMinPrice,
          maxPrice: _selectedMaxPrice,
        );
      },
      apply: (model) {
        if (offset == '1') {
          _reviewedItemList = [];
          _reviewedCategoriesList = [];
          if (firstTimeCategoryLoad) _categoryList = [];
        }
        _reviewedItemList!.addAll(model.items!);
        _reviewedCategoriesList!.addAll(model.categories!);
        if (firstTimeCategoryLoad) _categoryList!.addAll(model.categories!);
        _pageSize = model.totalSize;
        _isLoading = false;
      },
    );
  }

  // GET DISCOUNTED ITEM LIST – module-aware SWR via ItemListCacheHelper
  Future<void> getDiscountedItemList({
    required String offset,
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool notify = false,
    bool firstTimeCategoryLoad = false,
  }) async {
    _isSearching = _searchController.text.isNotEmpty;
    if (notify) update();

    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      // See getPopularItemList for rationale on guarding the wipe.
      if (dataSource != DataSourceEnum.local) {
        _discountedItemList = null;
        if (firstTimeCategoryLoad) _categoryList = null;
        if (notify) update();
      }
    }

    if (_offsetList.contains(offset)) {
      if (_isLoading) {
        _isLoading = false;
        update();
      }
      return;
    }
    _offsetList.add(offset);

    await _fetchPagedList<ItemModel>(
      cacheKey: ItemListCacheKeys.discountedItems,
      dataSource: dataSource,
      offset: offset,
      networkFetch: () async {
        return await itemServiceInterface.getDiscountedItemList(
          type: _discountedType,
          source: dataSource == DataSourceEnum.local
              ? DataSourceEnum.client
              : dataSource,
          offset: _offset,
          search: _searchController.text,
          categoryIds: _selectedCategoryIds,
          filter: _filter,
          rating: _rating,
          minPrice: _selectedMinPrice,
          maxPrice: _selectedMaxPrice,
        );
      },
      apply: (model) {
        if (offset == '1') {
          _discountedItemList = [];
          if (firstTimeCategoryLoad) _categoryList = [];
        }
        _discountedItemList!.addAll(model.items!);
        if (firstTimeCategoryLoad) _categoryList!.addAll(model.categories!);
        _pageSize = model.totalSize;
        _isLoading = false;
      },
    );
  }

  // Shared SWR driver for the three paged lists (popular / reviewed / discounted).
  Future<void> _fetchPagedList<T>({
    required String cacheKey,
    required DataSourceEnum dataSource,
    required String offset,
    required Future<T?> Function() networkFetch,
    required void Function(T) apply,
  }) async {
    bool renderedFromCache = false;

    // 1) Stale cache load (only for offset=1).
    if (dataSource == DataSourceEnum.local && offset == '1') {
      // 1a) Synchronous memory cache hit – avoids any UI flicker.
      final memEntry = ItemListCacheHelper.peekMemory(cacheKey);
      if (memEntry != null) {
        try {
          final model = ItemModel.fromJson(memEntry.data);
          apply(model as T);
          renderedFromCache = true;
        } catch (_) {
          // fall through to disk read
        }
      }
      // 1b) Disk cache fallback (only if memory missed).
      if (!renderedFromCache) {
        final cached = await ItemListCacheHelper.getItemModel(cacheKey);
        if (cached != null) {
          apply(cached as T);
          renderedFromCache = true;
        }
      }
      // Paint the cached snapshot immediately – without this the new data
      // would only become visible after the background network refresh.
      if (renderedFromCache) {
        _isLoading = false;
        update();
      }
    }

    if (!renderedFromCache) {
      _isLoading = true;
      update();
    }

    // 2) Background revalidation / fresh fetch.
    final fresh = await networkFetch();
    if (fresh != null) {
      apply(fresh);
      // Persist only the first page – subsequent pages are part of a single
      // transient scroll session.
      if (offset == '1' && fresh is ItemModel) {
        await ItemListCacheHelper.save(
          cacheKey: cacheKey,
          data: fresh.toJson(),
        );
      }
      // Always refresh the UI when we have a fresh payload – even if a cache
      // snapshot was already painted – so stale items get replaced.
      _isLoading = false;
      update();
    } else if (!renderedFromCache && _isLoading) {
      _isLoading = false;
      update();
    }
  }

  // GET FEATURED CATEGORIES ITEM LIST – module-aware SWR via helper
  Future<void> getFeaturedCategoriesItemList(
    bool reload,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _featuredCategoriesItem = null;
    }
    if (notify) update();

    if (_featuredCategoriesItem == null || reload || fromRecall) {
      bool renderedFromCache = false;

      if (dataSource == DataSourceEnum.local && !fromRecall) {
        final cached = await ItemListCacheHelper.getItemModel(
          ItemListCacheKeys.featuredItems,
        );
        if (cached != null) {
          _featuredCategoriesItem = cached;
          renderedFromCache = true;
          update();
        }
      }

      if (!renderedFromCache) {
        _isLoading = true;
        update();
      }

      final fresh = await itemServiceInterface.getFeaturedCategoriesItemList(
        dataSource == DataSourceEnum.local ? DataSourceEnum.client : dataSource,
      );

      if (fresh != null) {
        _featuredCategoriesItem = fresh;
        await ItemListCacheHelper.save(
          cacheKey: ItemListCacheKeys.featuredItems,
          data: fresh.toJson(),
        );
      }

      if (!renderedFromCache && _isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  // GET RECOMMENDED ITEM LIST – module-aware SWR via helper
  Future<void> getRecommendedItemList(
    bool reload,
    String type,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _recommendedItemList = null;
    }
    if (notify) update();

    if (_recommendedItemList == null || reload || fromRecall) {
      bool renderedFromCache = false;

      if (dataSource == DataSourceEnum.local && !fromRecall) {
        final cached = await ItemListCacheHelper.getItemList(
          ItemListCacheKeys.recommendedItems,
        );
        if (cached != null) {
          _recommendedItemList = [];
          _recommendedItemList!.addAll(cached);
          renderedFromCache = true;
          update();
        }
      }

      if (!renderedFromCache) {
        _isLoading = true;
        update();
      }

      final fresh = await itemServiceInterface.getRecommendedItemList(
        type,
        dataSource == DataSourceEnum.local ? DataSourceEnum.client : dataSource,
      );
      if (fresh != null) {
        _recommendedItemList = [];
        _recommendedItemList!.addAll(fresh);
        await ItemListCacheHelper.save(
          cacheKey: ItemListCacheKeys.recommendedItems,
          data: {'items': fresh.map((v) => v.toJson()).toList()},
        );
      }

      if (!renderedFromCache && _isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  // GET BASIC MEDICINE – module-aware SWR via helper
  Future<void> getBasicMedicine(
    bool reload,
    bool notify, {
    DataSourceEnum dataSource = DataSourceEnum.local,
    bool fromRecall = false,
  }) async {
    if (reload) {
      _basicMedicineModel = null;
    }
    if (notify) update();

    if (_basicMedicineModel == null || reload || fromRecall) {
      bool renderedFromCache = false;

      if (dataSource == DataSourceEnum.local && !fromRecall) {
        final cached = await ItemListCacheHelper.getBasicMedicine();
        if (cached != null) {
          _basicMedicineModel = cached;
          renderedFromCache = true;
          update();
        }
      }

      if (!renderedFromCache) {
        _isLoading = true;
        update();
      }

      final fresh = await itemServiceInterface.getBasicMedicine(
        dataSource == DataSourceEnum.local ? DataSourceEnum.client : dataSource,
      );
      if (fresh != null) {
        _basicMedicineModel = fresh;
        await ItemListCacheHelper.save(
          cacheKey: ItemListCacheKeys.basicMedicine,
          data: fresh.toJson(),
        );
      }

      if (!renderedFromCache && _isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  // GET CONDITIONS-WISE ITEMS – module-aware SWR via helper
  Future<void> getConditionsWiseItem(int id, bool notify) async {
    _conditionWiseProduct = null;
    if (notify) update();

    bool renderedFromCache = false;
    final cached = await ItemListCacheHelper.getItemList(
      ItemListCacheKeys.conditionsWiseItem,
    );
    if (cached != null) {
      _conditionWiseProduct = [];
      _conditionWiseProduct!.addAll(cached);
      renderedFromCache = true;
      update();
    }

    if (!renderedFromCache) {
      _isLoading = true;
      update();
    }

    final fresh = await itemServiceInterface.getConditionsWiseItems(id);
    if (fresh != null) {
      _conditionWiseProduct = [];
      _conditionWiseProduct!.addAll(fresh);
      await ItemListCacheHelper.save(
        cacheKey: ItemListCacheKeys.conditionsWiseItem,
        data: {'items': fresh.map((v) => v.toJson()).toList()},
      );
    }

    _isLoading = false;
    update();
  }

  // GET COMMON CONDITIONS – module-aware SWR via helper
  Future<void> getCommonConditions(bool notify) async {
    _commonConditions = [];
    if (notify) update();

    bool renderedFromCache = false;
    final cached = await ItemListCacheHelper.getCommonConditions();
    if (cached != null) {
      _commonConditions = [];
      _commonConditions!.addAll(cached);
      renderedFromCache = true;
      update();
    }

    if (!renderedFromCache) {
      _isLoading = true;
      update();
    }

    final fresh = await itemServiceInterface.getCommonConditions();
    if (fresh != null) {
      _commonConditions = [];
      _commonConditions!.addAll(fresh);
      await ItemListCacheHelper.save(
        cacheKey: ItemListCacheKeys.commonConditions,
        data: {'conditions': fresh.map((v) => v.toJson()).toList()},
      );
    }

    _isLoading = false;
    update();
  }

  // GET ITEM DETAILS – SWR with memory + disk + ProductCacheHelper
  Future<void> getItemDetails({required int itemId, CartModel? cart, bool isCampaign = false}) async {
    final isNewItem = (_lastLoadedItemId != itemId);

    if (isNewItem) {
      _item = null;
      _isLoading = true;
      _isRevalidating = false;
    }

    // 1) Stale-While-Revalidate: read from cache
    bool renderedFromCache = false;
    final cached = await ProductCacheHelper.get(itemId);
    if (cached != null) {
      final cachedItem = cached.toItem();
      if (cachedItem != null) {
        _item = cachedItem;
        if (isNewItem) {
          initData(_item, cart);
          _lastLoadedItemId = itemId;
        } else {
          _ensureSelectionFitsItem(_item!);
        }
        renderedFromCache = true;
        _isLoading = false;
        update();
      }
    }

    if (!renderedFromCache && isNewItem) {
      _isLoading = true;
      update();
    }

    // 2) Background revalidation: fetch fresh from network
    _isRevalidating = renderedFromCache;
    if (_isRevalidating) update();

    Item? fresh;
    try {
      fresh = await itemServiceInterface.getItemDetails(itemId, isCampaign);
    } catch (e) {
      fresh = null;
    }

    if (fresh != null) {
      _item = fresh;
      if (isNewItem) {
        initData(_item, cart);
        _lastLoadedItemId = itemId;
      } else {
        _ensureSelectionFitsItem(_item!);
      }
      setExistInCart(_item, _selectedVariations);
    }

    _isLoading = false;
    _isRevalidating = false;
    update();
  }

  void _ensureSelectionFitsItem(Item item) {
    final addOnsLen = item.addOns?.length ?? 0;
    if (_addOnActiveList.length != addOnsLen) {
      final next = List<bool>.filled(addOnsLen, false);
      for (int i = 0; i < _addOnActiveList.length && i < addOnsLen; i++) {
        next[i] = _addOnActiveList[i];
      }
      _addOnActiveList = next;
    }
    if (_addOnQtyList.length != addOnsLen) {
      final next = List<int?>.filled(addOnsLen, 1);
      for (int i = 0; i < _addOnQtyList.length && i < addOnsLen; i++) {
        next[i] = _addOnQtyList[i];
      }
      _addOnQtyList = next;
    }

    final coLen = item.choiceOptions?.length ?? 0;
    if (_variationIndex == null || _variationIndex!.length != coLen) {
      final existing = _variationIndex ?? const <int>[];
      final next = List<int>.filled(coLen, 0);
      for (int i = 0; i < existing.length && i < coLen; i++) {
        next[i] = existing[i];
      }
      _variationIndex = next;
    }

    final fvLen = item.foodVariations?.length ?? 0;
    if (_selectedVariations.length != fvLen) {
      _selectedVariations = itemServiceInterface.initializeSelectedVariation(item.foodVariations);
      _collapseVariation = itemServiceInterface.initializeCollapseVariation(item.foodVariations);
    }
  }

  void initData(Item? item, CartModel? cart) {
    _variationIndex = [];
    _addOnQtyList = [];
    _addOnActiveList = [];
    _selectedVariations = [];
    _collapseVariation = [];
    if(cart != null) {
      _quantity = cart.quantity;
      _addOnActiveList.addAll(itemServiceInterface.initializeCartAddonActiveList(cart.addOnIds, item!.addOns));
      _addOnQtyList.addAll(itemServiceInterface.initializeCartAddonsQtyList(cart.addOnIds, item.addOns));

      if(ModuleHelper.getModuleConfig(item.moduleType).newVariation!) {
        _selectedVariations.addAll(cart.foodVariations!);
        _collapseVariation.addAll(itemServiceInterface.collapseVariation(item.foodVariations!));
      }else {
        _variationIndex = itemServiceInterface.initializeCartVariationIndexes(cart.variation, item.choiceOptions);
      }
    } else {
      if(ModuleHelper.getModuleConfig(item!.moduleType).newVariation!) {
        _selectedVariations.addAll(itemServiceInterface.initializeSelectedVariation(item.foodVariations));
        _collapseVariation.addAll(itemServiceInterface.initializeCollapseVariation(item.foodVariations));
      } else {
        _variationIndex = itemServiceInterface.initializeVariationIndexes(item.choiceOptions);
      }
      _quantity = 1;
      _addOnActiveList.addAll(itemServiceInterface.initializeAddonActiveList(item.addOns));
      _addOnQtyList.addAll(itemServiceInterface.initializeAddonQtyList(item.addOns));

      setExistInCart(item, _selectedVariations, notify: true);
    }
  }

  void cartIndexSet() {
    _cartIndex = -1;
  }

  Future<int> setExistInCart(Item? item, List<List<bool?>>? selectedVariations, {bool notify = false}) async {
    String variationType = await itemServiceInterface.prepareVariationType(item!.choiceOptions, _variationIndex);

    if(ModuleHelper.getModuleConfig(ModuleHelper.getModule() != null ? ModuleHelper.getModule()!.moduleType : ModuleHelper.getCacheModule()!.moduleType).newVariation!) {
      _cartIndex = await itemServiceInterface.isExistInCartForBottomSheet(Get.find<CartController>().cartList, item.id, null, selectedVariations);
    } else {
      _cartIndex = Get.find<CartController>().isExistInCart(item.id, variationType, false, null);
    }

    if(_cartIndex != -1) {
      _quantity = Get.find<CartController>().cartList[_cartIndex].quantity;
      _addOnActiveList = itemServiceInterface.initializeCartAddonActiveList(Get.find<CartController>().cartList[_cartIndex].addOnIds, item.addOns);
      _addOnQtyList = itemServiceInterface.initializeCartAddonsQtyList(Get.find<CartController>().cartList[_cartIndex].addOnIds, item.addOns);
    } else {
      _quantity = 1;
    }
    if(notify) {
      update();
    }
    return _cartIndex;
  }

  void setAddOnQuantity(bool isIncrement, int index) {
    _addOnQtyList[index] = itemServiceInterface.setAddOnQuantity(isIncrement, _addOnQtyList[index]!);
    update();
  }

  Future<void> setQuantity(bool isIncrement, int? stock,  int? quantityLimit, {bool getxSnackBar = false}) async {
    _quantity = await itemServiceInterface.setQuantity(isIncrement, Get.find<SplashController>().configModel!.moduleConfig!.module!.stock!, stock, _quantity!, quantityLimit, getxSnackBar: getxSnackBar);
    update();
  }

  void setCartVariationIndex(int index, int i, Item? item) {
    _variationIndex![index] = i;
    _quantity = 1;
    setExistInCart(item, _selectedVariations);
    update();
  }

  void showMoreSpecificSection(int index){
    _collapseVariation[index] = !_collapseVariation[index];
    update();
  }

  void setNewCartVariationIndex(int index, int i, Item item) {
    _selectedVariations = itemServiceInterface.setNewCartVariationIndex(index, i, item.foodVariations!, _selectedVariations);
    setExistInCart(item, _selectedVariations);
    update();
  }

  int selectedVariationLength(List<List<bool?>> selectedVariations, int index) {
    return itemServiceInterface.selectedVariationLength(selectedVariations, index);
  }

  void addAddOn(bool isAdd, int index) {
    _addOnActiveList[index] = isAdd;
    update();
  }

  void setImageIndex(int index, bool notify) {
    _imageIndex = index;
    if(notify) {
      update();
    }
  }

  void setSelect(int select, bool notify){
    _productSelect = select;
    if(notify){
      update();
    }
  }

  void setImageSliderIndex(int index) {
    _imageSliderIndex = index;
    update();
  }

  double? getStartingPrice(Item item) {
    return itemServiceInterface.getStartingPrice(item);
  }

  bool isAvailable(Item item) {
    return DateConverter.isAvailable(item.availableTimeStarts, item.availableTimeEnds);
  }

  double? getDiscount(Item item) => item.discount;

  String? getDiscountType(Item item) => item.discountType;

  void navigateToItemPage(Item? item, BuildContext context, {bool inStore = false, bool isCampaign = false}) {
    if(Get.find<SplashController>().configModel!.moduleConfig!.module!.showRestaurantText! || item!.moduleType == 'food') {
      if(ResponsiveHelper.isMobile(context)) {
        Get.bottomSheet(
          ItemBottomSheet(itemId: item!.id!, inStorePage: inStore, isCampaign: isCampaign, item: item),
          backgroundColor: Colors.transparent, isScrollControlled: true,
        );
      } else {
        Get.dialog(
          Dialog(child: ItemBottomSheet(itemId: item!.id!, inStorePage: inStore, isCampaign: isCampaign, item: item)),
        );
      }
    }else {
      Get.toNamed(RouteHelper.getItemDetailsRoute(item.id, inStore, item.name!, slug: item.slug??'', isCampaign: isCampaign), arguments: ItemDetailsScreen(itemId: item.id!, inStorePage: inStore, isCampaign: isCampaign));
    }
  }

  void itemDirectlyAddToCart(Item? item, BuildContext context, {bool inStore = false, bool isCampaign = false}) {
    getItemDetails(itemId: item!.id!, isCampaign: isCampaign).then((value) {
      if (((_item!.foodVariations != null && _item!.foodVariations!.isEmpty) && _item?.moduleType == AppConstants.food) || (_item?.variations != null && _item!.variations!.isEmpty && _item?.moduleType != AppConstants.food)) {
        double price = _item!.price!;
        double discount = _item!.discount!;
        double discountPrice = PriceConverter.convertWithDiscount(price, discount, _item!.discountType)!;

        CartModel cartModel = CartModel(
          null, price, discount, [], [], (price - discountPrice), 1, [], [], isCampaign,
          _item?.stock, _item, _item?.quantityLimit,
        );

        OnlineCart onlineCart = OnlineCart(
          null, isCampaign ? null : _item?.id, isCampaign ? _item?.id : null, price.toString(),
          '', null, ModuleHelper.getModuleConfig(_item?.moduleType).newVariation! ? [] : null,
          1, [], [], [], 'Item',
        );
        if(Get.find<SplashController>().configModel!.moduleConfig!.module!.stock! && _item!.stock! <= 0){
          showCustomSnackBar('out_of_stock'.tr);
        }
        else if (Get.find<CartController>().existAnotherStoreItem(cartModel.item!.storeId, ModuleHelper.getModule() != null
            ? ModuleHelper.getModule()?.id : ModuleHelper.getCacheModule()?.id)) {
          Get.dialog(ConfirmationDialog(
            icon: Images.warning,
            title: 'are_you_sure_to_reset'.tr,
            description: Get.find<SplashController>().configModel!.moduleConfig!.module!.showRestaurantText!
                ? 'if_you_continue'.tr : 'if_you_continue_without_another_store'.tr,
            onYesPressed: () {
              Get.find<CartController>().clearCartOnline().then((success) async {
                if (success) {
                  await Get.find<CartController>().addToCartOnline(onlineCart);
                  Get.back();
                  showCartSnackBar();
                }
              });
            },
          ), barrierDismissible: false);
        } else {
          Get.find<CartController>().addToCartOnline(onlineCart);
          showCartSnackBar();
        }
      } else if(Get.find<SplashController>().configModel!.moduleConfig!.module!.showRestaurantText! || _item?.moduleType == AppConstants.food){
        if(ResponsiveHelper.isMobile(Get.context)) {
          Get.bottomSheet(
            ItemBottomSheet(itemId: _item!.id!, inStorePage: inStore, isCampaign: isCampaign),
            backgroundColor: Colors.transparent, isScrollControlled: true,
          );
        } else {
          Get.dialog(
            Dialog(child: ItemBottomSheet(itemId: _item!.id!, inStorePage: inStore, isCampaign: isCampaign)),
          );
        }
      } else {
        Get.toNamed(RouteHelper.getItemDetailsRoute(_item!.id, inStore, item.name!, slug: item.storeDetails?.slug??''), arguments: ItemDetailsScreen(itemId: _item!.id!, inStorePage: inStore));
      }
    });
  }
}