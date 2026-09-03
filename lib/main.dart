import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:pickles_and_pies/SplashLoadingWidget.dart';
import 'package:pickles_and_pies/features/auth/controllers/auth_controller.dart';
import 'package:pickles_and_pies/features/cart/controllers/cart_controller.dart';
import 'package:pickles_and_pies/features/language/controllers/language_controller.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/common/controllers/theme_controller.dart';
import 'package:pickles_and_pies/features/notification/domain/models/notification_body_model.dart';
import 'package:pickles_and_pies/helper/address_helper.dart';
import 'package:pickles_and_pies/helper/auth_helper.dart';
import 'package:pickles_and_pies/helper/link_converter_helper.dart';
import 'package:pickles_and_pies/helper/notification_helper.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/theme/dark_theme.dart';
import 'package:pickles_and_pies/theme/light_theme.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:pickles_and_pies/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/features/home/widgets/cookies_view.dart';
import 'helper/get_di.dart' as di;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_web_plugins/url_strategy.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    usePathUrlStrategy();
  }
  /*///Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };


  ///Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };*/

  if(GetPlatform.isWeb){
    await Firebase.initializeApp(options: const FirebaseOptions(
        apiKey: "AIzaSyCzzCpX6Qlar5_GuEn6fU9OJZiEFx2OJPA",
        authDomain: "ppdeli-f07a9.firebaseapp.com",
        projectId: "ppdeli-f07a9",
        storageBucket: "ppdeli-f07a9.firebasestorage.app",
        messagingSenderId: "422412778152",
        appId: "1:422412778152:web:622a0d81c8f4752f24e09d"
    ));
  } else if(GetPlatform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyClR9gV_285DgJviVaWvZrgkc2_Bb2wNwQ",
        appId: "1:422412778152:android:bbe20039b88aa6f124e09d",
        messagingSenderId: "422412778152",
        projectId: "ppdeli-f07a9",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  Map<String, Map<String, String>> languages = await di.init();

  NotificationBodyModel? body;
  try {
    if (GetPlatform.isMobile) {
      final RemoteMessage? remoteMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (remoteMessage != null) {
        body = NotificationHelper.convertNotification(remoteMessage.data);
      }
      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    }
  }catch(_) {}

  if (ResponsiveHelper.isWeb()) {
    await FacebookAuth.instance.webAndDesktopInitialize(
      appId: "380903914182154",
      cookie: true,
      xfbml: true,
      version: "v15.0",
    );
  }

  runApp(MyApp(languages: languages, body: body));
}

class MyApp extends StatefulWidget {
  final Map<String, Map<String, String>>? languages;
  final NotificationBodyModel? body;
  const MyApp({super.key, required this.languages, required this.body});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  String? deeplinkRoute;
  String? _initialRoute;

  @override
  void initState() {
    super.initState();

    if(!GetPlatform.isWeb) {
      _initAppLinks();
    }

    _route();
    
    _initialRoute = GetPlatform.isWeb ? RouteHelper.getInitialRoute() : RouteHelper.getSplashRoute(widget.body, deeplinkRoute);

  }

  void _initAppLinks() async {
    _appLinks = AppLinks();

    // Listen for any subsequent incoming links
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        if (kDebugMode) {
          print('=======Received URI: $uri and previous deeplinkRoute: ${Get.find<SplashController>().deeplinkRoute}');
        }
        LinkConverter.convertDeepLink(uri);
      }
    }, onError: (err) {
      if (kDebugMode) {
        print('catch Error in initAppLinksStream: $err');
      }
    });
  }

  void _route() async {
    if(GetPlatform.isWeb) {
       Get.find<SplashController>().initSharedData();
      if(AddressHelper.getUserAddressFromSharedPref() != null && AddressHelper.getUserAddressFromSharedPref()!.zoneIds == null) {
        Get.find<AuthController>().clearSharedAddress();
      }

      if(!AuthHelper.isLoggedIn() && !AuthHelper.isGuestLoggedIn()) {
        await Get.find<AuthController>().guestLogin();
      }

      if((AuthHelper.isLoggedIn() || AuthHelper.isGuestLoggedIn()) && Get.find<SplashController>().cacheModule != null) {
        Get.find<CartController>().getCartDataOnline();
      }

      Get.find<SplashController>().getConfigData(loadLandingData: (GetPlatform.isWeb && AddressHelper.getUserAddressFromSharedPref() == null), fromMainFunction: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Avoid nested GetBuilder rebuilds: each GetBuilder<>() in the ancestor chain
    // would invalidate everything below it on `update()`. Using the *value*
    // accessors directly keeps the rebuild scope tight to the outermost builder.
    final themeController = Get.find<ThemeController>();
    final localizeController = Get.find<LocalizationController>();
    final splashController = Get.find<SplashController>();

    return GetBuilder<ThemeController>(
      id: 'theme_root',
      builder: (_) => GetBuilder<LocalizationController>(
        id: 'locale_root',
        builder: (_) {
          if (GetPlatform.isWeb && splashController.configModel == null) {
            return const SplashLoadingWidget();
          }
          return GetMaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: Get.key,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
            ),
            theme: themeController.darkTheme ? dark() : light(),
            locale: localizeController.locale,
            translations: Messages(languages: widget.languages),
            fallbackLocale: Locale(AppConstants.languages[0].languageCode!, AppConstants.languages[0].countryCode),
            initialRoute: _initialRoute,
            getPages: RouteHelper.routes,
            defaultTransition: GetPlatform.isWeb ? Transition.fadeIn : Transition.topLevel,
            transitionDuration: const Duration(milliseconds: 50),
            builder: (BuildContext context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
                child: Material(
                  child: SafeArea(
                    top: false,
                    bottom: GetPlatform.isAndroid,
                    child: Stack(children: [
                      child ?? const SizedBox.shrink(),
                      // CookiesView is reactive on its own and rebuilds cheaply;
                      // do NOT wrap it in another GetBuilder<SplashController>
                      // because that would re-trigger the entire MaterialApp
                      // builder on every cookie-related update.
                      const _CookiesOverlay(),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Listens to cookie-related SplashController updates and renders the
/// cookies banner without rebuilding the whole MaterialApp tree.
///
/// Uses an isolated `GetBuilder` with a unique id so that cookie updates
/// rebuild only this widget, not the entire MaterialApp tree.
class _CookiesOverlay extends StatelessWidget {
  const _CookiesOverlay();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      id: '_cookies_overlay',
      builder: (splashController) {
        if (splashController.savedCookiesData) return const SizedBox.shrink();
        final cookiesText = splashController.configModel?.cookiesText ?? '';
        if (splashController.getAcceptCookiesStatus(cookiesText)) {
          return const SizedBox.shrink();
        }
        return ResponsiveHelper.isWeb()
            ? const Align(
                alignment: Alignment.bottomCenter,
                child: CookiesView(),
              )
            : const SizedBox.shrink();
      },
    );
  }
}

