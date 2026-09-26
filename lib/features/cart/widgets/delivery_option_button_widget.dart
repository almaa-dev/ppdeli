import 'package:pickles_and_pies/common/widgets/custom_tool_tip_widget.dart';
import 'package:pickles_and_pies/features/checkout/controllers/checkout_controller.dart';
import 'package:pickles_and_pies/helper/price_converter.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeliveryOptionButtonWidget extends StatefulWidget {
  final String value;
  final String title;
  final double? charge;
  final bool? isFree;
  final bool fromWeb;
  final double total;
  final String deliveryChargeForView;
  final double badWeatherCharge;
  final double extraChargeForToolTip;

  /// When `false`, the widget renders in disabled visual state and ignores
  /// taps. Used by the Delivery Service Hours feature to disable Home
  /// Delivery when the store is outside its service window. Defaults to
  /// `true` (no behavioral change vs. legacy code).
  final bool enabled;

  const DeliveryOptionButtonWidget({
    super.key,
    required this.value,
    required this.title,
    required this.charge,
    required this.isFree,
    this.fromWeb = false,
    required this.total,
    required this.deliveryChargeForView,
    required this.badWeatherCharge,
    required this.extraChargeForToolTip,
    this.enabled = true,
  });

  @override
  State<DeliveryOptionButtonWidget> createState() =>
      _DeliveryOptionButtonWidgetState();
}

class _DeliveryOptionButtonWidgetState extends State<DeliveryOptionButtonWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CheckoutController>(builder: (checkoutController) {
      bool select = checkoutController.orderType == widget.value;
      final bool isEnabled = widget.enabled;
      final bool isFreeDelivery = widget.isFree ?? false;

      return Opacity(
        opacity: isEnabled ? 1.0 : 0.45,
        child: InkWell(
          onTap: isEnabled
              ? () {
                  checkoutController.setOrderType(widget.value);
                  checkoutController.setInstruction(-1);

                  if (checkoutController.orderType == 'take_away') {
                    if (checkoutController.isPartialPay) {
                      double tips = 0;
                      try {
                        tips = double.parse(
                            checkoutController.tipController.text);
                      } catch (_) {}
                      checkoutController.checkBalanceStatus(
                          widget.total, widget.charge! + tips);
                    }
                  } else {
                    if (checkoutController.isPartialPay) {
                      checkoutController.changePartialPayment();
                    } else {
                      checkoutController.setPaymentMethod(-1);
                    }
                  }
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: select
                  ? widget.fromWeb
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Theme.of(context).cardColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              border: Border.all(
                  color: select ? Theme.of(context).primaryColor : Colors.transparent),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeSmall,
                vertical: Dimensions.paddingSizeExtraSmall),
            child: Row(
              children: [
                Builder(builder: (innerContext) {
                return RadioGroup<String>(
                  groupValue: checkoutController.orderType,
                  onChanged: (String? value) =>
                      checkoutController.setOrderType(value),
                  child: Radio<String>(
                    value: widget.value,
                    enabled: isEnabled,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: Theme.of(context).primaryColor,
                    visualDensity:
                        const VisualDensity(horizontal: -3, vertical: -3),
                  ),
                );
              }),
                const SizedBox(width: Dimensions.paddingSizeSmall),

                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: robotoMedium.copyWith(
                              color: select
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color)),
                      Row(children: [
                        Text(
                          (widget.value == 'delivery' && !isFreeDelivery)
                              ? '${'charge'.tr}: +${widget.deliveryChargeForView}'
                              : 'free'.tr,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .color,
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                        widget.value == 'delivery' &&
                                isFreeDelivery == false &&
                                widget.extraChargeForToolTip > 0 &&
                                widget.deliveryChargeForView != '0' &&
                                widget.deliveryChargeForView !=
                                    'calculating'.tr &&
                                widget.deliveryChargeForView.isNotEmpty
                            ? CustomToolTip(
                                message:
                                    '${'this_charge_include_extra_vehicle_charge'.tr} ${PriceConverter.convertPrice(widget.extraChargeForToolTip)}',
                                preferredDirection: AxisDirection.right,
                                child: const Icon(Icons.info,
                                    color: Colors.blue, size: 14),
                              )
                            : const SizedBox(),
                      ]),
                    ]),
                const SizedBox(width: Dimensions.paddingSizeSmall),
              ],
            ),
          ),
        ),
      );
    });
  }
}
