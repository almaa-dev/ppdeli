import 'package:get/get.dart';
import 'package:pickles_and_pies/util/html_type.dart';

abstract class HtmlServiceInterface{
  Future<Response> getHtmlText(HtmlType htmlType);
}