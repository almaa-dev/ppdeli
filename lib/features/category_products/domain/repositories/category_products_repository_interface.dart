import 'package:pickles_and_pies/common/enums/data_source_enum.dart';

/// Repository interface for CategoryProducts feature
/// Reuses existing CategoryRepositoryInterface methods
abstract class CategoryProductsRepositoryInterface {
  /// Get category list
  /// 
  /// [allCategory] - If true, returns all categories
  /// [source] - Data source (local cache or API client)
  Future<dynamic> getCategoryList({required bool allCategory, DataSourceEnum? source});
  
  /// Get subcategory list
  /// 
  /// [parentID] - ID of the parent category
  Future<dynamic> getSubCategoryList(String? parentID);

  /// Get items/products for a category
  /// 
  /// [categoryID] - ID of the category
  /// [offset] - Pagination offset
  /// [type] - Filter type (all, veg, non_veg)
  Future<dynamic> getCategoryItemList({String? categoryID, int? offset, String? type});
}
