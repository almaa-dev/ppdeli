import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/common/widgets/card_design/store_card.dart';
import 'package:pickles_and_pies/common/widgets/title_widget.dart';
import 'package:pickles_and_pies/features/home/widgets/web/web_new_on_view_widget.dart';
import 'package:pickles_and_pies/features/store/controllers/store_controller.dart';
import 'package:pickles_and_pies/features/store/domain/models/store_model.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/images.dart';
class TopOffersNearMe extends StatelessWidget {
  const TopOffersNearMe({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(builder: (storeController) {
      List<Store>? storeList = storeController.topOfferStoreList;

      return storeList != null ? storeList.isNotEmpty ? Container(
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Column(children: [

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: TitleWidget(
              title: 'top_offers_near_me'.tr,
              image: Images.fireIcon,
              onTap: () => Get.toNamed(RouteHelper.getAllStoreRoute('topOffer')),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),

          SizedBox(
            height: 140,
            child: ListView.builder(
              controller: ScrollController(),
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: Dimensions.paddingSizeSmall),
              itemCount: storeList.length,
              itemBuilder: (context, index){
                return Padding(
                  padding: const EdgeInsets.only(right: Dimensions.paddingSizeDefault, bottom: Dimensions.paddingSizeSmall, top: Dimensions.paddingSizeSmall),
                  child: StoreCard(store: storeList[index], isTopOffers: true),
                );
              },
            ),
          ),
        ]),
      ) : const SizedBox.shrink() : const WebNewOnShimmerView();
    });
  }
}
