import 'package:pickles_and_pies/api/api_client.dart';
import 'package:pickles_and_pies/features/auth/domain/models/delivery_man_body.dart';
import 'package:pickles_and_pies/interfaces/repository_interface.dart';

abstract class DeliverymanRegistrationRepositoryInterface extends RepositoryInterface{
  @override
  Future getList({int? offset, int? zoneId, bool isZone = true, bool isVehicle = false});
  Future<bool> registerDeliveryMan(DeliveryManBody deliveryManBody, List<MultipartBody> multiParts);
}