import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pickles_and_pies/common/models/ongoing_order_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/payment_model.dart';
import 'package:pickles_and_pies/features/home/controllers/home_controller.dart';
import 'package:pickles_and_pies/features/order/domain/models/order_cancellation_body.dart';
import 'package:pickles_and_pies/features/order/domain/models/order_details_model.dart';
import 'package:pickles_and_pies/features/order/domain/models/order_model.dart';
import 'package:pickles_and_pies/features/order/domain/repositories/order_repository_interface.dart';
import 'package:pickles_and_pies/features/order/domain/services/order_service_interface.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:pickles_and_pies/common/widgets/custom_snackbar.dart';

class OrderService implements OrderServiceInterface {
  final OrderRepositoryInterface orderRepositoryInterface;
  OrderService({required this.orderRepositoryInterface});

  @override
  Future<PaginatedOrderModel?> getRunningOrderList(int offset, bool fromDashboard) async {
    return await orderRepositoryInterface.getList(isRunningOrder: true, offset: offset, fromDashboard: fromDashboard);
  }

  @override
  Future<PaginatedOrderModel?> getHistoryOrderList(int offset) async {
    return await orderRepositoryInterface.getList(isHistoryOrder: true, offset: offset);
  }

  @override
  Future<List<String?>?> getSupportReasonsList() async {
    return await orderRepositoryInterface.getList(isSupportReasons: true);
  }

  @override
  Future<List<OrderDetailsModel>?> getOrderDetails(String orderID, String? guestId) async {
    return await orderRepositoryInterface.get(orderID, guestId: guestId);
  }

  @override
  Future<List<CancellationData>?> getCancelReasons() async {
    return await orderRepositoryInterface.getList(isCancelReasons: true);
  }

  @override
  Future<PaymentModel?> getPaymentFailedDetails(String? orderID) async {
    return await orderRepositoryInterface.getPaymentFailedDetails(orderID);
  }

  @override
  Future<OngoingOrderModel?> getDashboardOrders() async {
    return await orderRepositoryInterface.getDashboardOrders();
  }

  @override
  Future<List<String?>?> getRefundReasons() async {
    return await orderRepositoryInterface.getList(isRefundReasons: true);
  }

  @override
  Future<void> submitRefundRequest(int selectedReasonIndex, List<String?>? refundReasons, String note, String? orderId, XFile? refundImage) async {
    if(selectedReasonIndex == -1) {
      showCustomSnackBar('please_select_reason'.tr);
    } else {
      Map<String, String> body = {};
      body.addAll(<String, String>{
        'customer_reason': refundReasons![selectedReasonIndex]!,
        'order_id': orderId!,
        'customer_note': note,
      });
      Response response = await orderRepositoryInterface.submitRefundRequest(body, refundImage);
      if (response.statusCode == 200) {
        showCustomSnackBar(response.body['message'], isError: false);
        Get.offAllNamed(RouteHelper.getInitialRoute());
      }
    }
  }

  @override
  Future<Response> trackOrder(String? orderID, String? guestId, {String? contactNumber}) async {
    return await orderRepositoryInterface.trackOrder(orderID, guestId, contactNumber: contactNumber);
  }

  @override
  Future<bool> cancelOrder({required String orderID, String? reason, String? guestId, required bool isParcel, List<String>? reasons, String? comment}) async {
    return await orderRepositoryInterface.cancelOrder(orderID: orderID, reason: reason, guestId: guestId, isParcel: isParcel, reasons: reasons, comment: comment);
  }

  @override
  Future<bool> submitParcelReturn({required int orderId, required String orderStatus, required int returnOtp}) async {
    return await orderRepositoryInterface.submitParcelReturn(orderId: orderId, orderStatus: orderStatus, returnOtp: returnOtp);
  }

  @override
  OrderModel? prepareOrderModel(PaginatedOrderModel? runningOrderModel, int? orderID) {
    OrderModel? orderModel;
    if(runningOrderModel != null) {
      for(OrderModel order in runningOrderModel.orders!) {
        if(order.id == orderID) {
          orderModel = order;
          break;
        }
      }
    }
    return orderModel;
  }

  @override
  Future<bool> switchToCOD(String? orderID, {String? guestId}) async {
    bool isSuccess = false;
    Response response = await orderRepositoryInterface.switchToCOD(orderID,guestId: guestId);
    if (response.statusCode == 200) {
      isSuccess = true;
      // await Get.offAllNamed(RouteHelper.getInitialRoute());
      showCustomSnackBar(response.body['message'], isError: false);
    }
    return isSuccess;
  }

  @override
  Future<bool> switchToWalletPayment(String? orderID) async {
    bool isSuccess = false;
    Response response = await orderRepositoryInterface.switchToWalletPayment(orderID);
    if (response.statusCode == 200) {
      isSuccess = true;
      // await Get.offAllNamed(RouteHelper.getInitialRoute());
      showCustomSnackBar(response.body['message'], isError: false);
    }
    return isSuccess;
  }

  // --------------------------------------------------------------------
  // paymentRedirect -- hardened.
  //
  // Called by `PaymentScreen` and `PaymentWebViewScreen` on every WebView
  // navigation event. We:
  //   1. Honour the screen-level `canRedirect` flag - once a screen has
  //       signalled "we're done", further callbacks are no-ops.
  //   2. Classify the URL with `classifyPaymentUrl` (strict scheme/host/
 //      path matching) and short-circuit when it isn't a payment callback.
  //   3. De-duplicate via the per-flow guard so the same landing URL
  //      processed via onLoadStart + onLoadStop (or via multiple Stripe
 //      redirects) results in a single navigation.
  //   4. Wrap onClose() so a missing browser instance cannot crash us.
  // --------------------------------------------------------------------
  @override
  void paymentRedirect({required String url, required bool canRedirect, required String? contactNumber,
    required Function onClose, required final String? addFundUrl, required final String? subscriptionUrl,
    required final String orderID, int? storeId, required bool createAccount, required String guestId}) {

    if (!canRedirect) {
      return;
    }

    final outcome = classifyPaymentUrl(url);
    if (outcome == null) {
      return;
    }

    if (_paymentHandled) {
      if (kDebugMode) {
        debugPrint('[paymentRedirect] Duplicate callback ignored. orderID=$orderID url=$url alreadyHandled=$_handledOutcome');
      }
      return;
    }
    _paymentHandled = true;
    _handledOutcome = outcome;

    final isSuccess = outcome == 'success';
    final isFailed = outcome == 'fail';
    final isCancel = outcome == 'cancel';

    final forOrder = (addFundUrl == null || addFundUrl.isEmpty) && (subscriptionUrl == null || subscriptionUrl.isEmpty);
    final forSubscription = (subscriptionUrl != null && subscriptionUrl.isNotEmpty) && (addFundUrl == null || addFundUrl.isEmpty);

    try {
      onClose();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[paymentRedirect] onClose() threw: %e');
      }
    }

    if (forOrder) {
      if (isSuccess) {
        Get.offNamed(RouteHelper.getOrderSuccessRoute(orderID, contactNumber, createAccount: createAccount, guestId: guestId));
      } else if (isFailed || isCancel) {
        Get.offNamed(RouteHelper.getDigitalPaymentFailedScreen(orderID, createAccount: createAccount));
      }
    } else {
      if (Get.currentRoute.contains(RouteHelper.payment)) {
        Get.back();
      }
      if (forSubscription) {
        if (isSuccess) {
          Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(true);
            Get.find<HomeController>().saveIsStoreRegistrationSharedPref(true);
        }
        Get.offAllNamed(RouteHelper.getSubscriptionSuccessRoute(
          status: _outcomeLabel(outcome),
          fromSubscription: true,
          storeId: storeId,
        ));
      } else {
        Get.toNamed(RouteHelper.getWalletRoute(
          fundStatus: _outcomeLabel(outcome),
          token: UniqueKey().toString(),
        ));
      }
    }
  }

  // --------------------------------------------------------------------
  // URL Classification + state machine helpers (hardened).
  // --------------------------------------------------------------------

  /// Per-flow guard. The same URL can be delivered to us several times
  /// (onLoadStart, onLoadStop, JS-driven Stripe redirects).Without this
  /// guard the app would try to navigate to OrderSuccess multiple times.
  bool _paymentHandled = false;
  String? _handledOutcome;

  /// Reset the per-flow guard. Called by the PaymentScreen on initState so
  /// a re-entered payment session does not inherit a stale "already
  /// handled" state from a previous one.
  void resetPaymentRedirectGuard() {
    _paymentHandled = false;
    _handledOutcome = null;
  }

  /// Strict payment-callback classifier. Returns 'success' | 'fail' |
  /// 'cancel' when the URL is a trusted Laravel landing page, null
  /// otherwise. Exposed publicly so it can be unit-tested.
  String? classifyPaymentUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final parsed = Uri.tryParse(url);
    if (parsed == null) return null;
    if (parsed.scheme.toLowerCase() != 'https') return null;
    final host = parsed.host.toLowerCase();
    if (!_isTrustedHost(host)) return null;
    final outcome = _kPaymentPathToOutcome[parsed.path];
    if (outcome == null) return null;
    return outcome;
  }

  /// Map of exact payment landing paths -> outcome label. Used by
  /// `classifyPaymentUrl` and intentionally NOT matched with `startsWith`,
  /// so `/payment-success-malicious` is rejected.
  static const Map<String, String> _kPaymentPathToOutcome = {
    '/payment-success': 'success',
    '/payment-fail': 'fail',
    '/payment-cancel': 'cancel',
    '/subscription-success': 'success',
    '/subscription-fail': 'fail',
    '/subscription-cancel': 'cancel',
  };

  bool _isTrustedHost(String host) {
    if (host.isEmpty) return false;
    final base = Uri.tryParse(AppConstants.baseUrl);
    if (base == null) return false;
    final canonicalHost = base.host.toLowerCase();
    if (host == canonicalHost) return true;
    // Allow the `www.` variant of the canonical bare host only. We never
    // accept arbitrary subdomains; that would re-introduce the
    // `evil.ppdeli.com` bypass.
    if (canonicalHost == 'ppdeli.com' && host == 'www.ppdeli.com') {
      return true;
    }
    return false;
  }

  String _outcomeLabel(String outcome) {
    switch (outcome) {
      case 'success':
        return 'success';
      case 'fail':
        return 'fail';
      case 'cancel':
        return 'cancel';
      default:
        return 'fail';
    }
  }
}

