import 'package:get/get_connect/http/src/response/response.dart';
import 'package:pickles_and_pies/common/models/transaction_model.dart';

abstract class LoyaltyServiceInterface {
  Future<TransactionModel?> getLoyaltyTransactionList(String offset);
  Future<Response> pointToWallet({int? point});
}