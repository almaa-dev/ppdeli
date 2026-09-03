import 'package:pickles_and_pies/features/search/domain/models/popular_categories_model.dart';
import 'package:pickles_and_pies/features/search/domain/models/search_suggestion_model.dart';
import 'package:pickles_and_pies/interfaces/repository_interface.dart';

abstract class SearchRepositoryInterface extends RepositoryInterface {
  Future<bool> saveSearchHistory(List<String> searchHistories);
  List<String> getSearchAddress();
  Future<bool> clearSearchHistory();
  @override
  Future getList({int? offset, String? query, bool? isStore, bool isSuggestedItems = false});
  Future<SearchSuggestionModel?> getSearchSuggestions(String searchText);
  Future<List<PopularCategoryModel?>?> getPopularCategories();
}