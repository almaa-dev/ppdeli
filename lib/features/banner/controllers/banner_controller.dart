import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/banner/domain/models/banner_model.dart';
import 'package:pickles_and_pies/features/banner/domain/models/others_banner_model.dart';
import 'package:pickles_and_pies/features/banner/domain/models/promotional_banner_model.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/features/banner/domain/services/banner_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BannerController extends GetxController implements GetxService {
  final BannerServiceInterface bannerServiceInterface;
  BannerController({required this.bannerServiceInterface});

  // ============================================================
  //  CACHE METADATA — versioned keys + TTL (NEW)
  // ============================================================
  static const String bannerCacheKey = "cache_banners_v1";
  static const String bannerCacheTimeKey = "cache_banners_timestamp";
  static const Duration _cacheTtl = Duration(hours: 24);

  // ============================================================
  //  PUBLIC GETTERS — أسماء المتغيرات العامة لم تتغير
  // ============================================================
  List<String?>? _bannerImageList;
  List<String?>? get bannerImageList => _bannerImageList;

  List<String?>? _taxiBannerImageList;
  List<String?>? get taxiBannerImageList => _taxiBannerImageList;

  List<String?>? _featuredBannerList;
  List<String?>? get featuredBannerList => _featuredBannerList;

  List<dynamic>? _bannerDataList;
  List<dynamic>? get bannerDataList => _bannerDataList;

  List<dynamic>? _taxiBannerDataList;
  List<dynamic>? get taxiBannerDataList => _taxiBannerDataList;

  List<dynamic>? _featuredBannerDataList;
  List<dynamic>? get featuredBannerDataList => _featuredBannerDataList;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  ParcelOtherBannerModel? _parcelOtherBannerModel;
  ParcelOtherBannerModel? get parcelOtherBannerModel => _parcelOtherBannerModel;

  PromotionalBanner? _promotionalBanner;
  PromotionalBanner? get promotionalBanner => _promotionalBanner;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ============================================================
  //  INTERNAL FLAG — منع تكرار طلبات الـ API (NEW)
  // ============================================================
  bool _isRefreshing = false;

  // ============================================================
  //  UNCHANGED METHOD — getFeaturedBanner (لم يتغير)
  // ============================================================
  Future<void> getFeaturedBanner() async {
    BannerModel? bannerModel = await bannerServiceInterface.getFeaturedBannerList();
    if (bannerModel != null) {
      _featuredBannerList = [];
      _featuredBannerDataList = [];

      List<int?> moduleIdList = bannerServiceInterface.moduleIdList();

      for (var campaign in bannerModel.campaigns!) {
        if(_featuredBannerList!.contains(campaign.imageFullUrl)) {
          _featuredBannerList!.add('${campaign.imageFullUrl}${bannerModel.campaigns!.indexOf(campaign)}');
        } else {
          _featuredBannerList!.add(campaign.imageFullUrl);
        }
        _featuredBannerDataList!.add(campaign);
      }
      for (var banner in bannerModel.banners!) {
        if(_featuredBannerList!.contains(banner.imageFullUrl)) {
          _featuredBannerList!.add('${banner.imageFullUrl}${bannerModel.banners!.indexOf(banner)}');
        } else {
          _featuredBannerList!.add(banner.imageFullUrl);
        }
        if(banner.item != null && moduleIdList.contains(banner.item!.moduleId)) {
          _featuredBannerDataList!.add(banner.item);
        }else if(banner.store != null && moduleIdList.contains(banner.store!.moduleId)) {
          _featuredBannerDataList!.add(banner.store);
        }else if(banner.type == 'default') {
          _featuredBannerDataList!.add(banner.link);
        }else{
          _featuredBannerDataList!.add(null);
        }
      }
    }
    update();
  }

  // ============================================================
  //  UNCHANGED METHOD — clearBanner (لم يتغير)
  // ============================================================
  void clearBanner() {
    _bannerImageList = null;
  }

  // ============================================================
  //  ⭐ MODIFIED: getBannerList — Stale-While-Revalidate (SWR)
  // ============================================================
  Future<void> getBannerList(bool reload, {DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    if (_bannerImageList == null || reload || fromRecall) {
      if (reload) {
        _bannerImageList = null;
      }

      // ---------- PHASE 1: Show cache immediately (0-100ms) ----------
      bool hasCache = false;
      BannerModel? cachedModel;

      if (dataSource == DataSourceEnum.local && !fromRecall) {
        cachedModel = await getBannerCache();
        if (cachedModel != null) {
          _prepareBanner(cachedModel);
          hasCache = true;
          if (kDebugMode) {
            print('[BANNER_CACHE] Loaded ${cachedModel.banners?.length ?? 0} banners');
          }
        }
      }

      // Only show loading if there is no cache to show
      if (!hasCache && dataSource == DataSourceEnum.local && !fromRecall) {
        _isLoading = true;
        update();
      }

      // ---------- PHASE 2: Prevent duplicate concurrent refresh ----------
      if (_isRefreshing) {
        if (_isLoading) {
          _isLoading = false;
          update();
        }
        return;
      }
      _isRefreshing = true;

      try {
        // ---------- PHASE 3: Background API revalidation ----------
        BannerModel? freshModel = await bannerServiceInterface.getBannerList(
          source: DataSourceEnum.client,
        );

        if (freshModel != null) {
          if (kDebugMode) {
            print('[BANNER_API] Fetched ${freshModel.banners?.length ?? 0} banners');
          }

          // ---------- PHASE 4: Diff — only rebuild if data changed ----------
          if (_hasBannerDataChanged(cachedModel, freshModel)) {
            await saveBannerCache(freshModel);
            _prepareBanner(freshModel);
            if (kDebugMode) {
              print('[BANNER_CACHE] Updated successfully');
            }
          }
          // else: silent — no rebuild, no UI work
        } else if (hasCache) {
          // API failed → keep current cached UI silently (Offline-First)
          if (kDebugMode) {
            print('[BANNER_CACHE] Using offline cache');
          }
        }
      } catch (e) {
        // Silent failure: never clear UI on API error
        if (hasCache) {
          if (kDebugMode) {
            print('[BANNER_CACHE] Using offline cache');
          }
        }
      } finally {
        _isRefreshing = false;
        if (_isLoading) {
          _isLoading = false;
          update();
        }
      }
    }
  }

  // ============================================================
  //  ⭐ MODIFIED: _prepareBanner — now void (no Future overhead)
  //  نفس البيانات بالضبط — لا List جديد إلا عند الحاجة
  // ============================================================
  void _prepareBanner(BannerModel? bannerModel) {
    if (bannerModel == null) return;
    if (bannerModel.campaigns == null && bannerModel.banners == null) return;

    final campaigns = bannerModel.campaigns ?? const [];
    final banners = bannerModel.banners ?? const [];

    // Build local lists once, assign once → safer than mutating shared lists
    final newImageList = <String?>[];
    final newDataList = <dynamic>[];

    for (int i = 0; i < campaigns.length; i++) {
      final campaign = campaigns[i];
      if (newImageList.contains(campaign.imageFullUrl)) {
        newImageList.add('${campaign.imageFullUrl}$i');
      } else {
        newImageList.add(campaign.imageFullUrl);
      }
      newDataList.add(campaign);
    }

    for (int i = 0; i < banners.length; i++) {
      final banner = banners[i];
      if (newImageList.contains(banner.imageFullUrl)) {
        newImageList.add('${banner.imageFullUrl}$i');
      } else {
        newImageList.add(banner.imageFullUrl);
      }

      if (banner.item != null) {
        newDataList.add(banner.item);
      } else if (banner.store != null) {
        newDataList.add(banner.store);
      } else if (banner.type == 'default') {
        newDataList.add(banner.link);
      } else {
        newDataList.add(null);
      }
    }

    // Single atomic assignment → no UI flicker
    _bannerImageList = newImageList;
    _bannerDataList = newDataList;
    update();
  }

  // ============================================================
  //  ⭐ NEW: Diff helper — JSON-level comparison
  // ============================================================
  bool _hasBannerDataChanged(BannerModel? oldModel, BannerModel? newModel) {
    if (oldModel == null || newModel == null) return true;
    try {
      return jsonEncode(oldModel.toJson()) != jsonEncode(newModel.toJson());
    } catch (_) {
      return true; // on parsing error, treat as changed to be safe
    }
  }

  // ============================================================
  //  ⭐ NEW: Cache persistence helpers
  // ============================================================

  /// Saves BannerModel as JSON + writes timestamp atomically.
  Future<void> saveBannerCache(BannerModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(bannerCacheKey, jsonEncode(model.toJson()));
      await prefs.setInt(
        bannerCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Silent: cache writes are best-effort
    }
  }

  /// Returns BannerModel from cache (even if stale — SWR semantics).
  /// Caller is responsible for refreshing in the background.
  Future<BannerModel?> getBannerCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(bannerCacheKey);
      if (raw == null || raw.isEmpty) return null;
      return BannerModel.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Wipes both the cached payload and its timestamp.
  Future<void> clearBannerCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(bannerCacheKey);
      await prefs.remove(bannerCacheTimeKey);
    } catch (_) {
      // Silent
    }
  }

  /// Diagnostic: returns true if cache is within the 24h TTL window.
  /// Note: SWR always returns stale cache for display; this is for monitoring only.
  bool isCacheFresh() {
    try {
      final prefs = Get.find<SharedPreferences>();
      final ts = prefs.getInt(bannerCacheTimeKey);
      if (ts == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age < _cacheTtl.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  //  UNCHANGED METHODS — لم تتغير (taxi/parcel/promo/setCurrentIndex)
  // ============================================================

  Future<void> getTaxiBannerList(bool reload) async {
    if(_taxiBannerImageList == null || reload) {
      _taxiBannerImageList = null;
      BannerModel? bannerModel = await bannerServiceInterface.getTaxiBannerList();
      if (bannerModel != null) {
        _taxiBannerImageList = [];
        _taxiBannerDataList = [];
        for (var campaign in bannerModel.campaigns!) {
          _taxiBannerImageList!.add(campaign.imageFullUrl);
          _taxiBannerDataList!.add(campaign);
        }
        for (var banner in bannerModel.banners!) {
          _taxiBannerImageList!.add(banner.imageFullUrl);
          if(banner.item != null) {
            _taxiBannerDataList!.add(banner.item);
          }else if(banner.store != null){
            _taxiBannerDataList!.add(banner.store);
          }else if(banner.type == 'default'){
            _taxiBannerDataList!.add(banner.link);
          }else{
            _taxiBannerDataList!.add(null);
          }
        }
        if(ResponsiveHelper.isDesktop(Get.context) && _taxiBannerImageList!.length % 2 != 0){
          _taxiBannerImageList!.add(_taxiBannerImageList![0]);
          _taxiBannerDataList!.add(_taxiBannerDataList![0]);
        }
      }
      update();
    }
  }

  Future<void> getParcelOtherBannerList(bool reload, {DataSourceEnum dataSource = DataSourceEnum.local, bool fromRecall = false}) async {
    if(_parcelOtherBannerModel == null || reload || fromRecall) {
      ParcelOtherBannerModel? parcelOtherBannerModel;
      if(dataSource == DataSourceEnum.local) {
        parcelOtherBannerModel = await bannerServiceInterface.getParcelOtherBannerList(source: dataSource);
        _prepareParcelBanner(parcelOtherBannerModel);
        getParcelOtherBannerList(false, dataSource: DataSourceEnum.client, fromRecall: true);
      } else {
        parcelOtherBannerModel = await bannerServiceInterface.getParcelOtherBannerList(source: dataSource);
        _prepareParcelBanner(parcelOtherBannerModel);
      }
    }
  }

  void _prepareParcelBanner(ParcelOtherBannerModel? parcelOtherBannerModel) {
    if (parcelOtherBannerModel != null) {
      _parcelOtherBannerModel = parcelOtherBannerModel;
    }
    update();
  }

  Future<void> getPromotionalBannerList(bool reload) async {
    if(_promotionalBanner == null || reload) {
      PromotionalBanner? promotionalBanner = await bannerServiceInterface.getPromotionalBannerList();
      if (promotionalBanner != null) {
        _promotionalBanner = promotionalBanner;
      }
      update();
    }
  }

  void setCurrentIndex(int index, bool notify) {
    _currentIndex = index;
    if(notify) {
      update();
    }
  }
}
