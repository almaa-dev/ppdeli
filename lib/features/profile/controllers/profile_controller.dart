import 'package:pickles_and_pies/features/cart/controllers/cart_controller.dart';
import 'package:pickles_and_pies/features/favourite/controllers/favourite_controller.dart';
import 'package:pickles_and_pies/features/chat/domain/models/conversation_model.dart';
import 'package:pickles_and_pies/common/models/response_model.dart';
import 'package:pickles_and_pies/features/location/controllers/location_controller.dart';
import 'package:pickles_and_pies/features/profile/domain/models/update_user_model.dart';
import 'package:pickles_and_pies/features/profile/domain/models/userinfo_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pickles_and_pies/features/auth/controllers/auth_controller.dart';
import 'package:pickles_and_pies/features/verification/screens/verification_screen.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/common/widgets/custom_snackbar.dart';
import 'package:pickles_and_pies/features/profile/domain/services/profile_service_interface.dart';

class ProfileController extends GetxController implements GetxService {
 final ProfileServiceInterface profileServiceInterface;
  ProfileController({required this.profileServiceInterface});

  UserInfoModel? _userInfoModel;
  UserInfoModel? get userInfoModel => _userInfoModel;

  XFile? _pickedFile;
  XFile? get pickedFile => _pickedFile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Guard to prevent duplicate / double-tap Delete Account requests.
  /// Stays true for the entire duration of the network round-trip + local
  /// cleanup so that repeated taps cannot fire a second deleteUser() flow.
  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  Future<void> getUserInfo() async {
    _pickedFile = null;
    UserInfoModel? userInfoModel = await profileServiceInterface.getUserInfo();
    if (userInfoModel != null) {
      _userInfoModel = userInfoModel;
    }
    update();
  }

  void setForceFullyUserEmpty() {
    _userInfoModel = null;
  }

  Future<ResponseModel> updateUserInfo(UpdateUserModel updateUserModel, String token, {bool fromVerification = false, bool fromButton = false}) async {
    if(fromButton) {
      _isLoading = true;
      update();
    }
    ResponseModel responseModel = await profileServiceInterface.updateProfile(updateUserModel, _pickedFile, token);
    if(!fromVerification) {
      _updateProfileResponseHandle(responseModel, updateUserModel, token);
    }
    _isLoading = false;
    update();
    return responseModel;
  }

  Future<void> _updateProfileResponseHandle(ResponseModel responseModel, UpdateUserModel updateUserModel, String token) async {
    updateUserModel.verificationOn = responseModel.updateProfileResponseModel?.verificationOn;
    updateUserModel.verificationMedium = responseModel.updateProfileResponseModel?.verificationMedium;

    if(responseModel.isSuccess && responseModel.updateProfileResponseModel != null && responseModel.updateProfileResponseModel!.verificationOn != null && responseModel.updateProfileResponseModel!.verificationOn! == 'phone'){
      if(responseModel.updateProfileResponseModel!.verificationMedium! == 'firebase') {
        Get.find<AuthController>().firebaseVerifyPhoneNumber(updateUserModel.phone!, token, '', fromSignUp: false, updateUserModel: updateUserModel);
      } else {
        if(Get.isDialogOpen!) {
          Get.back();
        }
        if(ResponsiveHelper.isDesktop(Get.context)) {
          Get.dialog(VerificationScreen(
            number: updateUserModel.phone!, email: null, token: '', fromSignUp: false,
            fromForgetPassword: false, loginType: '', password: '', userModel: updateUserModel,
          ));
        } else {
          Get.toNamed(RouteHelper.getVerificationRoute(updateUserModel.phone!, null, '', '', null, '', updateUserModel: updateUserModel));
        }
      }
    } else if(responseModel.isSuccess && responseModel.updateProfileResponseModel != null && responseModel.updateProfileResponseModel!.verificationOn != null && responseModel.updateProfileResponseModel!.verificationOn! == 'email'){
      if(Get.isDialogOpen!) {
        Get.back();
      }
      if(ResponsiveHelper.isDesktop(Get.context)) {
        Get.dialog(VerificationScreen(
          number: null, email: updateUserModel.email!, token: '', fromSignUp: false,
          fromForgetPassword: false, loginType: '', password: '', userModel: updateUserModel,
        ));
      } else {
        Get.toNamed(RouteHelper.getVerificationRoute(null, updateUserModel.email!, '', '', null, '', updateUserModel: updateUserModel));
      }
    } else if(responseModel.isSuccess && responseModel.updateProfileResponseModel == null){
      if(Get.isDialogOpen!) {
        Get.back();
      }
      await getUserInfo();
      if(!ResponsiveHelper.isDesktop(Get.context)){
        Get.back();
        Get.back();
      }
      _pickedFile = null;
      showCustomSnackBar(responseModel.message, isError: false);
    }  else if(!responseModel.isSuccess && responseModel.updateProfileResponseModel != null){
      if(Get.isDialogOpen!) {
        Get.back();
      }
      showCustomSnackBar(responseModel.updateProfileResponseModel!.message);
    } else {
      if(Get.isDialogOpen!) {
        Get.back();
      }
      showCustomSnackBar(responseModel.message);
    }
  }

  Future<ResponseModel> changePassword(UserInfoModel updatedUserModel) async {
    _isLoading = true;
    update();
    ResponseModel responseModel = await profileServiceInterface.changePassword(updatedUserModel);
    _isLoading = false;
    update();
    return responseModel;
  }

  void updateUserWithNewData(User? user) {
    _userInfoModel!.userInfo = user;
  }

  void pickImage() async {
    _pickedFile = await profileServiceInterface.pickImageFromGallery();
    update();
  }

  void initData({bool isUpdate = false}) {
    _pickedFile = null;
    if(isUpdate){
      update();
    }
  }

  /// Completely deletes the user account and all related data.
  ///
  /// Steps:
  /// 1. Verify connectivity (no offline deletion).
  /// 2. Guard against double-tap / duplicate requests.
  /// 3. Call backend API to delete the account server-side.
  /// 4. Sign out from social providers (Google, Facebook, Apple).
  /// 5. Delete the Firebase Authentication account.
  /// 6. Wipe ALL local data (SharedPreferences, cache, etc.).
  /// 7. Navigate the user back to splash screen.
  ///
  /// If the backend call fails, nothing is destroyed locally so the user
  /// can retry safely.
  Future<void> deleteUser() async {
    // Guard against double-tap / rapid duplicate taps
    if (_isDeleting) {
      return;
    }

    // Offline guard: never destroy local data without backend confirmation
    try {
      final List<ConnectivityResult> connectivityResult =
          await Connectivity().checkConnectivity();
      final bool isOffline = connectivityResult.contains(ConnectivityResult.none) ||
          connectivityResult.isEmpty;
      if (isOffline) {
        showCustomSnackBar('internet_connection_required_to_delete_account'.tr);
        return;
      }
    } catch (e) {
      // If connectivity check itself errors out, fall through and let the
      // backend call surface the real network failure to the user.
      debugPrint('Connectivity check error during deleteUser: $e');
    }

    _isDeleting = true;
    _isLoading = true;
    update();
    try {
      Response response = await profileServiceInterface.deleteUser();
      if (response.statusCode == 200) {
        // 1. Sign out from social providers (Google, Facebook, Apple)
        try {
          await Get.find<AuthController>().socialLogout();
        } catch (e) {
          debugPrint('socialLogout error during deletion: $e');
        }

        // 2. Delete the Firebase Authentication account
        try {
          if (!GetPlatform.isWeb) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await user.delete();
            }
          }
        } catch (e) {
          debugPrint('FirebaseAuth.currentUser.delete error: $e');
        }

        // 3. Wipe ALL SharedPreferences keys related to the user
        try {
          await Get.find<AuthController>().wipeAllUserLocalData();
        } catch (e) {
          debugPrint('wipeAllUserLocalData error: $e');
        }

        // 4. Clear cart and favourites (in-memory controllers)
        try {
          await Get.find<CartController>().clearCartList();
        } catch (e) {
          debugPrint('clearCartList error: $e');
        }
        try {
          Get.find<FavouriteController>().removeFavourite();
        } catch (e) {
          debugPrint('removeFavourite error: $e');
        }

        // 5. Clear image / network cache (cached_network_image, flutter_cache_manager)
        try {
          if (!GetPlatform.isWeb) {
            await DefaultCacheManager().emptyCache();
            final cacheDir = await getTemporaryDirectory();
            final appCacheDir = await getApplicationCacheDirectory();
            if (cacheDir.existsSync()) {
              cacheDir.deleteSync(recursive: true);
            }
            if (appCacheDir.existsSync()) {
              appCacheDir.deleteSync(recursive: true);
            }
          }
        } catch (e) {
          debugPrint('Cache cleanup error: $e');
        }

        // 6. Clear remember-me state
        try {
          if (Get.find<AuthController>().isActiveRememberMe) {
            Get.find<AuthController>().toggleRememberMe();
          }
        } catch (e) {
          debugPrint('toggleRememberMe error: $e');
        }

        setForceFullyUserEmpty();
        _isLoading = false;
        _isDeleting = false;
        showCustomSnackBar('account_deleted_successfully'.tr, isError: false);
        Get.find<LocationController>().navigateToLocationScreen('splash', offNamed: true);
      } else {
        _isLoading = false;
        _isDeleting = false;
        if (Get.isDialogOpen!) {
          Get.back();
        }
        showCustomSnackBar('unable_to_delete_account_please_try_again'.tr);
      }
    } catch (e) {
      _isLoading = false;
      _isDeleting = false;
      update();
      if (Get.isDialogOpen!) {
        Get.back();
      }
      showCustomSnackBar('unable_to_delete_account_please_try_again'.tr);
      debugPrint('deleteUser error: $e');
      return;
    }
    update();
  }

  void clearUserInfo() {
    _userInfoModel = null;
    update();
  }

}