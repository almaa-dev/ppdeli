import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:pickles_and_pies/common/widgets/card_design/item_card.dart';
import 'package:pickles_and_pies/features/category_products/controllers/category_products_controller.dart';
import 'package:pickles_and_pies/features/splash/controllers/splash_controller.dart';
import 'package:pickles_and_pies/features/item/domain/models/item_model.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';
import 'package:pickles_and_pies/common/widgets/title_widget.dart';

/// AllProductsView - Section in the home page that displays all products
/// with a horizontal category filter, similar to the layout used in
/// NewOnMartView.
///
/// - Title: "All Products" (see-all navigates to full category products screen).
/// - Filter: horizontal list of category names. Selecting a category shows
///   the products that belong to it in a horizontal list below.
class AllProductsView extends StatefulWidget {
  const AllProductsView({super.key});

  @override
  State<AllProductsView> createState() => _AllProductsViewState();
}

class _AllProductsViewState extends State<AllProductsView> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_initialized) {
        _initialized = true;
        Get.find<CategoryProductsController>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isShop = Get.find<SplashController>().module != null &&
        Get.find<SplashController>().module!.moduleType.toString() ==
            AppConstants.ecommerce;

    return GetBuilder<CategoryProductsController>(builder: (controller) {
      final categories = controller.categoryList;
      final products = controller.productList;
      final selectedIndex = controller.selectedCategoryIndex;
      final isLoadingCategories = controller.isLoading && categories == null;
      final isLoadingProducts = controller.isProductsLoading;

      // Don't render anything until categories are loaded.
      if (isLoadingCategories) {
        return const _AllProductsShimmerView();
      }

      if (categories == null || categories.isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            child: TitleWidget(
              title: 'all_products'.tr,
              onTap: () => Get.toNamed(RouteHelper.getCategoryProductsRoute()),
            ),
          ),

          const SizedBox(height: Dimensions.paddingSizeSmall),

          // Category Filter Row
          SizedBox(
            height: 50,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final category = categories[index];
                return InkWell(
                  onTap: () {
                    if (selectedIndex != index) {
                      controller.selectCategory(index);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                          vertical: Dimensions.paddingSizeSmall,
                        ),
                        child: Text(
                          category.name ?? '',
                          style: robotoMedium.copyWith(
                            color: isSelected
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).disabledColor,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      isSelected
                          ? SizedBox(
                              height: 6,
                              width: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            )
                          : const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),

          // Products Horizontal List
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
            child: SizedBox(
              height: 285,
              width: Get.width,
              child: _buildProductsSection(
                products: products,
                isLoading: isLoadingProducts,
                isShop: isShop,
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _buildProductsSection({
    required List<Item>? products,
    required bool isLoading,
    required bool isShop,
  }) {
    if (isLoading && (products == null || products.isEmpty)) {
      return const _AllProductsListShimmer();
    }

    if (products == null || products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Text(
            'no_product_found'.tr,
            style: robotoRegular.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(
            bottom: Dimensions.paddingSizeDefault,
            right: Dimensions.paddingSizeDefault,
            top: Dimensions.paddingSizeDefault,
          ),
          child: ItemCard(
            item: products[index],
            isPopularItem: false,
            isPopularItemCart: false,
            isFood: !isShop,
            isShop: isShop,
            index: index,
          ),
        );
      },
    );
  }
}

class _AllProductsShimmerView extends StatelessWidget {
  const _AllProductsShimmerView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeDefault),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Title shimmer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            enabled: true,
            child: Container(
              height: 20,
              width: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).shadowColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
            ),
          ),
        ),

        const SizedBox(height: Dimensions.paddingSizeDefault),

        // Filter chips shimmer
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            itemCount: 6,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                  vertical: Dimensions.paddingSizeSmall,
                ),
                child: Shimmer(
                  duration: const Duration(seconds: 2),
                  enabled: true,
                  child: Container(
                    height: 18,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).shadowColor,
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Products shimmer list
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          ),
          child: const SizedBox(
            height: 285,
            child: _AllProductsListShimmer(),
          ),
        ),
      ]),
    );
  }
}

class _AllProductsListShimmer extends StatelessWidget {
  const _AllProductsListShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(
            bottom: Dimensions.paddingSizeDefault,
            right: Dimensions.paddingSizeDefault,
            top: Dimensions.paddingSizeDefault,
          ),
          child: Shimmer(
            duration: const Duration(seconds: 2),
            enabled: true,
            child: Container(
              padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
              height: 285,
              width: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              ),
              child: Column(children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).shadowColor,
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: Column(children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      ),
                      height: 15,
                      width: 100,
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      ),
                      height: 20,
                      width: 200,
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Container(
                      height: 15,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).shadowColor,
                        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}