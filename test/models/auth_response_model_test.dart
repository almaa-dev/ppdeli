import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/features/auth/domain/models/auth_response_model.dart';

void main() {
  group('AuthResponseModel', () {
    test('fromJson should parse all fields correctly', () {
      final json = {
        'token': 'auth-token-xyz',
        'is_phone_verified': 1,
        'is_email_verified': 0,
        'is_personal_info': 1,
        'is_exist_user': {
          'id': 42,
          'name': 'Ahmed Mohammed',
          'image': 'https://example.com/avatar.png',
        },
        'login_type': 'phone',
        'email': 'ahmed@example.com',
      };

      final model = AuthResponseModel.fromJson(json);

      expect(model.token, 'auth-token-xyz');
      expect(model.isPhoneVerified, true);
      expect(model.isEmailVerified, false);
      expect(model.isPersonalInfo, true);
      expect(model.isExistUser, isNotNull);
      expect(model.isExistUser!.id, 42);
      expect(model.isExistUser!.name, 'Ahmed Mohammed');
      expect(model.isExistUser!.image, 'https://example.com/avatar.png');
      expect(model.loginType, 'phone');
      expect(model.email, 'ahmed@example.com');
    });

    test('fromJson should handle integer 0/1 as boolean for verification fields', () {
      final json = {
        'token': 'auth-token-xyz',
        'is_phone_verified': 0,
        'is_email_verified': 1,
        'is_personal_info': 0,
      };

      final model = AuthResponseModel.fromJson(json);

      expect(model.isPhoneVerified, false);
      expect(model.isEmailVerified, true);
      expect(model.isPersonalInfo, false);
    });

    test('fromJson should handle null is_exist_user gracefully', () {
      final json = {
        'token': 'auth-token-xyz',
        'is_phone_verified': 1,
      };

      final model = AuthResponseModel.fromJson(json);

      expect(model.token, 'auth-token-xyz');
      expect(model.isExistUser, isNull);
    });

    test('fromJson should handle empty json - missing fields default to false', () {
      final model = AuthResponseModel.fromJson({});

      expect(model.token, isNull);
      // The model converts 0/1 ints to bools with `== 1`, so missing fields
      // are evaluated as `null == 1` which is `false`, not `null`.
      expect(model.isPhoneVerified, false);
      expect(model.isEmailVerified, false);
      expect(model.isPersonalInfo, false);
      expect(model.isExistUser, isNull);
    });

    test('toJson should serialize all fields', () {
      final model = AuthResponseModel(
        token: 'auth-token-xyz',
        isPhoneVerified: true,
        isEmailVerified: false,
        isPersonalInfo: true,
        isExistUser: IsExistUser(id: 42, name: 'Ahmed', image: 'img.png'),
        loginType: 'phone',
        email: 'ahmed@example.com',
      );

      final json = model.toJson();

      expect(json['token'], 'auth-token-xyz');
      expect(json['is_phone_verified'], true);
      expect(json['is_email_verified'], false);
      expect(json['is_personal_info'], true);
      expect(json['is_exist_user'], isA<Map<String, dynamic>>());
      expect(json['login_type'], 'phone');
      expect(json['email'], 'ahmed@example.com');
    });

    test('toJson should not include is_exist_user when null', () {
      final model = AuthResponseModel(
        token: 'auth-token-xyz',
        isPhoneVerified: true,
      );

      final json = model.toJson();

      expect(json.containsKey('is_exist_user'), false);
    });
  });

  group('IsExistUser', () {
    test('fromJson should parse all fields', () {
      final json = {
        'id': 42,
        'name': 'Ahmed Mohammed',
        'image': 'https://example.com/avatar.png',
      };

      final model = IsExistUser.fromJson(json);

      expect(model.id, 42);
      expect(model.name, 'Ahmed Mohammed');
      expect(model.image, 'https://example.com/avatar.png');
    });

    test('fromJson should handle empty json', () {
      final model = IsExistUser.fromJson({});

      expect(model.id, isNull);
      expect(model.name, isNull);
      expect(model.image, isNull);
    });

    test('toJson should serialize all fields', () {
      final model = IsExistUser(
        id: 42,
        name: 'Ahmed',
        image: 'img.png',
      );

      final json = model.toJson();

      expect(json['id'], 42);
      expect(json['name'], 'Ahmed');
      expect(json['image'], 'img.png');
    });
  });
}