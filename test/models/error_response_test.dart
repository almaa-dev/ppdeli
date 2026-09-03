import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/common/models/error_response.dart';

void main() {
  group('ErrorResponse', () {
    test('fromJson should parse errors list correctly', () {
      final json = {
        'errors': [
          {'code': 'validation.required', 'message': 'Field is required'},
          {'code': 'auth.failed', 'message': 'Invalid credentials'},
        ],
      };

      final response = ErrorResponse.fromJson(json);

      expect(response.errors, isNotNull);
      expect(response.errors!.length, 2);
      expect(response.errors![0].code, 'validation.required');
      expect(response.errors![0].message, 'Field is required');
      expect(response.errors![1].code, 'auth.failed');
      expect(response.errors![1].message, 'Invalid credentials');
    });

    test('fromJson should handle null errors field', () {
      final response = ErrorResponse.fromJson({});

      expect(response.errors, isNull);
    });

    test('fromJson should handle missing errors field', () {
      final response = ErrorResponse.fromJson({'foo': 'bar'});

      expect(response.errors, isNull);
    });

    test('toJson should serialize errors correctly', () {
      final response = ErrorResponse(
        errors: [
          Errors(code: 'error1', message: 'message1'),
        ],
      );

      final json = response.toJson();

      expect(json['errors'], isA<List>());
      expect((json['errors'] as List).length, 1);
      expect((json['errors'] as List)[0]['code'], 'error1');
      expect((json['errors'] as List)[0]['message'], 'message1');
    });

    test('toJson should not include errors when null', () {
      final response = ErrorResponse();
      final json = response.toJson();

      expect(json.containsKey('errors'), false);
    });
  });

  group('Errors', () {
    test('fromJson should parse code and message', () {
      final json = {'code': 'auth.failed', 'message': 'Login failed'};

      final error = Errors.fromJson(json);

      expect(error.code, 'auth.failed');
      expect(error.message, 'Login failed');
    });

    test('fromJson should handle empty json', () {
      final error = Errors.fromJson({});

      expect(error.code, isNull);
      expect(error.message, isNull);
    });

    test('toJson should serialize code and message', () {
      final error = Errors(code: 'auth.failed', message: 'Login failed');

      final json = error.toJson();

      expect(json['code'], 'auth.failed');
      expect(json['message'], 'Login failed');
    });
  });
}