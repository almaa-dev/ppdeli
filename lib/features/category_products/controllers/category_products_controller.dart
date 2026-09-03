import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/category/domain/models/category_model.dart';
import 'package:pickles_and_pies/features/category_products/domain/services/category_products_service_interface.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';

/// Controller for CategoryProductsScreen with Stale-While-Revalidate caching strategy
class CategoryProductsController extends GetxController implements GetxService {
  final CategoryProductsServiceInterface categoryProductsServiceInterface;
  
  CategoryProductsController({required this.categoryProductsServiceInterface});

  // ==================== SharedPreferences ====================
  
  SharedPreferences get _prefs => Get.find<SharedPreferences>();

  // ==================== Cache Keys ====================
  
  String get _categoryCacheKey => 'category_products_categories';
  String _subCategoryCacheKey(int parentId) => 'category_products_subcategories_$parentId';
  String _subSubCategoryCacheKey(int parentId) => 'category_products_sub_subcategories_$parentId';
  String _productCacheKey(int? categoryId, int? subCategoryId, String type, int offset) {
    final catId = categoryId?.toString() ?? 'null';
    final subId = subCategoryId?.toString() ?? 'null';
    return 'category_products_items_${catId}_${subId}_${type}_$offset';
  }

  // ==================== State Variables ====================
  
  /// List of all categories (main categories)
  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  /// Map of subcategories: parentId -> List of subcategories
  final Map<int, List<CategoryModel>> _subCategoryMap = {};
  Map<int, List<CategoryModel>> get subCategoryMap => _subCategoryMap;

  /// Map of sub-subcategories: parentId -> List of sub-subcategories
  final Map<int, List<CategoryModel>> _subSubCategoryMap = {};
  Map<int, List<CategoryModel>> get subSubCategoryMap => _subSubCategoryMap;

  /// Currently selected category index
  int _selectedCategoryIndex = 0;
  int get selectedCategoryIndex => _selectedCategoryIndex;

  /// Currently selected category
  CategoryModel? get selectedCategory => 
    _categoryList != null && _categoryList!.isNotEmpty && _selectedCategoryIndex < _categoryList!.length
      ? _categoryList![_selectedCategoryIndex] 
      : null;

  /// Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// Expansion state for accordion
  final Map<int, bool> _subCategoryExpansion = {};
  Map<int, bool> get subCategoryExpansion => _subCategoryExpansion;

  /// Track which subcategories have been loaded
  final Set<int> _loadedSubCategories = {};

  // ==================== Products State ====================
  
  /// List of products for the selected category/subcategory
  List<Item>? _productList;
  List<Item>? get productList => _productList;

  /// Loading state for products
  bool _isProductsLoading = false;
  bool get isProductsLoading => _isProductsLoading;

  /// Currently selected subcategory ID (null means all products)
  int? _selectedSubCategoryId;
  int? get selectedSubCategoryId => _selectedSubCategoryId;

  /// Offset for pagination
  int _productOffset = 1;
  int get productOffset => _productOffset;

  /// Total page size for products
  int? _productPageSize;
  int? get productPageSize => _productPageSize;

  /// Type filter (all, veg, non_veg)
  String _productType = 'all';
  String get productType => _productType;

  // ==================== Public Methods ====================

  /// Initialize controller - called from initState
  /// Uses Stale-While-Revalidate pattern
  Future<void> initialize() async {
    await getCategoryList(reload: false);
    
    // Load products for the first category after categories are loaded
    if (selectedCategory?.id != null) {
      await getProducts(categoryId: selectedCategory!.id!, reset: true);
    }
  }

  /// Get category list with Stale-While-Revalidate strategy
  /// 
  /// Pattern:
  /// 1. First call: Load from cache immediately, then fetch from API in background
  /// 2. Subsequent calls: Return cached data, refresh in background if needed
  Future<void> getCategoryList({bool reload = false}) async {
    if (_categoryList != null && !reload) {
      // Data already loaded, trigger background refresh if needed
      _refreshInBackground();
      return;
    }

    if (reload) {
      _categoryList = null;
      _subCategoryMap.clear();
      _subSubCategoryMap.clear();
      _loadedSubCategories.clear();
    }

    // First load: Get from local cache immediately
    if (_categoryList == null) {
      // STALE CACHE LOAD
      List<CategoryModel>? cachedCategories;
      bool hasCache = false;
      try {
        final String? cachedJson = _prefs.getString(_categoryCacheKey);
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(cachedJson);
          cachedCategories = decoded.map((e) => CategoryModel.fromJson(e)).toList();
          hasCache = true;
        }
      } catch (e) {
        // Cache corrupted
        if (kDebugMode) {
          print('Category cache corrupted: $e');
        }
        await _prefs.remove(_categoryCacheKey);
      }

      if (hasCache && cachedCategories != null && cachedCategories.isNotEmpty) {
        // SHOW CACHE IMMEDIATELY
        _categoryList = cachedCategories;
        _isLoading = false;
        update();
        
        // BACKGROUND REVALIDATION
        _refreshInBackground();
      } else {
        // No cache, fetch from API with current loading behavior
        _isLoading = true;
        update();
        await _fetchFromApi();
      }
    }
  }

  /// Refresh data from API in background
  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    
    try {
      List<CategoryModel>? freshCategories = await categoryProductsServiceInterface.getCategoryList(
        allCategory: true,
        source: DataSourceEnum.client,
      );

      if (freshCategories != null && freshCategories.isNotEmpty) {
        // Check if data changed
        bool hasChanged = _hasDataChanged(freshCategories);
        
        if (hasChanged) {
          if (kDebugMode) {
            print('Category data changed, updating UI');
          }
          _categoryList = freshCategories;
          // Clear subcategory cache as categories might have changed
          _subCategoryMap.clear();
          _subSubCategoryMap.clear();
          _loadedSubCategories.clear();
          // FINAL UI UPDATE
          update();
        }

        // SAVE FRESH DATA
        try {
          final String encoded = jsonEncode(freshCategories.map((e) => e.toJson()).toList());
          await _prefs.setString(_categoryCacheKey, encoded);
        } catch (e) {
          if (kDebugMode) {
            print('Error saving category cache: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background refresh failed: $e');
      }
      // Silent fail - user already has cached data
    } finally {
      _isRefreshing = false;
    }
  }

  /// Fetch categories from API directly
  Future<void> _fetchFromApi() async {
    try {
      List<CategoryModel>? categories = await categoryProductsServiceInterface.getCategoryList(
        allCategory: true,
        source: DataSourceEnum.client,
      );

      if (categories != null && categories.isNotEmpty) {
        _categoryList = categories;

        // SAVE FRESH DATA
        try {
          final String encoded = jsonEncode(categories.map((e) => e.toJson()).toList());
          await _prefs.setString(_categoryCacheKey, encoded);
        } catch (e) {
          if (kDebugMode) {
            print('Error saving category cache: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching categories: $e');
      }
    } finally {
      _isLoading = false;
      // FINAL UI UPDATE
      update();
    }
  }

  /// Check if fresh data differs from cached data
  bool _hasDataChanged(List<CategoryModel> freshCategories) {
    if (_categoryList == null) return true;
    if (_categoryList!.length != freshCategories.length) return true;
    
    for (int i = 0; i < freshCategories.length; i++) {
      if (i >= _categoryList!.length) return true;
      if (_categoryList![i].id != freshCategories[i].id) return true;
      if (_categoryList![i].name != freshCategories[i].name) return true;
    }
    
    return false;
  }

  /// Get subcategories for a parent category
  /// Uses lazy loading with cache
  Future<void> getSubCategories(int parentId) async {
    // Already loaded
    if (_subCategoryMap.containsKey(parentId)) return;
    
    // Already loading
    if (_loadedSubCategories.contains(parentId)) return;
    
    _loadedSubCategories.add(parentId);
    
    // STALE CACHE LOAD
    List<CategoryModel>? cachedSubCategories;
    bool hasCache = false;
    try {
      final String? cachedJson = _prefs.getString(_subCategoryCacheKey(parentId));
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        cachedSubCategories = decoded.map((e) => CategoryModel.fromJson(e)).toList();
        hasCache = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Subcategory cache corrupted for $parentId: $e');
      }
      await _prefs.remove(_subCategoryCacheKey(parentId));
    }

    if (hasCache && cachedSubCategories != null) {
      // SHOW CACHE IMMEDIATELY
      _subCategoryMap[parentId] = cachedSubCategories;
      
      // Initialize expansion state to collapsed
      for (var sub in cachedSubCategories) {
        if (sub.id != null) {
          _subCategoryExpansion[sub.id!] = false;
        }
      }
      
      update();
      
      // BACKGROUND REVALIDATION
      _refreshSubCategoriesInBackground(parentId);
    } else {
      // No cache, use current loading behavior
      try {
        List<CategoryModel>? subCategories = await categoryProductsServiceInterface.getSubCategoryList(parentId.toString());
        
        if (subCategories != null) {
          _subCategoryMap[parentId] = subCategories;
          
          // Initialize expansion state to collapsed
          for (var sub in subCategories) {
            if (sub.id != null) {
              _subCategoryExpansion[sub.id!] = false;
            }
          }
          
          update();

          // SAVE FRESH DATA
          try {
            final String encoded = jsonEncode(subCategories.map((e) => e.toJson()).toList());
            await _prefs.setString(_subCategoryCacheKey(parentId), encoded);
          } catch (e) {
            if (kDebugMode) {
              print('Error saving subcategory cache: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading subcategories for $parentId: $e');
        }
        _loadedSubCategories.remove(parentId);
      }
    }
  }

  /// Refresh subcategories from API in background
  Future<void> _refreshSubCategoriesInBackground(int parentId) async {
    try {
      List<CategoryModel>? freshSubCategories = await categoryProductsServiceInterface.getSubCategoryList(parentId.toString());
      
      if (freshSubCategories != null) {
        bool hasChanged = _hasSubCategoryListChanged(parentId, freshSubCategories);
        
        if (hasChanged) {
          _subCategoryMap[parentId] = freshSubCategories;
          
          // Initialize expansion state for new subcategories only
          for (var sub in freshSubCategories) {
            if (sub.id != null && !_subCategoryExpansion.containsKey(sub.id!)) {
              _subCategoryExpansion[sub.id!] = false;
            }
          }
          
          // FINAL UI UPDATE
          update();
        }

        // SAVE FRESH DATA
        try {
          final String encoded = jsonEncode(freshSubCategories.map((e) => e.toJson()).toList());
          await _prefs.setString(_subCategoryCacheKey(parentId), encoded);
        } catch (e) {
          if (kDebugMode) {
            print('Error saving subcategory cache: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background subcategory refresh failed for $parentId: $e');
      }
      // Silent fail - user already has cached data
    }
  }

  /// Check if subcategory list has changed
  bool _hasSubCategoryListChanged(int parentId, List<CategoryModel> freshSubCategories) {
    final cached = _subCategoryMap[parentId];
    if (cached == null) return true;
    if (cached.length != freshSubCategories.length) return true;
    
    for (int i = 0; i < freshSubCategories.length; i++) {
      if (i >= cached.length) return true;
      if (cached[i].id != freshSubCategories[i].id) return true;
      if (cached[i].name != freshSubCategories[i].name) return true;
    }
    
    return false;
  }

  /// Get sub-subcategories for a parent subcategory
  Future<void> getSubSubCategories(int parentId) async {
    // Already loaded
    if (_subSubCategoryMap.containsKey(parentId)) return;
    
    // STALE CACHE LOAD
    List<CategoryModel>? cachedSubSubCategories;
    bool hasCache = false;
    try {
      final String? cachedJson = _prefs.getString(_subSubCategoryCacheKey(parentId));
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        cachedSubSubCategories = decoded.map((e) => CategoryModel.fromJson(e)).toList();
        hasCache = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sub-subcategory cache corrupted for $parentId: $e');
      }
      await _prefs.remove(_subSubCategoryCacheKey(parentId));
    }

    if (hasCache && cachedSubSubCategories != null) {
      // SHOW CACHE IMMEDIATELY
      _subSubCategoryMap[parentId] = cachedSubSubCategories;
      update();
      
      // BACKGROUND REVALIDATION
      _refreshSubSubCategoriesInBackground(parentId);
    } else {
      // No cache, use current loading behavior
      try {
        List<CategoryModel>? subSubCategories = await categoryProductsServiceInterface.getSubCategoryList(parentId.toString());
        
        if (subSubCategories != null) {
          _subSubCategoryMap[parentId] = subSubCategories;
          update();

          // SAVE FRESH DATA
          try {
            final String encoded = jsonEncode(subSubCategories.map((e) => e.toJson()).toList());
            await _prefs.setString(_subSubCategoryCacheKey(parentId), encoded);
          } catch (e) {
            if (kDebugMode) {
              print('Error saving sub-subcategory cache: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading sub-subcategories for $parentId: $e');
        }
      }
    }
  }

  /// Refresh sub-subcategories from API in background
  Future<void> _refreshSubSubCategoriesInBackground(int parentId) async {
    try {
      List<CategoryModel>? freshSubSubCategories = await categoryProductsServiceInterface.getSubCategoryList(parentId.toString());
      
      if (freshSubSubCategories != null) {
        bool hasChanged = _hasSubSubCategoryListChanged(parentId, freshSubSubCategories);
        
        if (hasChanged) {
          _subSubCategoryMap[parentId] = freshSubSubCategories;
          // FINAL UI UPDATE
          update();
        }

        // SAVE FRESH DATA
        try {
          final String encoded = jsonEncode(freshSubSubCategories.map((e) => e.toJson()).toList());
          await _prefs.setString(_subSubCategoryCacheKey(parentId), encoded);
        } catch (e) {
          if (kDebugMode) {
            print('Error saving sub-subcategory cache: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background sub-subcategory refresh failed for $parentId: $e');
      }
      // Silent fail - user already has cached data
    }
  }

  /// Check if sub-subcategory list has changed
  bool _hasSubSubCategoryListChanged(int parentId, List<CategoryModel> freshSubSubCategories) {
    final cached = _subSubCategoryMap[parentId];
    if (cached == null) return true;
    if (cached.length != freshSubSubCategories.length) return true;
    
    for (int i = 0; i < freshSubSubCategories.length; i++) {
      if (i >= cached.length) return true;
      if (cached[i].id != freshSubSubCategories[i].id) return true;
      if (cached[i].name != freshSubSubCategories[i].name) return true;
    }
    
    return false;
  }

  /// Select a category by index
  void selectCategory(int index) {
    if (index < 0 || (_categoryList != null && index >= _categoryList!.length)) return;
    
    _selectedCategoryIndex = index;
    _selectedSubCategoryId = null; // Reset subcategory selection
    _productList = null;
    _productOffset = 1;
    
    // Pre-load subcategories for selected category
    final selectedCat = selectedCategory;
    if (selectedCat?.id != null) {
      getSubCategories(selectedCat!.id!);
      // Load products for this category
      getProducts(categoryId: selectedCat.id!, reset: true);
    }
    
    update();
  }

  // ==================== Products Methods ====================

  /// Get products for a category or subcategory
  /// 
  /// [categoryId] - The category ID to fetch products for
  /// [subCategoryId] - Optional subcategory ID to filter products
  /// [reset] - If true, clears existing products and starts from offset 1
  Future<void> getProducts({
    int? categoryId,
    int? subCategoryId,
    bool reset = false,
    String? type,
  }) async {
    // Determine which ID to use
    final targetId = subCategoryId ?? categoryId ?? selectedCategory?.id;
    if (targetId == null) return;

    // Update type if provided
    if (type != null) {
      _productType = type;
    }

    // Reset if needed
    if (reset) {
      _productOffset = 1;
      _productList = null;
      _selectedSubCategoryId = subCategoryId;
    }

    // Don't load if already loading
    if (_isProductsLoading) return;

    // Determine main category ID for cache key
    final mainCategoryId = selectedCategory?.id;

    // STALE CACHE LOAD
    List<Item>? cachedItems;
    ItemModel? cachedItemModel;
    bool hasCache = false;
    int previousListLength = _productList?.length ?? 0;
    
    try {
      final String cacheKey = _productCacheKey(mainCategoryId, _selectedSubCategoryId, _productType, _productOffset);
      final String? cachedJson = _prefs.getString(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        cachedItemModel = ItemModel.fromJson(jsonDecode(cachedJson));
        cachedItems = cachedItemModel.items;
        hasCache = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Product cache corrupted: $e');
      }
      await _prefs.remove(_productCacheKey(mainCategoryId, _selectedSubCategoryId, _productType, _productOffset));
    }

    if (hasCache && cachedItems != null) {
      // SHOW CACHE IMMEDIATELY
      if (_productList == null || reset) {
        _productList = [];
        _productPageSize = cachedItemModel?.totalSize;
      }
      _productList!.addAll(cachedItems);
      update();
      
      // BACKGROUND REVALIDATION
      _refreshProductsInBackground(mainCategoryId, _selectedSubCategoryId, _productType, _productOffset, previousListLength, cachedItems);
    } else {
      // No cache, use current loading behavior
      _isProductsLoading = true;
      update();

      try {
        final itemModel = await categoryProductsServiceInterface.getCategoryItemList(
          targetId.toString(),
          _productOffset,
          _productType,
        );

        if (itemModel != null && itemModel.items != null) {
          if (_productList == null || reset) {
            _productList = [];
          }
          _productList!.addAll(itemModel.items!);
          _productPageSize = itemModel.totalSize;

          // SAVE FRESH DATA
          try {
            final String cacheKey = _productCacheKey(mainCategoryId, _selectedSubCategoryId, _productType, _productOffset);
            await _prefs.setString(cacheKey, jsonEncode(itemModel.toJson()));
          } catch (e) {
            if (kDebugMode) {
              print('Error saving product cache: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading products: $e');
        }
      } finally {
        _isProductsLoading = false;
        // FINAL UI UPDATE
        update();
      }
    }
  }

  /// Refresh products from API in background
  Future<void> _refreshProductsInBackground(
    int? categoryId,
    int? subCategoryId,
    String type,
    int offset,
    int previousListLength,
    List<Item>? cachedItems,
  ) async {
    final targetId = subCategoryId ?? categoryId;
    if (targetId == null) return;
    
    try {
      final itemModel = await categoryProductsServiceInterface.getCategoryItemList(
        targetId.toString(),
        offset,
        type,
      );

      if (itemModel != null && itemModel.items != null) {
        bool hasChanged = _hasProductPageChanged(cachedItems, itemModel);
        
        if (hasChanged && _productList != null && _productList!.length >= previousListLength) {
          // Truncate back to previous length and append fresh data
          if (_productList!.length > previousListLength) {
            _productList!.removeRange(previousListLength, _productList!.length);
          }
          _productList!.addAll(itemModel.items!);
          _productPageSize = itemModel.totalSize;
          // FINAL UI UPDATE
          update();
        }

        // SAVE FRESH DATA
        try {
          final String cacheKey = _productCacheKey(categoryId, subCategoryId, type, offset);
          await _prefs.setString(cacheKey, jsonEncode(itemModel.toJson()));
        } catch (e) {
          if (kDebugMode) {
            print('Error saving product cache: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background product refresh failed: $e');
      }
      // Silent fail - user already has cached data
    }
  }

  /// Check if product page has changed
  bool _hasProductPageChanged(List<Item>? cachedItems, ItemModel freshModel) {
    if (cachedItems == null) return true;
    if (freshModel.items == null) return true;
    if (cachedItems.length != freshModel.items!.length) return true;
    
    for (int i = 0; i < cachedItems.length; i++) {
      if (cachedItems[i].id != freshModel.items![i].id) return true;
    }
    
    return false;
  }

  /// Select a subcategory and load its products
  /// 
  /// [subCategoryId] - The subcategory ID to select
  void selectSubCategory(int? subCategoryId) {
    // If selecting the same subcategory, do nothing
    if (_selectedSubCategoryId == subCategoryId) return;

    _selectedSubCategoryId = subCategoryId;
    _productOffset = 1;
    _productList = null;
    
    // Load products for the selected subcategory
    if (selectedCategory?.id != null) {
      getProducts(
        categoryId: selectedCategory!.id!,
        subCategoryId: subCategoryId,
        reset: true,
      );
    }
    
    update();
  }

  /// Load more products (pagination)
  Future<void> loadMoreProducts() async {
    if (_isProductsLoading) return;
    if (_productPageSize == null) return;
    
    final maxPage = (_productPageSize! / 10).ceil();
    if (_productOffset >= maxPage) return;

    _productOffset++;
    await getProducts(reset: false);
  }

  /// Set product type filter (all, veg, non_veg)
  void setProductType(String type) {
    if (_productType == type) return;
    
    _productType = type;
    _productOffset = 1;
    _productList = null;
    
    // Reload products with new filter
    if (selectedCategory?.id != null) {
      getProducts(
        categoryId: selectedCategory!.id!,
        subCategoryId: _selectedSubCategoryId,
        reset: true,
      );
    }
    
    update();
  }

  /// Check if a subcategory is selected
  bool isSubCategorySelected(int subCategoryId) {
    return _selectedSubCategoryId == subCategoryId;
  }

  /// Get filtered products based on selected subcategory
  List<Item>? get filteredProducts {
    return _productList;
  }

  /// Clear products list
  void clearProducts() {
    _productList = null;
    _selectedSubCategoryId = null;
    _productOffset = 1;
    _productPageSize = null;
    update();
  }

  /// Toggle accordion expansion for a subcategory
  void toggleSubCategoryExpansion(int subCategoryId) {
    _subCategoryExpansion[subCategoryId] = !(_subCategoryExpansion[subCategoryId] ?? false);
    
    // Load sub-subcategories if expanding
    if (_subCategoryExpansion[subCategoryId] == true) {
      getSubSubCategories(subCategoryId);
    }
    
    update();
  }

  /// Check if a subcategory is expanded
  bool isSubCategoryExpanded(int subCategoryId) {
    return _subCategoryExpansion[subCategoryId] ?? false;
  }

  /// Get subcategories for currently selected category
  List<CategoryModel>? get currentSubCategories {
    final selectedCat = selectedCategory;
    if (selectedCat?.id == null) return null;
    return _subCategoryMap[selectedCat!.id!];
  }

  /// Get sub-subcategories for a specific subcategory
  List<CategoryModel>? getSubSubCategoriesForParent(int parentId) {
    return _subSubCategoryMap[parentId];
  }

  /// Clear all data (for logout or module change)
  void clearData() {
    _categoryList = null;
    _subCategoryMap.clear();
    _subSubCategoryMap.clear();
    _selectedCategoryIndex = 0;
    _loadedSubCategories.clear();
    _subCategoryExpansion.clear();
    update();
  }

  /// Force refresh all data
  Future<void> refreshAll() async {
    await getCategoryList(reload: true);
  }

  @override
  void onClose() {
    // Controller lifecycle cleanup if needed
    super.onClose();
  }
}