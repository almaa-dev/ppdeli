import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pickles_and_pies/common/widgets/custom_app_bar.dart';
import 'package:pickles_and_pies/common/widgets/custom_image.dart';
import 'package:pickles_and_pies/common/widgets/custom_loader.dart';
import 'package:pickles_and_pies/common/widgets/item_view.dart';
import 'package:pickles_and_pies/common/widgets/menu_drawer.dart';
import 'package:pickles_and_pies/common/widgets/no_data_screen.dart';
import 'package:pickles_and_pies/features/category/domain/models/category_model.dart';
import 'package:pickles_and_pies/features/category_products/controllers/category_products_controller.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/styles.dart';

/// CategoryProductsScreen - Two-column layout
/// 
/// Left Column: Main categories list with selection indicator
/// Right Column: Dynamic content with "All Products" card and accordion subcategories
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({super.key});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize controller with Stale-While-Revalidate pattern
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<CategoryProductsController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveHelper.isDesktop(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const CustomAppBar(
        title: 'All Categories',
        backButton: true,
        showCart: true,
      ),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: GetBuilder<CategoryProductsController>(
          builder: (controller) {
            // Loading state
            if (controller.isLoading && controller.categoryList == null) {
              return const Center(child: CustomLoaderWidget());
            }

            // Empty state
            if (controller.categoryList == null || controller.categoryList!.isEmpty) {
              return NoDataScreen(text: 'no_category_found'.tr);
            }

            return isDesktop 
              ? _buildDesktopLayout(controller)
              : _buildMobileLayout(controller);
          },
        ),
      ),
    );
  }

  /// Desktop layout - wider columns
  Widget _buildDesktopLayout(CategoryProductsController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Categories (narrower)
        SizedBox(
          width: 300,
          child: _buildCategoriesList(controller),
        ),
        
        // Divider
        Container(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
        
        // Right Column - Content (wider)
        Expanded(
          child: _buildContentPanel(controller),
        ),
      ],
    );
  }

  /// Mobile layout - same proportions adapted for smaller screens
  Widget _buildMobileLayout(CategoryProductsController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column - Categories (about 30% of width)
        SizedBox(
          width: 100,
          child: _buildCategoriesList(controller),
        ),
        
        // Divider
        Container(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
        
        // Right Column - Content (about 70% of width)
        Expanded(
          child: _buildContentPanel(controller),
        ),
      ],
    );
  }

  /// Left column - Categories list
  Widget _buildCategoriesList(CategoryProductsController controller) {
    return Container(
      color: Theme.of(context).cardColor.withValues(alpha: 0.5),
      child: ListView.builder(
        itemCount: controller.categoryList!.length,
        padding: const EdgeInsets.symmetric(vertical: Dimensions.paddingSizeSmall),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = controller.categoryList![index];
          final isSelected = index == controller.selectedCategoryIndex;
          
          return _CategoryListItem(
            category: category,
            isSelected: isSelected,
            onTap: () => controller.selectCategory(index),
          );
        },
      ),
    );
  }

  /// Right column - Content panel
  Widget _buildContentPanel(CategoryProductsController controller) {
    final selectedCategory = controller.selectedCategory;
    
    if (selectedCategory == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "All [Category] Products" Card
          _AllProductsCard(
            categoryName: selectedCategory.name ?? 'Category',
            onTap: () => _navigateToCategoryItems(selectedCategory),
          ),
          
          const SizedBox(height: Dimensions.paddingSizeLarge),
          
          // Subcategories Filter Chips
          _buildSubcategoriesFilter(controller),
          
          const SizedBox(height: Dimensions.paddingSizeLarge),
          
          // Products Grid
          _buildProductsGrid(controller),
        ],
      ),
    );
  }

  /// Build subcategories filter chips
  Widget _buildSubcategoriesFilter(CategoryProductsController controller) {
    final subCategories = controller.currentSubCategories;
    
    if (subCategories == null) {
      // Loading subcategories
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: CustomLoaderWidget(),
        ),
      );
    }

    if (subCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'subcategories'.tr,
          style: robotoBold.copyWith(
            fontSize: Dimensions.fontSizeLarge,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        
        // Filter Chips
        Wrap(
          spacing: Dimensions.paddingSizeSmall,
          runSpacing: Dimensions.paddingSizeSmall,
          children: [
            // "All" Chip
            _FilterChip(
              label: 'all'.tr,
              isSelected: controller.selectedSubCategoryId == null,
              onTap: () => controller.selectSubCategory(null),
            ),
            // Subcategory Chips
            ...subCategories.map((subCategory) => _FilterChip(
              label: subCategory.name ?? '',
              isSelected: controller.selectedSubCategoryId == subCategory.id,
              onTap: () => controller.selectSubCategory(subCategory.id),
            )),
          ],
        ),
      ],
    );
  }

  /// Build products grid
  Widget _buildProductsGrid(CategoryProductsController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              controller.selectedSubCategoryId == null
                ? 'all_products'.tr
                : 'products'.tr,
              style: robotoBold.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            // View All Button
            TextButton(
              onPressed: () => _navigateToCategoryItems(controller.selectedCategory!),
              child: Text(
                'view_all'.tr,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        
        // Products Grid
        if (controller.isProductsLoading && controller.productList == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: CustomLoaderWidget(),
            ),
          )
        else if (controller.productList == null || controller.productList!.isEmpty)
          NoDataScreen(
            text: 'no_product_found'.tr,
          )
        else
          ItemsView(
            isStore: false,
            items: controller.productList,
            stores: null,
            noDataText: 'no_product_found'.tr,
            isScrollable: false,
            shimmerLength: 6,
          ),
      ],
    );
  }

  /// Navigate to CategoryItemScreen
  void _navigateToCategoryItems(CategoryModel category) {
    Get.toNamed(RouteHelper.getCategoryItemRoute(
      category.id,
      category.name ?? 'Category',
      slug: category.slug ?? '',
    ));
  }
}

/// Category list item widget for left column
class _CategoryListItem extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryListItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
          vertical: Dimensions.paddingSizeDefault,
        ),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected 
                ? Theme.of(context).primaryColor
                : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Image
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: Container(
                width: ResponsiveHelper.isDesktop(context) ? 60 : 50,
                height: ResponsiveHelper.isDesktop(context) ? 60 : 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: category.imageFullUrl != null && category.imageFullUrl!.isNotEmpty
                  ? CustomImage(
                      image: category.imageFullUrl!,
                      height: ResponsiveHelper.isDesktop(context) ? 60 : 50,
                      width: ResponsiveHelper.isDesktop(context) ? 60 : 50,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      Icons.category_outlined,
                      color: Theme.of(context).primaryColor,
                      size: ResponsiveHelper.isDesktop(context) ? 30 : 24,
                    ),
              ),
            ),
            
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            
            // Category Name
            Text(
              category.name ?? '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: isSelected
                ? robotoMedium.copyWith(
                    fontSize: ResponsiveHelper.isDesktop(context) 
                      ? Dimensions.fontSizeDefault 
                      : Dimensions.fontSizeSmall,
                    color: Theme.of(context).primaryColor,
                  )
                : robotoRegular.copyWith(
                    fontSize: ResponsiveHelper.isDesktop(context) 
                      ? Dimensions.fontSizeDefault 
                      : Dimensions.fontSizeSmall,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "All Products" card widget
class _AllProductsCard extends StatelessWidget {
  final String categoryName;
  final VoidCallback onTap;

  const _AllProductsCard({
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'All $categoryName Products',
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter chip widget for subcategory selection
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: robotoMedium.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
