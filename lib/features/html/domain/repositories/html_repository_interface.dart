import 'package:pickles_and_pies/interfaces/repository_interface.dart';
import 'package:pickles_and_pies/util/html_type.dart';

abstract class HtmlRepositoryInterface extends RepositoryInterface {
  Future<dynamic> getHtmlText(HtmlType htmlType);
}