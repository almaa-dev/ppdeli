// ignore_for_file: prefer_const_constructors_in_immutables, prefer_final_fields

import 'package:pickles_and_pies/common/models/config_model.dart';
import 'package:pickles_and_pies/features/coupon/controllers/coupon_controller.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';
import 'package:pickles_and_pies/helper/auth_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:get/get.dart';

/// Snapshot describing the resolved delivery fee state for the checkout
/// screen. Having an explicit, three-valued status (loading / free / paid)
/// is what prevents the legacy "Free -> $5 -> Free" flicker.
///
/// - [DeliveryFeeStatus.loading]: distance/store not yet available.
/// - [DeliveryFeeStatus.free]:    computed and equal to 0.
/// - [DeliveryFeeStatus.paid]:    computed and greater than 0.
enum DeliveryFeeStatus { loading, free, paid }

class DeliveryFeeSnapshot {
  final double value;
  final DeliveryFeeStatus status;

  const DeliveryFeeSnapshot._(this.value, this.status);

  /// Sentinel used while distance / store data is still loading. UI should
  /// display "calculating" (or hide the value entirely) when this is shown.
  static const DeliveryFeeSnapshot loading = DeliveryFeeSnapshot._(
    -1.0,
    DeliveryFeeStatus.loading,
  );

  const DeliveryFeeSnapshot.free(double amount)
      : this._(amount, DeliveryFeeStatus.free);

  const DeliveryFeeSnapshot.paid(double amount)
      : this._(amount, DeliveryFeeStatus.paid);

  bool get isLoading => status == DeliveryFeeStatus.loading;
  bool get isFree => status == DeliveryFeeStatus.free;
  bool get isPaid => status == DeliveryFeeStatus.paid;
}

/// Single source of truth for the delivery-fee business rule.
///
/// Why this exists
/// ---------------
/// The original `_calculateDeliveryCharge` in `checkout_screen.dart` mixed
/// four unrelated free-delivery sources:
///
///   1. `store.freeDelivery`
///   2. `adminFreeDelivery.type == free_delivery_to_all_store`
///   3. `adminFreeDelivery.type == free_delivery_by_order_amount` and
///      `orderAmount >= freeDeliveryOver`
///   4. `couponController.freeDelivery` (when a "free_delivery" coupon is
///      applied)
///   5. guest-without-address fallback
///
/// On top of that, `getDistanceInKM()` in `CheckoutController` re-runs the
/// build twice (distance + extraCharge) and each `setOrderType()` call in
/// `DeliveryOptionButtonWidget.initState()` triggers another build. Because
/// the value `0` was overloaded to mean BOTH "not calculated yet" AND
/// "delivered for free", the UI flickered: Free -> $5 -> Free.
///
/// This resolver separates the three states, applies the
/// `Pickles & Pies` business rule (below min order => flat fee) and is the
/// only place allowed to compute the final delivery fee.
class DeliveryFeeResolver {
  /// Optional lookup for [ConfigModel]. When null, the resolver falls
  /// back to `Get.find<SplashController>().configModel`. The lookup is
  /// exposed so unit tests can inject a config without registering a
  /// full `SplashController` in `Get`.
  final ConfigModel? Function()? _configModelLookup;

  /// Optional lookup for "is the current user a guest?". When null, the
  /// resolver falls back to [AuthHelper.isGuestLoggedIn]. Exposed for the
  /// same reason as [_configModelLookup].
  final bool Function()? _isGuestLoggedInLookup;

  DeliveryFeeResolver({
    ConfigModel? Function()? configModelLookup,
    bool Function()? isGuestLoggedInLookup,
  })  : _configModelLookup = configModelLookup,
        _isGuestLoggedInLookup = isGuestLoggedInLookup;

  /// Resolve the final delivery fee for the current checkout state.
  ///
  /// Inputs are passed in explicitly (no hidden lookups) so the caller can
  /// audit exactly which fields participate in the decision.
  ///
  /// Parameters:
  /// - [orderType]         : "delivery" or "take_away".
  /// - [orderAmount]       : the pre-delivery amount the rule is compared
  ///                         against (subTotal - discount - couponDiscount
  ///                         - referralDiscount + addOns + variations).
  /// - [store]             : the active store (may be null while loading).
  /// - [distanceKm]        : resolved customer->store distance. `null` or
  ///                         `-1.0` means "not yet calculated".
  /// - [originalCharge]    : the value coming out of the existing per-km
  ///                         / minimum / maximum / extra / surge pipeline
  ///                         in `_calculateOriginalDeliveryCharge`. Pass
  ///                         `-1.0` when the value is not yet computable.
  /// - [guestAddress]      : when the user is a guest, pass the
  ///                         checkoutController.guestAddress. `null` means
  ///                         "no address chosen yet".
  /// - [couponController]  : optional; when a `free_delivery` coupon is
  ///                         active this is required to detect it.
  DeliveryFeeSnapshot resolve({
    required String? orderType,
    required double orderAmount,
    required Store? store,
    required double? distanceKm,
    required double originalCharge,
    Object? guestAddress,
    CouponController? couponController,
  }) {
    // Pickup is always free and never enters the rule.
    if (orderType == 'take_away') {
      return DeliveryFeeSnapshot.free(0.0);
    }

    // Store / distance still loading -> keep the UI in "calculating" mode.
    if (store == null ||
        distanceKm == null ||
        distanceKm == -1.0 ||
        originalCharge == -1.0) {
      return DeliveryFeeSnapshot.loading;
    }

    final ConfigModel? configModel;
    if (_configModelLookup != null) {
      // In the test / unit-test path we rely entirely on the injected
      // lookup. We MUST NOT touch `Get.find<SplashController>()` in that
      // mode or the runner will throw.
      configModel = _configModelLookup();
    } else {
      configModel = Get.find<SplashController>().configModel;
    }
    final AdminFreeDelivery? admin = configModel?.adminFreeDelivery;

    // 1. The store itself is configured to deliver for free. This wins over
    //    every other rule, including the below-minimum charge.
    if (store.freeDelivery == true) {
      return DeliveryFeeSnapshot.free(0.0);
    }

    // 2. Admin-wide "free delivery to all stores". Same precedence as the
    //    per-store freeDelivery toggle.
    if (admin?.status == true &&
        admin?.type == 'free_delivery_to_all_store') {
      return DeliveryFeeSnapshot.free(0.0);
    }

    // 3. Admin "free delivery above a certain order amount". Only applies
    //    when the *current* order amount qualifies; otherwise we keep the
    //    charge.
    if (admin?.status == true &&
        admin?.type == 'free_delivery_by_order_amount' &&
        admin?.freeDeliveryOver != null &&
        orderAmount >= admin!.freeDeliveryOver!) {
      return DeliveryFeeSnapshot.free(0.0);
    }

    // 4. Guest fallback: a guest with no address must not be charged.
    //
    //    The caller passes [guestAddress] explicitly so this resolver stays
    //    independent of CheckoutController registration semantics (which
    //    are wrapped in try/catch in the legacy code for the same reason).
    //    In the checkout_screen.dart caller we forward
    //    `checkoutController.guestAddress` here.
    final bool isGuest = _isGuestLoggedInLookup != null
        ? _isGuestLoggedInLookup()
        : AuthHelper.isGuestLoggedIn();
    if (isGuest && guestAddress == null) {
      return DeliveryFeeSnapshot.free(0.0);
    }

    // 5. The Pickles & Pies "below-minimum flat fee" rule.
    //
    //    IF orderAmount < deliveryFeeMinOrderAmount
    //    THEN delivery fee = deliveryFeeBelowMinimum
    //
    //    This is evaluated AFTER all admin/coupon/guest overrides so the
    //    flicker can never happen: the moment a store / distance is known,
    //    we land on exactly one branch.
    if (orderAmount < AppConstants.deliveryFeeMinOrderAmount) {
      return DeliveryFeeSnapshot.paid(
        AppConstants.deliveryFeeBelowMinimum,
      );
    }

    // 6. Order reached the minimum -> apply the legacy per-km / min / max
    //    pipeline. This is also the spot where a "free_delivery" coupon is
    //    allowed to drop the value to zero (the coupon only fires once the
    //    order amount is large enough).
    double charge = originalCharge;

    // couponController.freeDelivery is set when a free_delivery coupon is
    // applied. The legacy code only honors this after the order reaches the
    // coupon's own minimum, so we mirror that behavior here.
    final hasFreeDeliveryCoupon = couponController?.freeDelivery ?? false;
    if (hasFreeDeliveryCoupon) {
      charge = 0.0;
    }

    if (charge <= 0) {
      return DeliveryFeeSnapshot.free(0.0);
    }
    return DeliveryFeeSnapshot.paid(charge);
  }
}