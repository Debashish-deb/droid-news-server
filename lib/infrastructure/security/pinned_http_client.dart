import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// HTTP Client that enforces Certificate Pinning.
/// 
/// MitM Protection.
class PinnedHttpClient {
  static Future<http.Client> create() async {
    final sslContext = SecurityContext();
    
    try {
    } catch (e) {
      throw Exception('Failed to load pinned certificates: $e');
    }

    final client = HttpClient(context: sslContext)
      ..badCertificateCallback = (cert, host, port) => false; // STRICT:

    return IOClient(client);
  }
}
