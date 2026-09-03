import 'package:get/get.dart';
import 'package:pickles_and_pies/features/online_payment/domain/services/online_payment_service_interface.dart';

class OnlinePaymentController extends GetxController implements GetxService {
  final OnlinePaymentServiceInterface onlinePaymentServiceInterface;

  OnlinePaymentController({required this.onlinePaymentServiceInterface});
}