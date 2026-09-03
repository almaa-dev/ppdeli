import 'package:get/get_connect/http/src/response/response.dart';
import 'package:pickles_and_pies/interfaces/repository_interface.dart';

abstract class LoyaltyRepositoryInterface extends RepositoryInterface {
  Future<Response> pointToWallet({int? point});
}