import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/category/domain/models/category_model.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';

/// Service interface for CategoryProducts feature
/// Extends the functionality of CategoryService with additional methods
abstract class CategoryProductsServiceInterface {
  /// Get list of categories
  /// 
  /// [allCategory] - If true, returns all categories including inactive ones
  /// [source] - Data source (local cache or API client)
  Future<List<CategoryModel>?> getCategoryList({required bool allCategory, DataSourceEnum? source});
  
  /// Get subcategories for a parent category
  /// 
  /// [parentID] - ID of the parent category
  Future<List<CategoryModel>?> getSubCategoryList(String? parentID);

  /// Get items/products for a category
  /// 
  /// [categoryID] - ID of the category
  /// [offset] - Pagination offset
  /// [type] - Filter type (all, veg, non_veg)
  Future<ItemModel?> getCategoryItemList(String? categoryID, int offset, String type);
}
