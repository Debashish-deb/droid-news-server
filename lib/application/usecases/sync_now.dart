import '../../core/architecture/either.dart';
import '../../core/architecture/failure.dart';
import '../../domain/repositories/sync_repository.dart';
import 'usecase.dart';

// Command to trigger an immediate background synchronization.
class SyncNowUseCase implements UseCase<void, NoParams> {

  SyncNowUseCase(this._repository);
  final SyncRepository _repository;

  @override
  Future<Either<AppFailure, void>> call(NoParams params) async {
    return _repository.syncNow();
  }
}
