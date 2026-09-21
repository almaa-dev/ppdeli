import 'package:get/get_connect/http/src/response/response.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pickles_and_pies/api/api_client.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/place_order_body_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/saved_prescription_model.dart';
import 'package:pickles_and_pies/features/checkout/domain/models/surge_price_model.dart';
import 'package:pickles_and_pies/interfaces/repository_interface.dart';

abstract class CheckoutRepositoryInterface extends RepositoryInterface {
  Future<int> getDmTipMostTapped();
  String getSharedPrefDmTipIndex();
  Future<bool> saveSharedPrefDmTipIndex(String index);
  Future<Response> getDistanceInMeter(LatLng originLatLng, LatLng destinationLatLng);
  Future<double> getExtraCharge(double? distance);
  Future<Response> placeOrder(PlaceOrderBodyModel orderBody, List<MultipartBody>? orderAttachment, List<String>? savedImages);
  Future<Response> placePrescriptionOrder(int? storeId, double? distance, String address, String longitude, String latitude, String note, List<MultipartBody> orderAttachment, List<String> savedImages, String dmTips, String deliveryInstruction);
  Future<Response> getOrderTax(PlaceOrderBodyModel placeOrderBody);
  Future<SurgePriceModel?> getSurgePrice({required String zoneId, required String moduleId, required String dateTime, String? guestId});
  Future<Response> deleteSavedPrescriptionImages();
  Future<List<SavedPrescriptionModel>?> getSavedPrescriptionImages();
  Future<Response> storeSavedPrescriptionImages(List<MultipartBody> images);

  // ===========================================================================
  // Last Payment Method Preference (non-sensitive, identity-scoped)
  // ===========================================================================
  // Persists ONLY the method identifier (e.g. 'cash_on_delivery', 'wallet',
  // 'stripe', 'paypal', offline bank index). NEVER card numbers / CVV / expiry.
  // Storage key is suffixed with the current user/guest id by the
  // implementation so different identities on the same device never see each
  // other's preferred payment method.
  // ===========================================================================
  Future<bool> saveLastPaymentMethod({
    required String identity,
    required int methodIndex,
    String? digitalPaymentName,
    int? offlineBankIndex,
  });
  Map<String, dynamic>? getLastPaymentMethod({required String identity});
  Future<bool> clearLastPaymentMethod({required String identity});
}
