import 'package:get/get.dart';
import 'package:pickles_and_pies/common/enums/data_source_enum.dart';
import 'package:pickles_and_pies/features/rental_module/home/domain/services/taxi_home_service_interface.dart';

class TaxiHomeController extends GetxController implements GetxService {
  final TaxiHomeServiceInterface taxiHomeServiceInterface;

  TaxiHomeController({required this.taxiHomeServiceInterface});

  Future<void> getTopRatedCarList(int offset, bool reload, {DataSourceEnum source = DataSourceEnum.local}) async {

  }


  Future<void> getTaxiBannerList(bool reload, {DataSourceEnum source = DataSourceEnum.local}) async {

  }

  Future<void> getTaxiCouponList(bool reload, {DataSourceEnum source = DataSourceEnum.local}) async {

  }


}