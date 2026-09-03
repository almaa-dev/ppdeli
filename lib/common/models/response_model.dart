import 'package:pickles_and_pies/features/auth/domain/models/auth_response_model.dart';
import 'package:pickles_and_pies/features/profile/domain/models/update_profile_response_model.dart';

class ResponseModel {
  final bool _isSuccess;
  final String? _message;
  List<int>? zoneIds;
  AuthResponseModel? authResponseModel;
  UpdateProfileResponseModel? updateProfileResponseModel;
  int? statusCode;
  ResponseModel(this._isSuccess, this._message, {this.zoneIds, this.authResponseModel, this.updateProfileResponseModel, this.statusCode});

  String? get message => _message;
  bool get isSuccess => _isSuccess;
}