import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bdnewsreader/infrastructure/services/payment/payment_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

@GenerateMocks([InAppPurchase, FirebaseFirestore, CollectionReference, DocumentReference])
import 'payment_service_test.mocks.dart';

void main() {
  late PaymentService paymentService;
  late MockInAppPurchase mockIap;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;

  setUp(() {
    mockIap = MockInAppPurchase();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    
    when(mockFirestore.collection('payments')).thenReturn(mockCollection);
    
    paymentService = PaymentService(mockIap, firestore: mockFirestore);
  });

  test('processGooglePayPayment writes to Firestore', () async {
    // Arrange
    when(mockCollection.add(any)).thenAnswer((_) async => MockDocumentReference());

    await paymentService.processGooglePayPayment(
      psp: 'google_pay',
      total: 10.0,
      currency: 'USD',
      paymentToken: 'token_123',
      userId: 'user_456',
    );

    verify(mockCollection.add(argThat(predicate((dynamic map) {
      if (map is! Map<String, dynamic>) return false;
      return map['userId'] == 'user_456' &&
             map['total'] == 10.0 &&
             map['status'] == 'PENDING';
    })))).called(1);
  });
}
