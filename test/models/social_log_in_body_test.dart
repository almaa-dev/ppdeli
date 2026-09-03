import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/features/auth/domain/models/social_log_in_body.dart';

void main() {
  group('SocialLogInBody', () {
    test('fromJson should correctly parse all fields', () {
      final json = {
        'email': 'user@example.com',
        'token': 'social-token-abc',
        'unique_id': 'unique-123',
        'medium': 'google',
        'phone': '+966500000000',
        'cm_firebase_token': 'firebase-token-xyz',
        'access_token': 9876543210,
        'login_type': 'social',
        'verified': '1',
        'guest_id': 'guest-123',
        'platform': 'android',
      };

      final model = SocialLogInBody.fromJson(json);

      expect(model.email, 'user@example.com');
      expect(model.token, 'social-token-abc');
      expect(model.uniqueId, 'unique-123');
      expect(model.medium, 'google');
      expect(model.phone, '+966500000000');
      expect(model.deviceToken, 'firebase-token-xyz');
      expect(model.accessToken, 9876543210);
      expect(model.loginType, 'social');
      expect(model.verified, '1');
      expect(model.guestId, 'guest-123');
      expect(model.platform, 'android');
    });

    test('fromJson should handle missing fields as null', () {
      final json = {
        'email': 'user@example.com',
        'token': 'social-token-abc',
        'medium': 'google',
      };

      final model = SocialLogInBody.fromJson(json);

      expect(model.email, 'user@example.com');
      expect(model.token, 'social-token-abc');
      expect(model.medium, 'google');
      expect(model.uniqueId, isNull);
      expect(model.phone, isNull);
      expect(model.deviceToken, isNull);
      expect(model.accessToken, isNull);
      expect(model.loginType, isNull);
      expect(model.verified, isNull);
      expect(model.guestId, isNull);
      expect(model.platform, isNull);
    });

    test('toJson should serialize base fields always', () {
      final model = SocialLogInBody(
        email: 'user@example.com',
        token: 'social-token-abc',
        uniqueId: 'unique-123',
        medium: 'google',
      );

      final json = model.toJson();

      expect(json['email'], 'user@example.com');
      expect(json['token'], 'social-token-abc');
      expect(json['unique_id'], 'unique-123');
      expect(json['medium'], 'google');
    });

    test('toJson should omit null optional fields', () {
      final model = SocialLogInBody(
        email: 'user@example.com',
        token: 'social-token-abc',
        medium: 'google',
      );

      final json = model.toJson();

      // accessToken is null -> should not be in json
      expect(json.containsKey('access_token'), false);
      // verified is null -> should not be in json
      expect(json.containsKey('verified'), false);
      // guestId is null -> should not be in json
      expect(json.containsKey('guest_id'), false);
      // platform is null -> should not be in json
      expect(json.containsKey('platform'), false);
    });

    test('toJson should include non-null optional fields', () {
      final model = SocialLogInBody(
        email: 'user@example.com',
        token: 'social-token-abc',
        medium: 'google',
        accessToken: 12345,
        verified: '1',
        guestId: 'guest-abc',
        platform: 'ios',
      );

      final json = model.toJson();

      expect(json['access_token'], 12345);
      expect(json['verified'], '1');
      expect(json['guest_id'], 'guest-abc');
      expect(json['platform'], 'ios');
    });

    test('roundtrip fromJson -> toJson should preserve base data', () {
      final original = SocialLogInBody(
        email: 'user@example.com',
        token: 'social-token-abc',
        uniqueId: 'unique-123',
        medium: 'google',
        loginType: 'social',
      );

      final json = original.toJson();
      final restored = SocialLogInBody.fromJson(json);

      expect(restored.email, original.email);
      expect(restored.token, original.token);
      expect(restored.uniqueId, original.uniqueId);
      expect(restored.medium, original.medium);
      expect(restored.loginType, original.loginType);
    });
  });
}