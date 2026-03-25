import 'package:bdnewsreader/core/errors/security_exception.dart';
import 'package:bdnewsreader/core/security/certificate_pinner.dart';
import 'package:bdnewsreader/core/security/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SSLPinning.debugReset);
  tearDown(SSLPinning.debugReset);

  test('startup fails in release when a required pin is missing', () {
    expect(
      () => CertificatePinner.validateConfiguration(enforceRelease: true),
      throwsA(isA<SecurityException>()),
    );
  });

  test('secure client cannot be created before pin init', () {
    expect(
      () => SSLPinning.getHttpClientFor(Uri.parse('https://newsdata.io')),
      throwsA(isA<SecurityException>()),
    );
  });

  test('strict client does not rely on the default trusted roots', () async {
    await SSLPinning.initialize();

    expect(SSLPinning.debugUsesDefaultTrustedRoots, isFalse);
  });
}
