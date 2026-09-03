import 'package:flutter_test/flutter_test.dart';
import 'package:pickles_and_pies/features/order/domain/repositories/order_repository_interface.dart';
import 'package:pickles_and_pies/features/order/domain/services/order_service.dart';

class _FakeRepo implements OrderRepositoryInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('classifyPaymentUrl accepts canonical payment-success', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/payment-success'),
      equals('success'),
    );
  });

  test('classifyPaymentUrl accepts canonical payment-fail', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/payment-fail'),
      equals('fail'),
    );
  });

  test('classifyPaymentUrl accepts canonical payment-cancel', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/payment-cancel'),
      equals('cancel'),
    );
  });

  test('classifyPaymentUrl accepts subscription variants', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/subscription-success'),
      equals('success'),
    );
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/subscription-fail'),
      equals('fail'),
    );
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/subscription-cancel'),
      equals('cancel'),
    );
  });

  test('classifyPaymentUrl accepts canonical URL with informational token', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl(
        'https://admin.ppdeli.com/payment-success?token=YWJjMTIz',
      ),
      equals('success'),
    );
  });

  test('classifyPaymentUrl rejects malicious host', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('https://evil.com/payment-success'),
      isNull,
    );
    expect(
      svc.classifyPaymentUrl(
        'https://admin.ppdeli.com.evil.com/payment-success',
      ),
      isNull,
    );
  });

  test('classifyPaymentUrl rejects path-prefix bypass attempts', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl(
        'https://admin.ppdeli.com/payment-success-malicious',
      ),
      isNull,
    );
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/payment-successx'),
      isNull,
    );
  });

  test('classifyPaymentUrl rejects non-https schemes', () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('http://ppdeli.com/payment-success'),
      isNull,
    );
    expect(
      svc.classifyPaymentUrl('pickles://payment/success'),
      isNull,
    );
  });

  test('classifyPaymentUrl rejects intermediate URLs (Stripe / 3DS / assets)',
      () {
    final svc = OrderService(orderRepositoryInterface: _FakeRepo() as dynamic);
    expect(
      svc.classifyPaymentUrl('https://checkout.stripe.com/c/pay/cs_test_123'),
      isNull,
    );
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/payment-mobile'),
      isNull,
    );
    expect(
      svc.classifyPaymentUrl('https://admin.ppdeli.com/api/v1/something'),
      isNull,
    );
    expect(svc.classifyPaymentUrl(null), isNull);
    expect(svc.classifyPaymentUrl(''), isNull);
  });
}


