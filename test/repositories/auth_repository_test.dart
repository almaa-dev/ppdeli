import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/api/api_client.dart';
import 'package:pickles_and_pies/common/models/response_model.dart';
import 'package:pickles_and_pies/features/auth/domain/models/signup_body_model.dart';
import 'package:pickles_and_pies/features/auth/domain/models/social_log_in_body.dart';
import 'package:pickles_and_pies/features/auth/domain/reposotories/auth_repository.dart';
import 'package:pickles_and_pies/util/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

/// A minimal fake of [ApiClient] that records the calls it receives and
/// returns the responses we configure. We avoid using `mockito`/`mocktail`
/// to keep the test suite dependency-free.
class _FakeApiClient extends ApiClient implements GetxService {
  _FakeApiClient({required super.sharedPreferences})
      : super(appBaseUrl: 'https://test.example.com');

  String? lastUri;
  dynamic lastBody;
  Response nextResponse = Response(statusCode: 200, body: const {});

  @override
  Future<Response> postData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
    int? timeout,
    bool handleError = true,
  }) async {
    lastUri = uri;
    lastBody = body;
    return nextResponse;
  }

  @override
  Future<Response> putData(
    String uri,
    dynamic body, {
    Map<String, String>? headers,
    bool handleError = true,
  }) async {
    lastUri = uri;
    lastBody = body;
    return nextResponse;
  }

  @override
  Future<Response> getData(
    String uri, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool handleError = true,
  }) async {
    lastUri = uri;
    lastBody = null;
    return nextResponse;
  }

  @override
  Future<Response> deleteData(
    String uri, {
    Map<String, String>? headers,
    bool handleError = true,
  }) async {
    lastUri = uri;
    lastBody = null;
    return nextResponse;
  }

  @override
  Map<String, String> updateHeader(
    String? token,
    List<int>? zoneIDs,
    List<int>? operationIds,
    String? languageCode,
    String? moduleID,
    String? latitude,
    String? longitude,
    int? zoneId, {
    bool setHeader = true,
    fromModule = false,
  }) {
    return <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  @override
  Map<String, String> getHeader() => <String, String>{};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakeApiClient apiClient;
  late AuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    apiClient = _FakeApiClient(sharedPreferences: prefs);
    repository = AuthRepository(apiClient: apiClient, sharedPreferences: prefs);
  });

  group('AuthRepository - login', () {
    test('login should call loginUri and return the API response', () async {
      apiClient.nextResponse = Response(
        statusCode: 200,
        body: {'token': 'auth-token-xyz'},
      );

      final result = await repository.login(
        emailOrPhone: 'user@example.com',
        password: 'Password123',
        loginType: 'email',
        fieldType: 'email',
      );

      expect(apiClient.lastUri, AppConstants.loginUri);
      expect(apiClient.lastBody['email_or_phone'], 'user@example.com');
      expect(apiClient.lastBody['password'], 'Password123');
      expect(apiClient.lastBody['login_type'], 'email');
      expect(apiClient.lastBody['field_type'], 'email');
      expect(result.statusCode, 200);
      expect(result.body['token'], 'auth-token-xyz');
    });

    test('login should attach guest_id when present', () async {
      await prefs.setString(AppConstants.guestId, 'guest-abc');

      apiClient.nextResponse = Response(
        statusCode: 200,
        body: {'token': 'auth-token-xyz'},
      );

      await repository.login(
        emailOrPhone: 'user@example.com',
        password: 'Password123',
        loginType: 'email',
        fieldType: 'email',
      );

      expect(apiClient.lastBody['guest_id'], 'guest-abc');
    });

    test('login should NOT attach guest_id when not present', () async {
      apiClient.nextResponse = Response(
        statusCode: 200,
        body: {'token': 'auth-token-xyz'},
      );

      await repository.login(
        emailOrPhone: 'user@example.com',
        password: 'Password123',
        loginType: 'email',
        fieldType: 'email',
      );

      expect(apiClient.lastBody.containsKey('guest_id'), false);
    });
  });

  group('AuthRepository - registration', () {
    test('registration should POST signup body to registerUri', () async {
      apiClient.nextResponse = Response(
        statusCode: 200,
        body: {'token': 'new-user-token'},
      );

      final body = SignUpBodyModel(
        fName: 'Ahmed',
        lName: 'Mohammed',
        phone: '+966500000000',
        email: 'ahmed@example.com',
        password: 'Password123',
      );

      final result = await repository.registration(body);

      expect(apiClient.lastUri, AppConstants.registerUri);
      expect(apiClient.lastBody['f_name'], 'Ahmed');
      expect(apiClient.lastBody['l_name'], 'Mohammed');
      expect(apiClient.lastBody['phone'], '+966500000000');
      expect(apiClient.lastBody['email'], 'ahmed@example.com');
      expect(result.body['token'], 'new-user-token');
    });
  });

  group('AuthRepository - OTP login', () {
    test('otpLogin should call loginUri with phone and optional otp', () async {
      apiClient.nextResponse = Response(
        statusCode: 200,
        body: {'token': 'otp-token'},
      );

      await repository.otpLogin(
        phone: '+966500000000',
        otp: '1234',
        loginType: 'phone',
        verified: '1',
      );

      expect(apiClient.lastUri, AppConstants.loginUri);
      expect(apiClient.lastBody['phone'], '+966500000000');
      expect(apiClient.lastBody['otp'], '1234');
      expect(apiClient.lastBody['verified'], '1');
      expect(apiClient.lastBody['login_type'], 'phone');
    });

    test('otpLogin should not include otp/verified when empty', () async {
      apiClient.nextResponse = Response(statusCode: 200, body: {'token': 'x'});

      await repository.otpLogin(
        phone: '+966500000000',
        otp: '',
        loginType: 'phone',
        verified: '',
      );

      expect(apiClient.lastBody.containsKey('otp'), false);
      expect(apiClient.lastBody.containsKey('verified'), false);
    });
  });

  group('AuthRepository - social login', () {
    test('loginWithSocialMedia should POST social body', () async {
      apiClient.nextResponse = Response(statusCode: 200, body: {'token': 'social-token'});

      final social = SocialLogInBody(
        email: 'user@example.com',
        token: 'social-token',
        uniqueId: 'unique-1',
        medium: 'google',
        loginType: 'social',
      );

      await repository.loginWithSocialMedia(social);

      expect(apiClient.lastUri, AppConstants.loginUri);
      expect(apiClient.lastBody['email'], 'user@example.com');
      expect(apiClient.lastBody['token'], 'social-token');
      expect(apiClient.lastBody['unique_id'], 'unique-1');
      expect(apiClient.lastBody['medium'], 'google');
    });
  });

  group('AuthRepository - save/load user credentials', () {
    test('saveUserNumberAndPassword should persist into SharedPreferences', () async {
      await repository.saveUserNumberAndPassword(
        '+966500000000',
        'Secret123',
        '+966',
      );

      expect(repository.getUserNumber(), '+966500000000');
      expect(repository.getUserPassword(), 'Secret123');
      expect(repository.getUserCountryCode(), '+966');
    });

    test('clearUserNumberAndPassword should remove all keys', () async {
      await repository.saveUserNumberAndPassword(
        '+966500000000',
        'Secret123',
        '+966',
      );

      await repository.clearUserNumberAndPassword();

      expect(repository.getUserNumber(), '');
      expect(repository.getUserPassword(), '');
      expect(repository.getUserCountryCode(), '');
    });

    test('saveOtpUserNumber / clearOtpUserNumber roundtrip', () async {
      await repository.saveOtpUserNumber('+966500000000', '+966');

      expect(repository.getOtpUserNumber(), '+966500000000');
      expect(repository.getOtpUserCountryCode(), '+966');

      await repository.clearOtpUserNumber();

      expect(repository.getOtpUserNumber(), '');
      expect(repository.getOtpUserCountryCode(), '');
    });
  });

  group('AuthRepository - token management', () {
    test('saveUserToken should write token to SharedPreferences', () async {
      await repository.saveUserToken('user-token-123');

      expect(repository.getUserToken(), 'user-token-123');
    });

    test('isLoggedIn should reflect token presence', () async {
      expect(repository.isLoggedIn(), false);

      await repository.saveUserToken('user-token-123');

      expect(repository.isLoggedIn(), true);
    });

    test('clearSharedData should remove token', () async {
      await repository.saveUserToken('user-token');
      await repository.saveSharedPrefGuestId('guest-id');

      apiClient.nextResponse = Response(statusCode: 200, body: {'guest_id': 'new-guest'});

      await repository.clearSharedData();

      expect(repository.getUserToken(), '');
    });
  });

  group('AuthRepository - guest login', () {
    test('guestLogin should return ResponseModel with success on 200', () async {
      apiClient.nextResponse = Response(
        statusCode: 200,
        body: {'guest_id': 'new-guest-id'},
      );

      final result = await repository.guestLogin();

      expect(result, isA<ResponseModel>());
      expect(result.isSuccess, true);
      expect(repository.getSharedPrefGuestId(), 'new-guest-id');
      expect(repository.isGuestLoggedIn(), true);
    });

    test('guestLogin should return ResponseModel with failure on error', () async {
      apiClient.nextResponse = Response(statusCode: 500, statusText: 'Server error');

      final result = await repository.guestLogin();

      expect(result.isSuccess, false);
    });
  });

  group('AuthRepository - update personal info', () {
    test('updatePersonalInfo should send only provided fields', () async {
      apiClient.nextResponse = Response(statusCode: 200, body: {'ok': true});

      await repository.updatePersonalInfo(
        name: 'Ahmed',
        phone: '+966500000000',
        loginType: 'phone',
        email: null,
        referCode: 'REF123',
      );

      expect(apiClient.lastUri, AppConstants.personalInformationUri);
      expect(apiClient.lastBody['name'], 'Ahmed');
      expect(apiClient.lastBody['phone'], '+966500000000');
      expect(apiClient.lastBody['login_type'], 'phone');
      expect(apiClient.lastBody['ref_code'], 'REF123');
      expect(apiClient.lastBody.containsKey('email'), false);
    });
  });

  group('AuthRepository - notification preferences', () {
    test('isSharedPrefNotificationActive should default to true when not set', () {
      expect(repository.isSharedPrefNotificationActive(), true);
    });

    test('setNotificationActive should persist boolean flag', () async {
      await repository.setNotificationActive(true);
      expect(repository.isSharedPrefNotificationActive(), true);

      await repository.setNotificationActive(false);
      expect(repository.isSharedPrefNotificationActive(), false);
    });
  });
}