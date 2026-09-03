import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/common/models/response_model.dart';

void main() {
  group('ResponseModel', () {
    test('should construct with success status and message', () {
      final model = ResponseModel(true, 'login_successful');

      expect(model.isSuccess, true);
      expect(model.message, 'login_successful');
      expect(model.zoneIds, isNull);
      expect(model.statusCode, isNull);
    });

    test('should construct with failure status and message', () {
      final model = ResponseModel(false, 'invalid_credentials');

      expect(model.isSuccess, false);
      expect(model.message, 'invalid_credentials');
    });

    test('should expose zoneIds when provided', () {
      final model = ResponseModel(
        true,
        'ok',
        zoneIds: [1, 2, 3],
        statusCode: 200,
      );

      expect(model.zoneIds, [1, 2, 3]);
      expect(model.statusCode, 200);
    });

    test('should allow null message', () {
      final model = ResponseModel(true, null);

      expect(model.isSuccess, true);
      expect(model.message, isNull);
    });

    test('isSuccess getter should return the stored value', () {
      final successModel = ResponseModel(true, 'ok');
      final failureModel = ResponseModel(false, 'error');

      expect(successModel.isSuccess, true);
      expect(failureModel.isSuccess, false);
    });
  });
}