import 'package:bdnewsreader/core/security/certificate_pinner.dart';
import 'package:bdnewsreader/core/security/ssl_pinning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(SSLPinning.debugReset);
  tearDown(SSLPinning.debugReset);

  test('startup succeeds in release when pins are present', () {
    expect(
      () => CertificatePinner.validateConfiguration(enforceRelease: true),
      returnsNormally,
    );
  });

  test('secure client lazily initializes strict pin context', () {
    final client = SSLPinning.getHttpClientFor(
      Uri.parse('https://newsdata.io'),
    );

    expect(client, isNotNull);
    expect(SSLPinning.debugUsesDefaultTrustedRoots, isFalse);
  });

  test('strict client does not rely on the default trusted roots', () async {
    await SSLPinning.initialize();

    expect(SSLPinning.debugUsesDefaultTrustedRoots, isFalse);
  });
}
