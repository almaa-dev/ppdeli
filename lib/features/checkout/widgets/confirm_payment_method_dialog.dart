import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/common/widgets/custom_button.dart';
import 'package:pickles_and_pies/features/checkout/controllers/checkout_controller.dart';
import 'package:pickles_and_pies/features/payment/domain/models/offline_method_model.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';

class ConfirmPaymentMethodDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onChange;
  const ConfirmPaymentMethodDialog({
    super.key,
    required this.onConfirm,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CheckoutController>(builder: (checkoutController) {
      final methodIndex = checkoutController.paymentMethodIndex;
      final paymentInfo = _resolvePaymentInfo(checkoutController, methodIndex);
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        insetPadding: const EdgeInsets.all(30),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: SizedBox(
          width: 450,
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _header(context),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text(
                'confirm_payment_method'.tr,
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeExtraLarge,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(
                'your_selected_payment_method'.tr,
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context).disabledColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              _selectedMethodCard(context, paymentInfo),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Text(
                'confirm_payment_method_message'.tr,
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context).disabledColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              _actions(context),
            ]),
          ),
        ),
      );
    });
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.lock_outline,
        size: 36,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextButton(
          onPressed: () {
            Get.back();
            onChange();
          },
          style: TextButton.styleFrom(
            backgroundColor:
                Theme.of(context).disabledColor.withValues(alpha: 0.2),
            minimumSize: const Size(0, 50),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
          ),
          child: Text(
            'change_payment_method'.tr,
            textAlign: TextAlign.center,
            style: robotoBold.copyWith(
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
          ),
        ),
      ),
      const SizedBox(width: Dimensions.paddingSizeSmall),
      Expanded(
        child: CustomButton(
          buttonText: 'confirm_and_place_order'.tr,
          height: 50,
          radius: Dimensions.radiusSmall,
          fontSize: Dimensions.fontSizeSmall,
          onPressed: () {
            Get.back();
            onConfirm();
          },
        ),
      ),
    ]);
  }

  Widget _selectedMethodCard(BuildContext context, _PaymentDisplayInfo info) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).primaryColor,
              size: 22,
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: Text(
                info.title,
                style: robotoBold.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                ),
              ),
            ),
          ]),
          if (info.subtitle.isNotEmpty) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                info.subtitle,
                style: robotoRegular.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
          ],
          if (info.isLastUsed) ...[
            const SizedBox(height: Dimensions.paddingSizeSmall),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeSmall,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .primaryColor
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(Dimensions.radiusSmall),
                ),
                child: Text(
                  'last_used_payment_method'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a user-friendly title + subtitle for the currently selected
  /// payment method. Uses the actual project labels (not hard-coded names)
  /// whenever possible. Also flags whether the live selection equals the
  /// persisted saved preference, so we can render the optional "Last used"
  /// hint.
  _PaymentDisplayInfo _resolvePaymentInfo(
    CheckoutController controller,
    int methodIndex,
  ) {
    final savedIndex = controller.savedPaymentMethodIndex;
    final isLastUsed = savedIndex == methodIndex && savedIndex != -1;
    switch (methodIndex) {
      case 0:
        return _PaymentDisplayInfo(
          title: 'cash_on_delivery_full'.tr,
          subtitle: '',
          isLastUsed: isLastUsed,
        );
      case 1:
        return _PaymentDisplayInfo(
          title: 'wallet_payment_full'.tr,
          subtitle: '',
          isLastUsed: isLastUsed,
        );
      case 2:
        final splash = Get.find<SplashController>();
        final activeList = splash.configModel?.activePaymentMethodList;
        String title = controller.digitalPaymentName ?? 'digital_payment_full'.tr;
        String subtitle = '';
        if (activeList != null && controller.digitalPaymentName != null) {
          for (final gateway in activeList) {
            if (gateway.getWay == controller.digitalPaymentName) {
              title = gateway.getWayTitle ?? title;
              subtitle = gateway.getWay ?? '';
              break;
            }
          }
        }
        return _PaymentDisplayInfo(
          title: title,
          subtitle: subtitle,
          isLastUsed: isLastUsed,
        );
      case 3:
        String subtitle = '';
        String title = 'offline_payment_full'.tr;
        try {
          final List<OfflineMethodModel>? list = controller.offlineMethodList;
          final int idx = controller.selectedOfflineBankIndex;
          if (list != null && idx >= 0 && idx < list.length) {
            title = list[idx].methodName ?? title;
            subtitle = 'bank'.tr;
          }
        } catch (_) {
          // Defensive: never let a bad offline list crash the dialog.
        }
        return _PaymentDisplayInfo(
          title: title,
          subtitle: subtitle,
          isLastUsed: isLastUsed,
        );
      default:
        return _PaymentDisplayInfo(
          title: 'select_payment_method'.tr,
          subtitle: '',
          isLastUsed: false,
        );
    }
  }
}

class _PaymentDisplayInfo {
  final String title;
  final String subtitle;
  final bool isLastUsed;
  _PaymentDisplayInfo({
    required this.title,
    required this.subtitle,
    required this.isLastUsed,
  });
}
