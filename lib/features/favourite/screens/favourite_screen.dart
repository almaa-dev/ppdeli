import 'package:pickles_and_pies/common/widgets/web_page_title_widget.dart';
import 'package:pickles_and_pies/features/favourite/controllers/favourite_controller.dart';
import 'package:pickles_and_pies/helper/auth_helper.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';
import 'package:pickles_and_pies/common/widgets/custom_app_bar.dart';
import 'package:pickles_and_pies/common/widgets/menu_drawer.dart';
import 'package:pickles_and_pies/common/widgets/not_logged_in_screen.dart';
import 'package:pickles_and_pies/features/favourite/widgets/fav_item_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class FavouriteScreen extends StatefulWidget {
  const FavouriteScreen({super.key});

  @override
  FavouriteScreenState createState() => FavouriteScreenState();
}

class FavouriteScreenState extends State<FavouriteScreen> {
  @override
  void initState() {
    super.initState();
    initCall();
  }

  void initCall(){
    if(AuthHelper.isLoggedIn()) {
      Get.find<FavouriteController>().getFavouriteList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'favourite'.tr, backButton: false),
      endDrawer: const MenuDrawer(),endDrawerEnableOpenDragGesture: false,
      body: AuthHelper.isLoggedIn() ? SafeArea(child: Column(children: [

        WebScreenTitleWidget(title: 'favourite'.tr),

        SizedBox(
          width: Dimensions.webMaxWidth,
          child: Container(
            width: Dimensions.webMaxWidth,
            color: Theme.of(context).cardColor,
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: Text(
              'item'.tr,
              style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
            ),
          ),
        ),

        const Expanded(child: FavItemViewWidget(isStore: false)),

      ])) : NotLoggedInScreen(callBack: (value){
        initCall();
        setState(() {});
      }),
    );
  }
}