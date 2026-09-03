
import 'package:pickles_and_pies/features/rental_module/home/domain/repositories/taxi_home_repository_interface.dart';
import 'package:pickles_and_pies/features/rental_module/home/domain/services/taxi_home_service_interface.dart';

class TaxiHomeService implements TaxiHomeServiceInterface {
  final TaxiHomeRepositoryInterface taxiHomeRepositoryInterface;
  TaxiHomeService({required this.taxiHomeRepositoryInterface});

}