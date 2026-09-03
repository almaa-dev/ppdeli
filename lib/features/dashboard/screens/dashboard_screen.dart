import 'dart:async';
import 'dart:io';
import 'package:expandable_bottom_sheet/expandable_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pickles_and_pies/common/widgets/login_suggestion_bottomsheet.dart';
import 'package:pickles_and_pies/common/widgets/ride_cart.dart';
import 'package:pickles_and_pies/features/dashboard/widgets/payment_incomplete_bottomsheet.dart';
import 'package:pickles_and_pies/features/rental_module/common/widgets/taxi_cart_widget.dart';
import 'package:pickles_and_pies/features/dashboard/widgets/store_registration_success_bottom_sheet.dart';
import 'package:pickles_and_pies/features/home/controllers/home_controller.dart';
import 'package:pickles_and_pies/features/location/controllers/location_controller.dart';
import 'package:pickles_and_pies/features/ride_share_module/offer/screens/offer_screen.dart';
import 'package:pickles_and_pies/features/ride_share_module/ride_home/widgets/login_warning_dialog.dart';
import 'package:pickles_and_pies/features/ride_share_module/ride_order/controllers/ride_controller.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/features/order/controllers/order_controller.dart';
import 'package:pickles_and_pies/features/address/screens/address_screen.dart';
import 'package:pickles_and_pies/features/auth/controllers/auth_controller.dart';
import 'package:pickles_and_pies/features/dashboard/widgets/bottom_nav_item_widget.dart';
import 'package:pickles_and_pies/features/parcel/controllers/parcel_controller.dart';
import 'package:pickles_and_pies/features/store/controllers/store_controller.dart';
import 'package:pickles_and_pies/features/rental_module/rental_cart_screen/taxi_cart_screen.dart';
import 'package:pickles_and_pies/features/rental_module/rental_favourite/screens/vehicle_favourite_screen.dart';
import 'package:pickles_and_pies/helper/auth_helper.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/helper/taxi_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/images.dart';
import 'package:pickles_and_pies/common/widgets/cart_widget.dart';
import 'package:pickles_and_pies/common/widgets/custom_dialog.dart';
import 'package:pickles_and_pies/features/checkout/widgets/congratulation_dialogue.dart';
import 'package:pickles_and_pies/features/dashboard/widgets/address_bottom_sheet_widget.dart';
import 'package:pickles_and_pies/features/dashboard/widgets/parcel_bottom_sheet_widget.dart';
import 'package:pickles_and_pies/features/favourite/screens/favourite_screen.dart';
import 'package:pickles_and_pies/features/home/screens/home_screen.dart';
import 'package:pickles_and_pies/features/menu/screens/menu_screen.dart';
import 'package:pickles_and_pies/features/order/screens/order_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// import '../widgets/running_order_view_widget.dart';

class DashboardScreen extends StatefulWidget {
  final int pageIndex;
  final int? rideOfferIndex;
  final bool fromSplash;
  const DashboardScreen({super.key, required this.pageIndex, this.fromSplash = false, this.rideOfferIndex = 0});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  PageController? _pageController;
  int _pageIndex = 0;
  late List<Widget> _screens;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey();
  bool _canExit = GetPlatform.isWeb ? true : false;

  GlobalKey<ExpandableBottomSheetState> key = GlobalKey();


  late bool _isLogin;
  bool active = false;

  @override
  void initState() {
    super.initState();

    _isLogin = AuthHelper.isLoggedIn();

    _showRegistrationSuccessBottomSheet();
    if(!_isLogin && Get.find<SplashController>().showLoginSuggestion() && (GetPlatform.isAndroid || GetPlatform.isIOS)) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        Get.bottomSheet(LoginSuggestionBottomSheet(), isScrollControlled: true).then((v) {
          Get.find<SplashController>().disableLoginSuggestion();
        });
      });
    }

    if(_isLogin){
      if(Get.find<SplashController>().configModel!.loyaltyPointStatus == 1 && Get.find<AuthController>().getEarningPint().isNotEmpty
          && !ResponsiveHelper.isDesktop(Get.context)){
        Future.delayed(const Duration(seconds: 1), () => showAnimatedDialog(Get.context!, const CongratulationDialogue()));
      }
      suggestAddressBottomSheet();
      // Get.find<OrderController>().getRunningOrders(1, fromDashboard: true);
      Get.find<OrderController>().getDashboardOrders();

      Get.find<SplashController>().getPaymentIncompleteSheetStatus();
      if((Get.find<SplashController>().showPaymentIncompleteBottomSheet && !GetPlatform.isWeb) || (GetPlatform.isWeb && !Get.find<SplashController>().getPaymentIncompleteSheetStatus())) {
        Get.find<OrderController>().getPaymentFailedDetails(null).then((paymentModel) {
          if (paymentModel != null) {
            if(ResponsiveHelper.isDesktop(Get.context)) {
              Get.dialog(Center(child: PaymentIncompleteBottomSheet(paymentModel: paymentModel, fromHome: true)));
            } else {
              Get.bottomSheet(PaymentIncompleteBottomSheet(paymentModel: paymentModel, fromHome: true), isScrollControlled: true);
            }
          }
        });
      }
    }

    _pageIndex = widget.pageIndex;

    _pageController = PageController(initialPage: widget.pageIndex);

    _screens = [
      const HomeScreen(),
      const FavouriteScreen(),
      const SizedBox(),
      const OrderScreen(),
      const MenuScreen()
    ];
  }

  void _showRegistrationSuccessBottomSheet() {
    bool canShowBottomSheet = Get.find<HomeController>().getRegistrationSuccessfulSharedPref();
    if(canShowBottomSheet) {
      Future.delayed(const Duration(seconds: 1), () {
        ResponsiveHelper.isDesktop(Get.context) ? Get.dialog(const Dialog(child: StoreRegistrationSuccessBottomSheet())).then((value) {
          Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(false);
          Get.find<HomeController>().saveIsStoreRegistrationSharedPref(false);
          setState(() {});
        }) : showModalBottomSheet(
          context: Get.context!, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (con) => const StoreRegistrationSuccessBottomSheet(),
        ).then((value) {
          Get.find<HomeController>().saveRegistrationSuccessfulSharedPref(false);
          Get.find<HomeController>().saveIsStoreRegistrationSharedPref(false);
          setState(() {});
        });
      });
    }
  }

  Future<void> suggestAddressBottomSheet() async {
    active = await Get.find<LocationController>().checkLocationActive();
    if(widget.fromSplash && Get.find<LocationController>().showLocationSuggestion && active) {
      Future.delayed(const Duration(seconds: 1), () {
        showModalBottomSheet(
          context: Get.context!, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (con) => const AddressBottomSheetWidget(),
        ).then((value) {
          Get.find<LocationController>().showSuggestedLocation(false);
          setState(() {});
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    bool keyboardVisible = MediaQuery.of(context).viewInsets.bottom != 0;
    return GetBuilder<SplashController>(
      builder: (splashController) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (_pageIndex != 0) {
              _setPage(0);
            } else {
              if(!ResponsiveHelper.isDesktop(context) && Get.find<SplashController>().module != null && Get.find<SplashController>().configModel!.module == null && splashController.moduleList != null && splashController.moduleList!.length != 1) {
                // Get.find<SplashController>().setModule(null);
                splashController.removeModule();
                Get.find<StoreController>().resetStoreData();
              }else {
                if(_canExit) {
                  if (GetPlatform.isAndroid) {
                    SystemNavigator.pop();
                  } else if (GetPlatform.isIOS) {
                    exit(0);
                  }
                }else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('back_press_again_to_exit'.tr, style: const TextStyle(color: Colors.white)),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                    margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  ));
                  _canExit = true;
                  Timer(const Duration(seconds: 2), () {
                    _canExit = false;
                  });
                }
              }
            }
          },
          child: GetBuilder<OrderController>(
            builder: (orderController) {
              // تم إلغاء البوتوم شيت الخاص بالطلبات الجارية، لذا تم تعطيل المتغير runningOrder.
              // List<OrderData> runningOrder = orderController.ongoingOrderModel != null ? orderController.ongoingOrderModel!.data! : [];

              // تحديث قائمة الشاشات بناءً على نوع الموديل الحالي
              bool isParcel = splashController.module != null && splashController.configModel!.moduleConfig!.module!.isParcel!;
              bool isTaxiWithCache = ((splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.taxi) || (splashController.cacheModule != null && splashController.cacheModule!.moduleType.toString() == AppConstants.taxi)) && TaxiHelper.haveTaxiModule();
              bool isTaxi = (splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.taxi);
              bool isRide = (splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.ride);
              isParcel = isParcel && !isTaxiWithCache;

              _screens = [
                const HomeScreen(),
                isParcel ? const AddressScreen(fromDashboard: true)
                    : isTaxi ? const VehicleFavouriteScreen()
                    : isRide ? OrderScreen(index: isTaxi ? 'trips' : 'rides')
                    : const FavouriteScreen(),
                const SizedBox(),
                isRide ? OfferScreen(selectedIndex: widget.rideOfferIndex) : OrderScreen(index: isTaxi ? 'trips' : 'orders'),
                const MenuScreen()
              ];

              return SafeArea(
                top: false, bottom: GetPlatform.isAndroid,
                child: Scaffold(
                  key: _scaffoldKey,
                  body: ExpandableBottomSheet(
                    background: Stack(children: [
                      PageView.builder(
                          controller: _pageController,
                          itemCount: _screens.length,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return _screens[index];
                          },
                        ),

                        // تم إفراغ محتوى شريط التنقل السفلي من هنا (نقلناه إلى persistentFooter)
                        // لمنع ظهور أي فراغ أبيض تحت الـ PageView.
                        const SizedBox.shrink(),
                      ]),

                    // تعطيل الحجز الدائم للمحتوى لأن expandableContent أصبح فارغاً تماماً
                    persistentContentHeight: 0,

                    persistentFooter: _buildBottomNavigation(context, size, keyboardVisible: keyboardVisible),

                    // تم تعطيل التبديل والـ callbacks لأن البوتوم شيت تم إلغاؤه
                    enableToggle: false,

                    expandableContent: const SizedBox(),
                  ),
                ),
              );
            }
          ),
        );
      }
    );
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageController!.jumpToPage(pageIndex);
      _pageIndex = pageIndex;
    });
  }

  /// يبني شريط التنقل السفلي + زر الفلوتنج (FAB) ويُستخدم كـ persistentFooter
  /// في ExpandableBottomSheet. تم نقله من داخل الـ background لكي:
  /// 1) يضمن ظهور الشريط السفلي دائماً في أسفل الشاشة
  /// 2) يمنع ظهور أي فراغ أبيض ناتج عن الـ ExpandableBottomSheet
  /// 3) يبقي الـ FAB والصف السفلي خارج منطق حساب ارتفاعات الـ ExpandableContent
  ///
  /// المعامل [keyboardVisible] يستخدم لإخفاء الشريط عند ظهور لوحة المفاتيح
  /// لتوفير مساحة للمستخدم.
  Widget _buildBottomNavigation(BuildContext context, Size size, {bool keyboardVisible = false}) {
    if (ResponsiveHelper.isDesktop(context) || keyboardVisible) {
      return const SizedBox.shrink();
    }
    return Container(
      width: size.width,
      height: GetPlatform.isIOS ? 80 : 65,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Dimensions.radiusLarge)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
      ),
      child: Stack(children: [

        // زر الفلوتنج (FAB) في المنتصف، يطفو فوق شريط التنقل
        Center(
          heightFactor: 0.6,
          child: GetBuilder<SplashController>(
            builder: (splashController) {
              bool isParcel = splashController.module != null && splashController.configModel!.moduleConfig!.module!.isParcel!;
              bool isTaxiWithCache = ((splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.taxi) || (splashController.cacheModule != null && splashController.cacheModule!.moduleType.toString() == AppConstants.taxi)) && TaxiHelper.haveTaxiModule();
              bool isRide = (splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.ride);
              isParcel = isParcel && !isTaxiWithCache;

              // إخفاء الـ FAB في بعض الحالات الخاصة (ديسكتوب أو شاشة اختيار الموقع)
              if (ResponsiveHelper.isDesktop(context)) return const SizedBox();
              if (widget.fromSplash && Get.find<LocationController>().showLocationSuggestion && active) return const SizedBox();

              return Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).cardColor, width: 5),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
                ),
                child: FloatingActionButton(
                  backgroundColor: Theme.of(context).primaryColor,
                  onPressed: () async {
                    if(isParcel) {
                      showModalBottomSheet(
                        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                        builder: (con) => ParcelBottomSheetWidget(parcelCategoryList: Get.find<ParcelController>().parcelCategoryList),
                      );
                    } else if(isRide) {
                      if(AuthHelper.isLoggedIn()) {
                        await Get.find<RideController>().getCurrentRideStatus(fromRefresh: true, showCustomLoader: true);
                      } else {
                        Get.dialog(const LoginWarningDialog());
                      }
                    } else if(isTaxiWithCache) {
                      Get.to(()=> const TaxiCartScreen());
                    } else {
                      Get.toNamed(RouteHelper.getCartRoute());
                    }
                  },
                  elevation: 0,
                  child: isTaxiWithCache
                      ? TaxiCartWidget(color: Theme.of(context).cardColor, size: 22)
                      : isParcel ? Icon(CupertinoIcons.add, size: 34, color: Theme.of(context).cardColor)
                      : isRide ? const RideCart()
                      : CartWidget(color: Theme.of(context).cardColor, size: 22),
                ),
              );
            },
          ),
        ),

        // صف أيقونات التنقل السفلية
        GetBuilder<SplashController>(
          builder: (splashController) {
            bool isParcel = splashController.module != null && splashController.configModel!.moduleConfig!.module!.isParcel!;
            bool isTaxi = (splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.taxi);
            bool isRide = (splashController.module != null && splashController.module!.moduleType.toString() == AppConstants.ride);

            // إخفاء الصف في بعض الحالات الخاصة
            if (ResponsiveHelper.isDesktop(context)) return const SizedBox();
            if (widget.fromSplash && Get.find<LocationController>().showLocationSuggestion && active) return const SizedBox();

            return Center(
              child: SizedBox(
                width: size.width, height: 80,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  BottomNavItemWidget(
                    title: 'home'.tr, selectedIcon: Images.homeSelect,
                    unSelectedIcon: Images.homeUnselect, isSelected: _pageIndex == 0,
                    onTap: () => _setPage(0),
                  ),
                  BottomNavItemWidget(
                    title: isParcel ? 'address'.tr : isTaxi ? 'wishlist'.tr : isRide ? 'my_activity'.tr  : 'favourite'.tr,
                    selectedIcon: isParcel ? Images.addressSelect : isRide ? Images.orderSelect : Images.favouriteSelect,
                    unSelectedIcon: isParcel ? Images.addressUnselect : isRide ? Images.orderUnselect : Images.favouriteUnselect,
                    isSelected: _pageIndex == 1, onTap: () => _setPage(1),
                  ),
                  Container(width: size.width * 0.2),
                  BottomNavItemWidget(
                    title: isTaxi ? 'trips'.tr : isRide ? 'my_offers'.tr  : 'orders'.tr,
                    selectedIcon: isRide ? Images.offerSelect : Images.orderSelect,
                    unSelectedIcon: isRide ? Images.offerUnSelect : Images.orderUnselect,
                    isSelected: _pageIndex == 3, onTap: () => _setPage(3),
                  ),
                  BottomNavItemWidget(
                    title: 'menu'.tr, selectedIcon: Images.menu, unSelectedIcon: Images.menu,
                    isSelected: _pageIndex == 4, onTap: () => _setPage(4),
                  ),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }

  Widget trackView(BuildContext context, {required bool status}) {
    return Container(height: 3, decoration: BoxDecoration(color: status ? Theme.of(context).primaryColor
        : Theme.of(context).disabledColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(Dimensions.radiusDefault)));
  }


}

