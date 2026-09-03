import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/category/domain/reposotories/category_repository_interface.dart';
import 'package:pickles_and_pies/features/category_products/domain/repositories/category_products_repository_interface.dart';

/// Repository implementation for CategoryProducts feature
/// Reuses existing CategoryRepository to avoid code duplication
class CategoryProductsRepository implements CategoryProductsRepositoryInterface {
  final CategoryRepositoryInterface categoryRepository;
  
  CategoryProductsRepository({required this.categoryRepository});

  @override
  Future<dynamic> getCategoryList({required bool allCategory, DataSourceEnum? source}) async {
    return await categoryRepository.getList(
      allCategory: allCategory,
      categoryList: true,
      source: source,
    );
  }

  @override
  Future<dynamic> getSubCategoryList(String? parentID) async {
    return await categoryRepository.getList(
      id: parentID,
      subCategoryList: true,
    );
  }

  @override
  Future<dynamic> getCategoryItemList({String? categoryID, int? offset, String? type}) async {
    return await categoryRepository.getList(
      id: categoryID,
      offset: offset,
      type: type,
      categoryItemList: true,
    );
  }
}
