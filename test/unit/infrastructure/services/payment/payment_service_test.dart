import 'package:bdnewsreader/infrastructure/services/payment/payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([InAppPurchase])
import 'payment_service_test.mocks.dart';

void main() {
  late PaymentService paymentService;
  late MockInAppPurchase mockIap;

  setUp(() {
    mockIap = MockInAppPurchase();
  });

  test('processGooglePayPayment delegates to backend processor', () async {
    Map<String, dynamic>? capturedPayload;
    paymentService = PaymentService(
      mockIap,
      googlePayProcessor: (payload) async {
        capturedPayload = payload;
        return <String, dynamic>{'success': true, 'status': 'processed'};
      },
    );

    await paymentService.processGooglePayPayment(
      psp: 'google_pay',
      total: 10.0,
      currency: 'USD',
      paymentToken: 'token_123',
      userId: 'user_456',
    );

    expect(capturedPayload, isNotNull);
    expect(capturedPayload!['userId'], 'user_456');
    expect(capturedPayload!['total'], 10.0);
    expect(capturedPayload!['paymentToken'], 'token_123');
  });
}
