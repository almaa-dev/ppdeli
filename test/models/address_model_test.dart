import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/features/address/domain/models/address_model.dart';

void main() {
  group('AddressModel', () {
    test('fromJson should parse all basic fields', () {
      final json = {
        'id': 1,
        'address_type': 'Home',
        'contact_person_number': '+966500000000',
        'address': 'King Fahd Road',
        'additional_address': 'Building 5, Floor 3',
        'latitude': '24.7136',
        'longitude': '46.6753',
        'zone_id': 5,
        '_method': 'cash_on_delivery',
        'contact_person_name': 'Ahmed',
        'road': '123',
        'house': 'A1',
        'floor': '3',
        'contact_person_email': 'home@example.com',
      };

      final model = AddressModel.fromJson(json);

      expect(model.id, 1);
      expect(model.addressType, 'Home');
      expect(model.contactPersonNumber, '+966500000000');
      expect(model.address, 'King Fahd Road');
      expect(model.additionalAddress, 'Building 5, Floor 3');
      expect(model.latitude, '24.7136');
      expect(model.longitude, '46.6753');
      expect(model.zoneId, 5);
      expect(model.method, 'cash_on_delivery');
      expect(model.contactPersonName, 'Ahmed');
      expect(model.streetNumber, '123');
      expect(model.house, 'A1');
      expect(model.floor, '3');
      expect(model.email, 'home@example.com');
    });

    test('fromJson should parse list fields correctly', () {
      final json = {
        'id': 1,
        'contact_person_number': '+966500000000',
        'latitude': '24.7136',
        'longitude': '46.6753',
        'zone_ids': [1, 2, 3],
        'area_ids': [10, 20],
      };

      final model = AddressModel.fromJson(json);

      expect(model.zoneIds, [1, 2, 3]);
      expect(model.areaIds, [10, 20]);
    });

    test('fromJson should serialize zoneIds correctly', () {
      final json = {
        'id': 1,
        'contact_person_number': '+966500000000',
        'latitude': '0',
        'longitude': '0',
        'zone_ids': <int>[1, 2, 3],
      };

      final model = AddressModel.fromJson(json);
      expect(model.zoneIds, [1, 2, 3]);
    });

    test('fromJson should handle zone_id as string', () {
      final json = {
        'id': 1,
        'contact_person_number': '+966500000000',
        'latitude': '24.7136',
        'longitude': '46.6753',
        'zone_id': '5', // String instead of int
      };

      final model = AddressModel.fromJson(json);
      expect(model.zoneId, 5);
    });

    test('toJson should serialize all fields', () {
      final model = AddressModel(
        id: 1,
        addressType: 'Home',
        address: 'King Fahd Road',
        latitude: '24.7136',
        longitude: '46.6753',
        zoneId: 5,
        zoneIds: [1, 2, 3],
        contactPersonName: 'Ahmed',
        email: 'home@example.com',
      );

      final json = model.toJson();

      expect(json['id'], 1);
      expect(json['address_type'], 'Home');
      expect(json['address'], 'King Fahd Road');
      expect(json['latitude'], '24.7136');
      expect(json['longitude'], '46.6753');
      expect(json['zone_id'], 5);
      expect(json['zone_ids'], [1, 2, 3]);
      expect(json['contact_person_name'], 'Ahmed');
      expect(json['contact_person_email'], 'home@example.com');
    });

    test('toJson should not include email when null', () {
      final model = AddressModel(
        id: 1,
        contactPersonNumber: '+966500000000',
        latitude: '24.7136',
        longitude: '46.6753',
      );

      final json = model.toJson();

      expect(json.containsKey('contact_person_email'), false);
    });

    test('copyWith should update only the specified fields', () {
      final original = AddressModel(
        id: 1,
        contactPersonName: 'Ahmed',
        contactPersonNumber: '+966500000000',
        latitude: '24.7136',
        longitude: '46.6753',
        address: 'King Fahd Road',
      );

      final updated = original.copyWith(
        contactPersonName: 'Mohammed',
        contactPersonNumber: '+966511111111',
      );

      expect(updated.id, 1); // unchanged
      expect(updated.contactPersonName, 'Mohammed'); // changed
      expect(updated.contactPersonNumber, '+966511111111'); // changed
      expect(updated.address, 'King Fahd Road'); // unchanged
    });

    test('should produce a non-null string representation', () {
      final model = AddressModel(
        id: 1,
        contactPersonNumber: '+966500000000',
        latitude: '24.7136',
        longitude: '46.6753',
        address: 'Test Address',
      );

      final str = model.toString();

      expect(str, isNotNull);
      expect(str.isNotEmpty, true);
    });
  });
}