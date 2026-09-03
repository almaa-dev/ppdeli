import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/common/models/module_model.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_details_result.dart';
import 'package:pickles_and_pies/interfaces/repository_interface.dart';

abstract class StoreRepositoryInterface extends RepositoryInterface {
  @override
  Future getList({int? offset, bool isStoreList = false, String? filterBy, bool isPopularStoreList = false, String? type, bool isLatestStoreList = false,
    bool isFeaturedStoreList = false, bool isVisitAgainStoreList = false, bool isStoreRecommendedItemList = false, int? storeId,
    bool isStoreBannerList = false, bool isRecommendedStoreList = false, bool isTopOfferStoreList = false, DataSourceEnum? source});
  Future<StoreDetailsResult?> getStoreDetails(String storeID, bool fromCart, String slug, String languageCode, ModuleModel? module, int? cacheModuleId, int? moduleId, {bool handleError = true});
  Future<dynamic> getStoreItemList({int? storeID, required int offset, int? categoryID, String? type, List<String>? filter, int? rating, double? lowerValue, double? upperValue});
  Future<dynamic> getStoreSearchItemList(String searchText, String? storeID, int offset, String type, int? categoryID);
  Future<dynamic> getCartStoreSuggestedItemList(int? storeId, String languageCode, ModuleModel? module, int? cacheModuleId, int? moduleId);
}