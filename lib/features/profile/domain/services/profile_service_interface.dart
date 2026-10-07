import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pickles_and_pies/common/models/response_model.dart';
import 'package:pickles_and_pies/features/profile/domain/models/update_user_model.dart';
import 'package:pickles_and_pies/features/profile/domain/models/userinfo_model.dart';

abstract class ProfileServiceInterface {
  Future<UserInfoModel?> getUserInfo();
  //Future<ResponseModel> updateProfile(UserInfoModel userInfoModel, XFile? data, String token);
  Future<ResponseModel> updateProfile(UpdateUserModel userInfoModel, XFile? data, String token);
  Future<ResponseModel> changePassword(UserInfoModel userInfoModel);
  Future<Response> deleteUser();
  
  /// Phone-based account deletion (new anonymization endpoint).
  /// POST /api/v1/customer/delete-account with body `{ "phone": "..." }`.
  Future<Response> deleteAccountByPhone(String phone);
  Future<XFile?> pickImageFromGallery();
}