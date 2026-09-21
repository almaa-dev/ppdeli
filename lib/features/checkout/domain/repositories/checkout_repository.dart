import 'dart:convert';
import 'dart:developer';
import 'package:get/get_connect/connect.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickles_and_pies/api/api_client.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/saved_prescription_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/surge_price_model.dart';
import 'package:pickles_and_pies/features/payment/domain/models/offline_method_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/place_order_body_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/repositories/checkout_repository_interface.dart';
import 'package:pickles_and_pies/util/app_constants.dart';

import '../../../../common/widgets/custom_snackbar.dart';

class CheckoutRepository implements CheckoutRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  CheckoutRepository({ required this.apiClient, required this.sharedPreferences});

  @override
  Future<int> getDmTipMostTapped() async {
    int mostDmTipAmount = 0;
    Response response = await apiClient.getData(AppConstants.mostTipsUri);
    if (response.statusCode == 200) {
      mostDmTipAmount = response.body['most_tips_amount'];
    }
    return mostDmTipAmount;
  }

  @override
  Future<bool> saveSharedPrefDmTipIndex(String index) async {
    return await sharedPreferences.setString(AppConstants.dmTipIndex, index);
  }

  @override
  String getSharedPrefDmTipIndex() {
    return sharedPreferences.getString(AppConstants.dmTipIndex) ?? "";
  }

  @override
  Future<Response> getDistanceInMeter(LatLng originLatLng, LatLng destinationLatLng) async {
    return await apiClient.getData(
      '${AppConstants.distanceMatrixUri}?origin_lat=${originLatLng.latitude}&origin_lng=${originLatLng.longitude}'
          '&destination_lat=${destinationLatLng.latitude}&destination_lng=${destinationLatLng.longitude}&mode=WALK',
      handleError: false,
    );
  }

  @override
  Future<double> getExtraCharge(double? distance) async {
    double extraCharge = 0;
    Response response = await apiClient.getData('${AppConstants.vehicleChargeUri}?distance=$distance', handleError: false);
    if (response.statusCode == 200) {
      extraCharge = double.parse(response.body.toString());
    }
    return extraCharge;
  }

  @override
  Future<Response> placeOrder(PlaceOrderBodyModel orderBody, List<MultipartBody>? orderAttachment, List<String>? savedImages) async {
    Map<String, String> body = orderBody.toJson();
    if(savedImages != null && savedImages.isNotEmpty) {
      final List<String> cleanedSavedImages = savedImages.map((image) => image.trim()).where((image) => image.isNotEmpty).toList();
      if(cleanedSavedImages.isNotEmpty) {
        body['saved_images'] = jsonEncode(cleanedSavedImages);
        for(int index = 0; index < cleanedSavedImages.length; index++) {
          body['saved_images[$index]'] = cleanedSavedImages[index];
        }
      }
    }
    log("order Attachment: ${orderAttachment?.map((e) => e.file?.name).toList()}");
    log("Order Body: $body");
    return await apiClient.postMultipartData(AppConstants.placeOrderUri, body, orderAttachment ?? [], handleError: false);
  }

  @override
  Future<Response> placePrescriptionOrder(int? storeId, double? distance, String address, String longitude, String latitude, String note,
      List<MultipartBody> orderAttachment, List<String> savedImages, String dmTips, String deliveryInstruction) async {

    Map<String, String> body = {
      'store_id': storeId.toString(),
      'distance': distance.toString(),
      'address': address,
      'longitude': longitude,
      'latitude': latitude,
      'order_note': note,
      'dm_tips': dmTips,
      'delivery_instruction': deliveryInstruction,
      'payment_method': 'cash_on_delivery',
      'order_type': 'delivery',
    };
    if(savedImages.isNotEmpty) {
      final List<String> cleanedSavedImages = savedImages.map((image) => image.trim()).where((image) => image.isNotEmpty).toList();
      if(cleanedSavedImages.isNotEmpty) {
        body['saved_images'] = jsonEncode(cleanedSavedImages);
        for(int index = 0; index < cleanedSavedImages.length; index++) {
          body['saved_images[$index]'] = cleanedSavedImages[index];
        }
      }
    }
    return await apiClient.postMultipartData(AppConstants.placePrescriptionOrderUri, body, orderAttachment, handleError: false);
  }

  @override
  Future<List<SavedPrescriptionModel>?> getSavedPrescriptionImages() async {
    List<SavedPrescriptionModel>? savedFiles;
    Response response = await apiClient.getData(AppConstants.savedFilesUri, handleError: false);
    if (response.statusCode == 200 && response.body != null && response.body['saved_files'] is List) {
      savedFiles = [];
      for (final savedFile in response.body['saved_files']) {
        if (savedFile is Map) {
          savedFiles.add(SavedPrescriptionModel.fromJson( Map<String, dynamic>.from(savedFile)));
        }
      }
    }
    return savedFiles;
  }

  @override
  Future<Response> storeSavedPrescriptionImages(List<MultipartBody> images) async {
    final response = await apiClient.postMultipartData(AppConstants.storeSavedFilesUri, {}, images, handleError: false);

    if (response.statusCode == 400 && response.statusText == 'connection_to_api_server_failed'.tr) {
      showCustomSnackBar('max_file_size_2mb'.tr);
      return response;
    }
    return response;
  }

  @override
  Future<Response> deleteSavedPrescriptionImages() async {
    return await apiClient.deleteData(AppConstants.deleteSavedFilesUri, handleError: false);
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) async{
    return await _getOfflineMethodList();
  }

  Future<List<OfflineMethodModel>?> _getOfflineMethodList() async {
    List<OfflineMethodModel>? offlineMethodList;
    Response response = await apiClient.getData(AppConstants.offlineMethodListUri);
    if (response.statusCode == 200) {
      offlineMethodList = [];
      response.body.forEach((method) => offlineMethodList!.add(OfflineMethodModel.fromJson(method)));
    }
    return offlineMethodList;
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }

  @override
  Future<Response> getOrderTax(PlaceOrderBodyModel orderBody) async {
    Response response = await apiClient.postData(AppConstants.getOrderTaxUri, orderBody.toJson());
    return response;
  }

  @override
  Future<SurgePriceModel?> getSurgePrice({required String zoneId, required String moduleId, required String dateTime, String? guestId}) async {
    SurgePriceModel? surgePrice;
    Map<String, dynamic> body = {
      'zone_id': zoneId,
      'module_id': moduleId,
      'date_time': dateTime,
      'guest_id': guestId ?? '',
    };
    Response response = await apiClient.postData(AppConstants.getSurgePriceUri, body);
    if (response.statusCode == 200) {
      surgePrice = SurgePriceModel.fromJson(response.body);
    }
    return surgePrice;
  }

  // ===========================================================================
  // Last Payment Method Preference (identity-scoped, non-sensitive)
  // ===========================================================================
  /// Builds a stable SharedPreferences key that includes the identity suffix.
  /// For logged-out users we use the guest id; for logged-in users we use the
  /// user id. When neither is available we fall back to a global key, which
  /// is acceptable only as a last resort (no real account associated).
  String _resolvePaymentPrefKey(String identity) {
    final safeIdentity = identity.trim().isEmpty ? 'anonymous' : identity.trim();
    return '${AppConstants.lastPaymentPrefBaseKey}_$safeIdentity';
  }

  @override
  Future<bool> saveLastPaymentMethod({
    required String identity,
    required int methodIndex,
    String? digitalPaymentName,
    int? offlineBankIndex,
  }) async {
    try {
      final payload = jsonEncode({
        'method_index': methodIndex,
        // null-safe: serialise the absence of a digital gateway explicitly so
        // a later read can distinguish "saved as null" from "never saved".
        'digital_payment_name': digitalPaymentName,
        'offline_bank_index': offlineBankIndex,
        // schema version helps us discard older payloads safely if the shape
        // ever changes.
        'v': 1,
      });
      return await sharedPreferences.setString(_resolvePaymentPrefKey(identity), payload);
    } catch (_) {
      return false;
    }
  }

  @override
  Map<String, dynamic>? getLastPaymentMethod({required String identity}) {
    try {
      final raw = sharedPreferences.getString(_resolvePaymentPrefKey(identity));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Malformed payload (older schema, partial write, etc.) — treat as no
      // saved preference. The caller will fall back to -1 and require the
      // user to pick a method again.
      return null;
    }
  }

  @override
  Future<bool> clearLastPaymentMethod({required String identity}) async {
    try {
      return await sharedPreferences.remove(_resolvePaymentPrefKey(identity));
    } catch (_) {
      return false;
    }
  }
}
