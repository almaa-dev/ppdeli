import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pickles_and_pies/common/models/response_model.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';
import 'package:pickles_and_pies/common/widgets/custom_snackbar.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickles_and_pies/features/favourite/domain/services/favourite_service_interface.dart';

class FavouriteController extends GetxController implements GetxService {
  final FavouriteServiceInterface favouriteServiceInterface;
  FavouriteController({required this.favouriteServiceInterface});

  // ==================== SharedPreferences ====================
  SharedPreferences get _prefs => Get.find<SharedPreferences>();

  // ==================== Cache Keys ====================
  static const String _itemCacheKey = 'cached_favourite_items';
  static const String _storeCacheKey = 'cached_favourite_stores';
  static const String _itemIdCacheKey = 'cached_favourite_item_ids';
  static const String _storeIdCacheKey = 'cached_favourite_store_ids';

  List<Item?>? _wishItemList;
  List<Item?>? get wishItemList => _wishItemList;

  List<Store?>? _wishStoreList;
  List<Store?>? get wishStoreList => _wishStoreList;

  List<int?> _wishItemIdList = [];
  List<int?> get wishItemIdList => _wishItemIdList;

  List<int?> _wishStoreIdList = [];
  List<int?> get wishStoreIdList => _wishStoreIdList;

  bool _isRemoving = false;
  bool get isRemoving => _isRemoving;

  // ==================== Cache Helpers ====================

  void _saveCache() {
    try {
      if (_wishItemList != null) {
        final items = _wishItemList!.where((e) => e != null).toList();
        _prefs.setString(_itemCacheKey, jsonEncode(items.map((e) => e!.toJson()).toList()));
      } else {
        _prefs.remove(_itemCacheKey);
      }
      if (_wishStoreList != null) {
        final stores = _wishStoreList!.where((e) => e != null).toList();
        _prefs.setString(_storeCacheKey, jsonEncode(stores.map((e) => e!.toJson()).toList()));
      } else {
        _prefs.remove(_storeCacheKey);
      }
      _prefs.setString(_itemIdCacheKey, jsonEncode(_wishItemIdList));
      _prefs.setString(_storeIdCacheKey, jsonEncode(_wishStoreIdList));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving favourite cache: $e');
      }
    }
  }

  void _clearCache() {
    _prefs.remove(_itemCacheKey);
    _prefs.remove(_storeCacheKey);
    _prefs.remove(_itemIdCacheKey);
    _prefs.remove(_storeIdCacheKey);
  }

  bool _areIdListsEqual(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ==================== Add / Remove ====================

  void addToFavouriteList(Item? product, int? storeID, bool isStore, {bool getXSnackBar = false}) async {
    _isRemoving = true;
    update();

    // OPTIMISTIC LOCAL UPDATE
    if(isStore) {
      _wishStoreList ??= [];
      _wishStoreIdList.add(storeID);
      _wishStoreList!.add(Store());
    }else{
      _wishItemList ??= [];
      _wishItemList!.add(product);
      _wishItemIdList.add(product!.id);
    }

    // Persist optimistic update to cache immediately
    _saveCache();

    ResponseModel responseModel = await favouriteServiceInterface.addFavouriteList(isStore ? storeID : product!.id, isStore);
    if (responseModel.isSuccess) {
      showCustomSnackBar(responseModel.message, isError: false, getXSnackBar: getXSnackBar);
    } else {
      // ROLLBACK ON FAILURE
      if(isStore) {
        for (var storeId in _wishStoreIdList) {
          if (storeId == storeID) {
            _wishStoreIdList.removeAt(_wishStoreIdList.indexOf(storeId));
          }
        }
      }else{
        _wishItemIdList.removeWhere((id) => id == product!.id);
      }
      showCustomSnackBar(responseModel.message, isError: true, getXSnackBar: getXSnackBar);

      // Persist rollback to cache
      _saveCache();
    }
    _isRemoving = false;
    update();
  }

  void removeFromFavouriteList(int? id, bool isStore, {bool getXSnackBar = false}) async {
    _isRemoving = true;
    update();

    int idIndex = -1;
    int? storeId, itemId;
    Store? store;
    Item? item;
    if(isStore) {
      idIndex = _wishStoreIdList.indexOf(id);
      if(idIndex != -1) {
        storeId = id;
        _wishStoreIdList.removeAt(idIndex);
        store = _wishStoreList![idIndex];
        _wishStoreList!.removeAt(idIndex);
      }
    }else {
      idIndex = _wishItemIdList.indexOf(id);
      if(idIndex != -1) {
        itemId = id;
        _wishItemIdList.removeAt(idIndex);
        item = _wishItemList![idIndex];
        _wishItemList!.removeAt(idIndex);
      }
    }

    // Persist optimistic removal to cache immediately
    _saveCache();

    ResponseModel responseModel = await favouriteServiceInterface.removeFavouriteList(id, isStore);
    if (responseModel.isSuccess) {
      showCustomSnackBar(responseModel.message, isError: false, getXSnackBar: getXSnackBar);
    }
    else {
      showCustomSnackBar(responseModel.message, isError: true, getXSnackBar: getXSnackBar);
      // ROLLBACK ON FAILURE - restore removed item/store
      if(isStore) {
        _wishStoreIdList.add(storeId);
        _wishStoreList!.add(store);
      }else {
        _wishItemIdList.add(itemId);
        _wishItemList!.add(item);
      }

      // Persist restore to cache
      _saveCache();
    }
    _isRemoving = false;
    update();
  }

  // ==================== Load Favourites ====================

  Future<void> getFavouriteList() async {
    // STALE CACHE LOAD
    bool hasCache = false;
    List<Item?>? cachedItems;
    List<Store?>? cachedStores;
    List<int?> cachedItemIds = [];
    List<int?> cachedStoreIds = [];

    try {
      final String? itemsJson = _prefs.getString(_itemCacheKey);
      final String? storesJson = _prefs.getString(_storeCacheKey);
      final String? itemIdsJson = _prefs.getString(_itemIdCacheKey);
      final String? storeIdsJson = _prefs.getString(_storeIdCacheKey);

      if (itemsJson != null && itemsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(itemsJson);
        cachedItems = decoded.map((e) => Item.fromJson(e)).toList();
      }

      if (storesJson != null && storesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(storesJson);
        cachedStores = decoded.map((e) => Store.fromJson(e)).toList();
      }

      if (itemIdsJson != null && itemIdsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(itemIdsJson);
        cachedItemIds = decoded.map((e) => e is int ? e : int.tryParse(e.toString())).toList();
      }

      if (storeIdsJson != null && storeIdsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(storeIdsJson);
        cachedStoreIds = decoded.map((e) => e is int ? e : int.tryParse(e.toString())).toList();
      }

      // Validate cache consistency
      bool itemListsMatch = (cachedItems == null && cachedItemIds.isEmpty) ||
                            (cachedItems != null && cachedItems.length == cachedItemIds.length);
      bool storeListsMatch = (cachedStores == null && cachedStoreIds.isEmpty) ||
                             (cachedStores != null && cachedStores.length == cachedStoreIds.length);

      if (!itemListsMatch || !storeListsMatch) {
        _clearCache();
        hasCache = false;
      } else {
        hasCache = (cachedItems != null && cachedItems.isNotEmpty) ||
                   (cachedStores != null && cachedStores.isNotEmpty) ||
                   cachedItemIds.isNotEmpty ||
                   cachedStoreIds.isNotEmpty;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Favourite cache corrupted: $e');
      }
      _clearCache();
    }

    if (hasCache) {
      // SHOW CACHE IMMEDIATELY
      _wishItemList = cachedItems ?? [];
      _wishStoreList = cachedStores ?? [];
      _wishItemIdList = cachedItemIds;
      _wishStoreIdList = cachedStoreIds;
      update();
    } else {
      // No cache - match original behavior for loading state
      _wishItemList = null;
      _wishStoreList = null;
    }

    // BACKGROUND REVALIDATION
    try {
      Response response = await favouriteServiceInterface.getFavouriteList();

      if (response.statusCode == 200) {
        if (!hasCache) {
          // Match original behavior: update with empty lists before populating
          update();
        }

        List<Item?> freshItemList = [];
        List<Store?> freshStoreList = [];
        List<int?> freshItemIdList = [];
        List<int?> freshStoreIdList = [];

        if(response.body['item'] != null) {
          for (var item in response.body['item']) {
            if(item['module_type'] == null || !Get.find<SplashController>().getModuleConfig(item['module_type']).newVariation!
              || item['variations'] == null || item['variations'].isEmpty || (item['food_variations'] != null)){

              Item i = Item.fromJson(item);
              if(Get.find<SplashController>().module == null){
                freshItemList.addAll(favouriteServiceInterface.wishItemList(i));
                freshItemIdList.addAll(favouriteServiceInterface.wishItemIdList(i));
              }else{
                freshItemList.add(i);
                freshItemIdList.add(i.id);
              }
            }
          }
        }

        if(response.body['store'] != null) {
          for (var store in response.body['store']) {
            if(Get.find<SplashController>().module == null){
              freshStoreList.addAll(favouriteServiceInterface.wishStoreList(store));
              freshStoreIdList.addAll(favouriteServiceInterface.wishStoreIdList(store));
            }else{
              Store? s;
              try{
                s = Store.fromJson(store);
              }catch(e){
                debugPrint('exception create in store list create : $e');
              }
              if(s != null && Get.find<SplashController>().module!.id == s.moduleId) {
                freshStoreList.add(s);
                freshStoreIdList.add(s.id);
              }
            }
          }
        }

        // Smart sync - compare IDs to avoid unnecessary rebuilds
        bool hasChanged = !_areIdListsEqual(_wishItemIdList, freshItemIdList) ||
                          !_areIdListsEqual(_wishStoreIdList, freshStoreIdList);

        if (hasChanged || !hasCache) {
          _wishItemList = freshItemList;
          _wishStoreList = freshStoreList;
          _wishItemIdList = freshItemIdList;
          _wishStoreIdList = freshStoreIdList;
          // FINAL UI UPDATE
          update();
        }

        // SAVE FRESH DATA
        _saveCache();
      } else {
        if (!hasCache) {
          // API error with no cache - avoid infinite loading state
          _wishItemList = [];
          _wishStoreList = [];
          update();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Background favourite refresh failed: $e');
      }
      if (!hasCache) {
        _wishItemList = [];
        _wishStoreList = [];
        update();
      }
    }
  }

  void removeFavourite() {
    _wishItemIdList = [];
    _wishStoreIdList = [];
    _clearCache();
  }

}