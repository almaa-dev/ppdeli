import 'package:get/get.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/category/domain/models/category_model.dart';
import 'package:pickles_and_pies/features/category_products/domain/repositories/category_products_repository_interface.dart';
import 'package:pickles_and_pies/features/category_products/domain/services/category_products_service_interface.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';

/// Service implementation for CategoryProducts feature
/// Handles business logic and data transformation
class CategoryProductsService implements CategoryProductsServiceInterface {
  final CategoryProductsRepositoryInterface categoryProductsRepository;
  
  CategoryProductsService({required this.categoryProductsRepository});

  @override
  Future<List<CategoryModel>?> getCategoryList({required bool allCategory, DataSourceEnum? source}) async {
    final response = await categoryProductsRepository.getCategoryList(
      allCategory: allCategory,
      source: source,
    );
    
    // If response is already a List<CategoryModel>, return it directly
    if (response is List<CategoryModel>) {
      return response;
    }
    
    // If response is a List of Maps (JSON data), parse it
    if (response is List) {
      return response.map((item) {
        if (item is CategoryModel) {
          return item;
        }
        return CategoryModel.fromJson(item as Map<String, dynamic>);
      }).toList();
    }
    
    // If response is a GetX Response object
    if (response is Response && response.statusCode == 200) {
      if (response.body is List) {
        return (response.body as List).map((item) {
          if (item is CategoryModel) {
            return item;
          }
          return CategoryModel.fromJson(item as Map<String, dynamic>);
        }).toList();
      }
    }
    
    return null;
  }

  @override
  Future<List<CategoryModel>?> getSubCategoryList(String? parentID) async {
    final response = await categoryProductsRepository.getSubCategoryList(parentID);
    
    // If response is already a List<CategoryModel>, return it directly
    if (response is List<CategoryModel>) {
      return response;
    }
    
    // If response is a List of Maps (JSON data), parse it
    if (response is List) {
      return response.map((item) {
        if (item is CategoryModel) {
          return item;
        }
        return CategoryModel.fromJson(item as Map<String, dynamic>);
      }).toList();
    }
    
    // If response is a GetX Response object
    if (response is Response && response.statusCode == 200) {
      if (response.body is List) {
        return (response.body as List).map((item) {
          if (item is CategoryModel) {
            return item;
          }
          return CategoryModel.fromJson(item as Map<String, dynamic>);
        }).toList();
      }
    }
    
    return null;
  }

  @override
  Future<ItemModel?> getCategoryItemList(String? categoryID, int offset, String type) async {
    final response = await categoryProductsRepository.getCategoryItemList(
      categoryID: categoryID,
      offset: offset,
      type: type,
    );
    
    // If response is already an ItemModel, return it directly
    if (response is ItemModel) {
      return response;
    }
    
    // If response is a Map (JSON data), parse it
    if (response is Map<String, dynamic>) {
      return ItemModel.fromJson(response);
    }
    
    // If response is a GetX Response object
    if (response is Response && response.statusCode == 200) {
      if (response.body is Map<String, dynamic>) {
        return ItemModel.fromJson(response.body as Map<String, dynamic>);
      }
    }
    
    return null;
  }
}
