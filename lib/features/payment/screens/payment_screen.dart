import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/features/order/controllers/order_controller.dart';
import 'package:pickles_and_pies/features/order/domain/models/order_model.dart';
import 'package:pickles_and_pies/features/location/domain/models/zone_response_model.dart';
import 'package:pickles_and_pies/helper/address_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/common/widgets/custom_app_bar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pickles_and_pies/features/checkout/widgets/payment_failed_dialog.dart';
import 'package:pickles_and_pies/features/wallet/widgets/fund_payment_dialog_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel orderModel;
  final bool isCashOnDelivery;
  final String? addFundUrl;
  final String paymentMethod;
  final String guestId;
  final String contactNumber;
  final String? subscriptionUrl;
  final int? storeId;
  final bool createAccount;
  final int? createUserId;
  const PaymentScreen({super.key, required this.orderModel, required this.isCashOnDelivery, this.addFundUrl, required this.paymentMethod,
    required this.guestId, required this.contactNumber, this.storeId, this.subscriptionUrl, this.createAccount = false, this.createUserId});

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  late String selectedUrl;
  double value = 0.0;
  // Loading spinner stays mutable so the parent can flip it back to false
  // when navigation completes (or when the user back-presses).
  // ignore: prefer_final_fields
  bool _isLoading = true;
  PullToRefreshController? pullToRefreshController;
  late MyInAppBrowser browser;
  double? _maximumCodOrderAmount;
  // Cached controller reference; we no longer hit Get.find inside every
  // WebView callback.
  late OrderController _orderController;

  @override
  void initState() {
    super.initState();
    _orderController = Get.find<OrderController>();

    if(widget.addFundUrl == '' && widget.addFundUrl!.isEmpty && widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty){
      selectedUrl = '${AppConstants.baseUrl}/payment-mobile?customer_id=${widget.orderModel.userId == 0 ? widget.guestId : widget.orderModel.userId}&order_id=${widget.orderModel.id}&payment_method=${widget.paymentMethod}';
    } else if(widget.subscriptionUrl != '' && widget.subscriptionUrl!.isNotEmpty){
      selectedUrl = widget.subscriptionUrl!;
    } else{
      selectedUrl = widget.addFundUrl!;
    }
    if (kDebugMode) {
      // ignore: avoid_print, prefer_interpolation_to_compose_strings
      print('[Payment] init url host=' + (Uri.tryParse(selectedUrl)?.host ?? ''));
    }
    // Reset the per-flow guard so a fresh payment session does not
    // inherit an already-handled state from a previous one.
    _orderController.resetPaymentRedirectGuard();
    _initData();
  }

  void _initData() async {

    if(widget.addFundUrl == '' && widget.addFundUrl!.isEmpty && widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty){
      for(ZoneData zData in AddressHelper.getUserAddressFromSharedPref()!.zoneData!) {
        for(Modules m in zData.modules!) {
          if(m.id == Get.find<SplashController>().module?.id) {
            _maximumCodOrderAmount = m.pivot!.maximumCodOrderAmount;
            break;
          }
        }
      }
    }

    browser = MyInAppBrowser(
      orderID: widget.orderModel.id.toString(), orderType: widget.orderModel.orderType,
      orderAmount: widget.orderModel.orderAmount, maxCodOrderAmount: _maximumCodOrderAmount,
      isCashOnDelivery: widget.isCashOnDelivery, addFundUrl: widget.addFundUrl,
      contactNumber: widget.contactNumber, storeId: widget.storeId,
      subscriptionUrl: widget.subscriptionUrl, createAccount: widget.createAccount,
      guestId: widget.guestId,
    );

    if(GetPlatform.isAndroid){
      await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);

      bool swAvailable = await WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE);
      bool swInterceptAvailable = await WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_SHOULD_INTERCEPT_REQUEST);

      if (swAvailable && swInterceptAvailable) {
        ServiceWorkerController serviceWorkerController = ServiceWorkerController.instance();
        await serviceWorkerController.setServiceWorkerClient(ServiceWorkerClient(
          shouldInterceptRequest: (request) async {
            if (kDebugMode) {
              print(request);
            }
            return null;
          },
        ));
      }
    }

    await browser.openUrlRequest(
      urlRequest: URLRequest(url: WebUri(selectedUrl)),
      settings: InAppBrowserClassSettings(
        webViewSettings: InAppWebViewSettings(useShouldOverrideUrlLoading: true, useOnLoadResource: true),
        browserSettings: InAppBrowserSettings(hideUrlBar: true, hideToolbarTop: GetPlatform.isAndroid),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _exitApp().then((value) => value!);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: CustomAppBar(title: 'payment'.tr, onBackPressed: () => _exitApp()),
        body: Center(
          child: SizedBox(
            width: Dimensions.webMaxWidth,
            child: Stack(
              children: [
                _isLoading ? Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
                ) : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _exitApp() async {
    if((widget.addFundUrl == null || widget.addFundUrl!.isEmpty) && (widget.subscriptionUrl == '' && widget.subscriptionUrl!.isEmpty)){
      return Get.dialog(PaymentFailedDialog(
        orderID: widget.orderModel.id.toString(), orderAmount: widget.orderModel.orderAmount,
        maxCodOrderAmount: _maximumCodOrderAmount, orderType: widget.orderModel.orderType,
        isCashOnDelivery: widget.isCashOnDelivery, guestId: widget.createAccount ? widget.createUserId.toString() : widget.guestId,
      ));
    } else{
      return Get.dialog(FundPaymentDialogWidget(isSubscription: widget.subscriptionUrl != null && widget.subscriptionUrl!.isNotEmpty));
    }
  }

}

class MyInAppBrowser extends InAppBrowser {
  final String orderID;
  final String? orderType;
  final double? orderAmount;
  final double? maxCodOrderAmount;
  final bool isCashOnDelivery;
  final String? addFundUrl;
  final String? subscriptionUrl;
  final String? contactNumber;
  final int? storeId;
  final bool createAccount;
  final String guestId;

  MyInAppBrowser({
    super.windowId, super.initialUserScripts,
    required this.orderID, required this.orderType, required this.orderAmount,
    required this.maxCodOrderAmount, required this.isCashOnDelivery,
    this.addFundUrl, this.subscriptionUrl, this.contactNumber, this.storeId,
    required this.createAccount, required this.guestId});

  // Mirror of the per-flow guard from OrderService. We flip this inside
  // onClose so subsequent stale WebView events (3DS rebroadcasts,
  // onLoadStop after close) become no-ops.
  // ignore: prefer_final_fields
  bool _canRedirect = true;
  bool _closedCalled = false;

  // Cached controller reference. The browser lives outside the State
  // cycle, so we cannot rely on `mounted` from here.
  OrderController? _controller;

  @override
  Future onBrowserCreated() async {
    // Cache the controller reference once. After this callback the
    // `_controller` field may be reset to null by `onExit` (see below)
    // so we must not access it after that.
    _controller = Get.find<OrderController>();
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Payment] browser created');
    }
  }

  @override
  Future onLoadStart(url) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Payment] onLoadStart');
    }
    // Delegate classification + guards to paymentRedirect in
    // OrderService. Nothing else is done in onLoadStart to avoid
    // redundant callbacks (Stripe 3DS and other intermediate
    // navigations fire onLoadStart multiple times).
    _dispatch(url);
  }

  @override
  Future onLoadStop(url) async {
    pullToRefreshController?.endRefreshing();
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Payment] onLoadStop');
    }
    _dispatch(url);
  }

  // @override
  // Future<ServerTrustAuthResponse?>? onReceivedServerTrustAuthRequest(URLAuthenticationChallenge challenge) async {
  //   if (kDebugMode) {
  //     print("\n\n onReceivedServerTrustAuthRequest: ${challenge.toString()}\n\n");
  //   }
  //   return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
  // }
  //
  // @override
  // Future<ShouldAllowDeprecatedTLSAction?>? shouldAllowDeprecatedTLS(URLAuthenticationChallenge challenge) async {
  //   if (kDebugMode) {
  //     print("\n\n shouldAllowDeprecatedTLS: ${challenge.protectionSpace.host}\n\n");
  //   }
  //   return ShouldAllowDeprecatedTLSAction.ALLOW;
  // }

  @override
  void onLoadError(url, code, message) {
    pullToRefreshController?.endRefreshing();
    if (kDebugMode) {
      // ignore: avoid_print, prefer_interpolation_to_compose_strings
      print('[Payment] onLoadError code=' + code.toString());
    }
  }

  @override
  void onProgressChanged(progress) {
    if (progress == 100) {
      pullToRefreshController?.endRefreshing();
    }
  }

  @override
  void onExit() {
    // Only mark the placeholder in the parent screen if it is still
    // mounted. The parent State of PaymentScreen may have already been
    // disposed by a navigation resulting from the callback.
    _closedCalled = true;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Payment] browser closed');
    }
  }

  @override
  Future onLoadResource(resource) async {
    // Intentionally no-op. We do not log per-resource navigations because
    // they fire hundreds of times per Stripe checkout and would dominate
    // the debug log.
  }

  @override
  void onConsoleMessage(consoleMessage) {
    // Intentionally no-op. Console messages from the WebView can leak
    // sensitive payment data; we must not log them.
  }

  @override
  Future<NavigationActionPolicy?>? shouldOverrideUrlLoading(navigationAction) async {
    final uri = navigationAction.request.url;
    if (uri == null) {
      return NavigationActionPolicy.ALLOW;
    }
    // Only allow a subset of mobile-relevant schemes inside the WebView;
    // other schemes (intent://, custom://, etc.) are external and must
    // be handed outside the app via url_launcher.
    if (!const ['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about'].contains(uri.scheme)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  // Forward to the cached OrderController with a safe wrapper. A null
  // controller (or a disposed controller) must not crash the browser.
  void _dispatch(dynamic url) async {
    if (_closedCalled) return;
    if (!_canRedirect) return;
    if (_controller == null) return;
    try {
      _controller!.paymentRedirect(
        url: url.toString(),
        canRedirect: _canRedirect,
        // onClose is invoked exactly once, only when a payment outcome
        // has been classified and dispatched. We flip our local flag
        // inside it so any late WebView events become no-ops.
        onClose: () {
          _canRedirect = false;
          close();
        },
        addFundUrl: addFundUrl,
        orderID: orderID,
        contactNumber: contactNumber,
        storeId: storeId,
        subscriptionUrl: subscriptionUrl,
        createAccount: createAccount,
        guestId: guestId,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Payment] paymentRedirect threw: $e');
      }
    }
  }
}