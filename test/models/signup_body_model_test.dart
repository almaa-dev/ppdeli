import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/features/auth/domain/models/signup_body_model.dart';

void main() {
  group('SignUpBodyModel', () {
    test('fromJson should correctly parse all fields', () {
      final json = {
        'f_name': 'Ahmed',
        'l_name': 'Mohammed',
        'phone': '+966500000000',
        'email': 'ahmed@example.com',
        'password': 'SecurePass123',
        'ref_code': 'REF123',
        'cm_firebase_token': 'firebase-token-xyz',
        'guest_id': 12345,
        'name': 'Ahmed Mohammed',
      };

      final model = SignUpBodyModel.fromJson(json);

      expect(model.fName, 'Ahmed');
      expect(model.lName, 'Mohammed');
      expect(model.phone, '+966500000000');
      expect(model.email, 'ahmed@example.com');
      expect(model.password, 'SecurePass123');
      expect(model.refCode, 'REF123');
      expect(model.deviceToken, 'firebase-token-xyz');
      expect(model.guestId, 12345);
      expect(model.name, 'Ahmed Mohammed');
    });

    test('fromJson should handle missing optional fields as null', () {
      final json = {
        'f_name': 'Ahmed',
        'phone': '+966500000000',
        'password': 'SecurePass123',
      };

      final model = SignUpBodyModel.fromJson(json);

      expect(model.fName, 'Ahmed');
      expect(model.lName, isNull);
      expect(model.email, isNull);
      expect(model.refCode, isNull);
      expect(model.deviceToken, isNull);
      expect(model.guestId, isNull);
      expect(model.name, isNull);
    });

    test('fromJson should handle empty json gracefully', () {
      final model = SignUpBodyModel.fromJson({});

      expect(model.fName, isNull);
      expect(model.lName, isNull);
      expect(model.phone, isNull);
      expect(model.email, isNull);
      expect(model.password, isNull);
    });

    test('toJson should serialize all fields correctly', () {
      final model = SignUpBodyModel(
        fName: 'Ahmed',
        lName: 'Mohammed',
        phone: '+966500000000',
        email: 'ahmed@example.com',
        password: 'SecurePass123',
        refCode: 'REF123',
        deviceToken: 'firebase-token-xyz',
        guestId: 12345,
        name: 'Ahmed Mohammed',
      );

      final json = model.toJson();

      expect(json['f_name'], 'Ahmed');
      expect(json['l_name'], 'Mohammed');
      expect(json['phone'], '+966500000000');
      expect(json['email'], 'ahmed@example.com');
      expect(json['password'], 'SecurePass123');
      expect(json['ref_code'], 'REF123');
      expect(json['cm_firebase_token'], 'firebase-token-xyz');
      expect(json['guest_id'], 12345);
      expect(json['name'], 'Ahmed Mohammed');
    });

    test('toJson should produce a map with all expected keys', () {
      final model = SignUpBodyModel();
      final json = model.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('f_name'), true);
      expect(json.containsKey('l_name'), true);
      expect(json.containsKey('phone'), true);
      expect(json.containsKey('email'), true);
      expect(json.containsKey('password'), true);
      expect(json.containsKey('ref_code'), true);
      expect(json.containsKey('cm_firebase_token'), true);
      expect(json.containsKey('guest_id'), true);
      expect(json.containsKey('name'), true);
    });

    test('roundtrip fromJson -> toJson should preserve data', () {
      final original = SignUpBodyModel(
        fName: 'Ahmed',
        lName: 'Mohammed',
        phone: '+966500000000',
        email: 'ahmed@example.com',
        password: 'SecurePass123',
        refCode: 'REF123',
        deviceToken: 'firebase-token-xyz',
        guestId: 12345,
        name: 'Ahmed Mohammed',
      );

      final json = original.toJson();
      final restored = SignUpBodyModel.fromJson(json);

      expect(restored.fName, original.fName);
      expect(restored.lName, original.lName);
      expect(restored.phone, original.phone);
      expect(restored.email, original.email);
      expect(restored.password, original.password);
      expect(restored.refCode, original.refCode);
      expect(restored.deviceToken, original.deviceToken);
      expect(restored.guestId, original.guestId);
      expect(restored.name, original.name);
    });
  });
}