import 'package:pickles_and_pies/features/cart/controllers/cart_controller.dart';
import 'package:pickles_and_pies/features/favourite/controllers/favourite_controller.dart';
import 'package:pickles_and_pies/features/chat/domain/models/conversation_model.dart';
import 'package:pickles_and_pies/common/models/response_model.dart';
import 'package:pickles_and_pies/features/profile/domain/models/update_user_model.dart';
import 'package:pickles_and_pies/features/profile/domain/models/userinfo_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pickles_and_pies/common/widgets/custom_button.dart';
import 'package:pickles_and_pies/common/widgets/custom_snackbar.dart';
import 'package:pickles_and_pies/common/widgets/non_dismissible_loading_dialog.dart';
import 'package:pickles_and_pies/features/auth/controllers/auth_controller.dart';
import 'package:pickles_and_pies/features/verification/screens/verification_screen.dart';
import 'package:pickles_and_pies/helper/responsive_helper.dart';
import 'package:pickles_and_pies/helper/route_helper.dart';
import 'package:pickles_and_pies/util/dimensions.dart';
import 'package:pickles_and_pies/util/images.dart';
import 'package:pickles_and_pies/util/styles.dart';
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
  /// New flow (phone-based anonymization endpoint):
  ///
  ///   1. Re-entry guard: refuse double-taps.
  ///   2. Offline guard: never destroy local data without backend confirmation.
  ///   3. Show the **confirmation dialog** ("Are you sure you want to delete
  ///      your account? This action cannot be undone.").
  ///   4. On confirm → show a **non-dismissible Loading Dialog**
  ///      (`barrierDismissible: false`) so the user cannot tap out of it.
  ///   5. Call `POST /api/v1/customer/delete-account` with the current
  ///      `UserInfoModel.phone`.
  ///   6. On `200`:
  ///        a. Hide the loading dialog.
  ///        b. Show the success dialog with an OK button.
  ///        c. Sign out from social providers (Google, Facebook, Apple).
  ///        d. Delete the Firebase Authentication account (non-web only).
  ///        e. Wipe **all** SharedPreferences keys for this user.
  ///        f. Clear the in-memory Cart and Favourites controllers.
  ///        g. Empty image cache and temporary directories.
  ///        h. Disable the "Remember me" toggle if it was on.
  ///        i. Wait **5 seconds** (`Future.delayed`) so the user reads the
  ///           success message.
  ///        j. Pop the success dialog and `Get.offAllNamed(...)` to the
  ///           Sign-In screen, clearing the entire navigation stack.
  ///
  /// If the backend call fails (non-200 or thrown exception), nothing is
  /// destroyed locally so the user can retry safely.
  Future<void> deleteUser() async {
    // 1. Re-entry guard.
    if (_isDeleting) {
      return;
    }

    // 2. Offline guard: never destroy local data without backend confirmation.
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
      debugPrint('Connectivity check error during deleteUser: $e');
    }

    // 3. Show the confirmation dialog ("Are you sure…").
    //
    // We use a fresh Get.dialog with the EXACT English copy from the spec
    // — no .tr() key, no fallback wording — to avoid localisation drift on
    // this irreversible action.
    final bool? confirmed = await Get.dialog<bool>(
      _DeleteAccountConfirmDialog(
        message:
            'Are you sure you want to delete your account? This action cannot be undone.',
      ),
      barrierDismissible: true,
      useSafeArea: false,
    );

    if (confirmed != true) {
      return; // user tapped Cancel
    }

    _isDeleting = true;
    _isLoading = true;
    update();

    // 4. Show the non-dismissible Loading Dialog.
    NonDismissibleLoadingDialog.show(
      message: 'deleting_account_please_wait'.tr,
    );

    try {
      // 5. Resolve the phone to send. Prefer the in-memory model, then
      // fall back to the cached remember-me phone (covers the rare case
      // where the user has a token but `userInfoModel` has not yet been
      // fetched on this screen).
      String? phone = _userInfoModel?.phone;
      if (phone == null || phone.isEmpty) {
        phone = Get.find<AuthController>().getUserNumber();
      }
      if (phone.trim().isEmpty) {
        throw Exception(
            'Cannot delete account: no phone number associated with this user.');
      }

      // 6. Hit the new anonymization endpoint.
      final Response response =
          await profileServiceInterface.deleteAccountByPhone(phone);

      // The new endpoint considers BOTH the freshly-deleted AND
      // already-deleted cases as success.
      final bool isSuccess = response.statusCode == 200;

      if (isSuccess) {
        // 6a. Hide the loading dialog.
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        // 6b. Show the success dialog with an OK button.
        Get.dialog(
          _AccountDeletedSuccessDialog(
            message:
                'Your account has been deleted successfully. You will be signed out, please wait...',
            onOk: () => Get.back(),
          ),
          barrierDismissible: false,
          useSafeArea: true,
        );

        // 6c. Sign out from social providers (Google, Facebook, Apple).
        try {
          await Get.find<AuthController>().socialLogout();
        } catch (e) {
          debugPrint('socialLogout error during deletion: $e');
        }

        // 6d. Delete the Firebase Authentication account (mobile only).
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

        // 6e. Wipe ALL SharedPreferences keys related to the user.
        try {
          await Get.find<AuthController>().wipeAllUserLocalData();
        } catch (e) {
          debugPrint('wipeAllUserLocalData error: $e');
        }

        // 6f. Clear in-memory cart and favourites.
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

        // 6g. Empty image / network cache + temporary directories.
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

        // 6h. Clear remember-me state if it was active.
        try {
          if (Get.find<AuthController>().isActiveRememberMe) {
            Get.find<AuthController>().toggleRememberMe();
          }
        } catch (e) {
          debugPrint('toggleRememberMe error: $e');
        }

        // Mark the in-memory user model as empty BEFORE we navigate.
        setForceFullyUserEmpty();

        // 6i. Wait 5 seconds so the user reads the success message and
        //     so any local cleanup finishes propagating.
        await Future.delayed(const Duration(seconds: 5));

        // 6j. Pop the success dialog (if still open) and navigate to the
        //     Sign-In screen, clearing the entire navigation stack.
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        _isLoading = false;
        _isDeleting = false;
        update();
        Get.offAllNamed(RouteHelper.getSignInRoute('splash'));
      } else {
        // Backend returned a non-200 status.
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        _isLoading = false;
        _isDeleting = false;
        update();
        showCustomSnackBar('unable_to_delete_account_please_try_again'.tr);
      }
    } catch (e) {
      // Network / unexpected error path.
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      _isLoading = false;
      _isDeleting = false;
      update();
      showCustomSnackBar('unable_to_delete_account_please_try_again'.tr);
      debugPrint('deleteUser error: $e');
      return;
    }
  }

  void clearUserInfo() {
    _userInfoModel = null;
    update();
  }

}

// =============================================================================
// LOCAL DIALOG WIDGETS (kept private to this file because they are tightly
// coupled to the deleteUser() flow above and would not be reused elsewhere).
// =============================================================================

/// Confirmation dialog shown BEFORE we hit the new
/// `/api/v1/customer/delete-account` endpoint.
///
/// The English copy is hard-coded on purpose — localisation drift on this
/// irreversible action is unacceptable.
class _DeleteAccountConfirmDialog extends StatelessWidget {
  final String message;
  const _DeleteAccountConfirmDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
      ),
      insetPadding: const EdgeInsets.all(30),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                child: Image.asset(
                  Images.warning,
                  width: 50,
                  height: 50,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge),
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back<bool>(result: false),
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .disabledColor
                            .withValues(alpha: 0.3),
                        minimumSize: const Size(Dimensions.webMaxWidth, 50),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(Dimensions.radiusSmall),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        textAlign: TextAlign.center,
                        style: robotoBold.copyWith(
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeLarge),
                  Expanded(
                    child: CustomButton(
                      buttonText: 'Confirm',
                      onPressed: () => Get.back<bool>(result: true),
                      radius: Dimensions.radiusSmall,
                      height: 50,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Success dialog shown AFTER the backend has confirmed the account has been
/// anonymised. The dialog stays open while we wipe local data + redirect
/// to the Sign-In screen. The user can dismiss it early with the OK button
/// (we still wait 5 seconds in `deleteUser()` before navigating).
class _AccountDeletedSuccessDialog extends StatelessWidget {
  final String message;
  final VoidCallback onOk;

  const _AccountDeletedSuccessDialog({
    required this.message,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        insetPadding: const EdgeInsets.all(30),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: SizedBox(
          width: 500,
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade600,
                    size: 56,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                    ),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                CustomButton(
                  buttonText: 'OK',
                  onPressed: onOk,
                  radius: Dimensions.radiusSmall,
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}