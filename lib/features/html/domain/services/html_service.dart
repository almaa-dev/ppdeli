import 'package:get/get.dart';
import 'package:pickles_and_pies/features/html/domain/repositories/html_repository_interface.dart';
import 'package:pickles_and_pies/features/html/domain/services/html_service_interface.dart';
import 'package:pickles_and_pies/util/html_type.dart';

class HtmlService implements HtmlServiceInterface {
  final HtmlRepositoryInterface htmlRepositoryInterface;
  HtmlService({required this.htmlRepositoryInterface});

  @override
  Future<Response> getHtmlText(HtmlType htmlType) async {
    return await htmlRepositoryInterface.getHtmlText(htmlType);
  }

}