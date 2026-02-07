
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show XFile;
import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart' show AppFailure, OCRFailure;

/// Service responsible for OCR operations
abstract class OCRService {
  Future<Either<AppFailure, String>> extractTextFromImage(XFile image);
}

class OCRServiceImpl implements OCRService {
  @override
  Future<Either<AppFailure, String>> extractTextFromImage(XFile image) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return const Right("Extracted text from image...");
    } catch (e) {
      return const Left(OCRFailure());
    }
  }
}

final ocrServiceProvider = Provider<OCRService>((ref) => OCRServiceImpl());
