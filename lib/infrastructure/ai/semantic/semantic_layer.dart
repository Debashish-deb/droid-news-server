import '../../../core/architecture/either.dart';
import '../../../core/architecture/failure.dart';

/// Facade for Semantic Understanding operations.
/// 
/// implementations might use:
/// - Cloud API (OpenAI
/// - On-Device TFLite (BERT Mobile)
abstract class SemanticLayer {
  /// Generates a vector embedding for the given text.
  /// 
  /// Returns `List<double>` representing the 384-dim (MiniLM) or 768-dim (BERT) vector.
  Future<Either<AppFailure, List<double>>> getEmbedding(String text);

  /// Calculates cosine similarity between two vectors.
  double similarity(List<double> v1, List<double> v2);
}
