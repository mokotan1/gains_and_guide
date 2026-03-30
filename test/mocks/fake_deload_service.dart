import 'package:gains_and_guide/core/domain/models/deload_recommendation.dart';
import 'package:gains_and_guide/core/domain/repositories/deload_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/progression_repository.dart';
import 'package:gains_and_guide/core/domain/repositories/workout_history_repository.dart';
import 'package:gains_and_guide/features/deload/application/deload_service.dart';
import 'package:gains_and_guide/features/routine/domain/exercise.dart';

/// [DeloadService] 의 테스트용 Fake.
///
/// 디로드 평가 결과를 테스트에서 직접 제어할 수 있다.
class FakeDeloadService extends DeloadService {
  DeloadRecommendation? activeRecommendation;
  DeloadRecommendation nextEvaluationResult = const DeloadRecommendation.none();
  bool deloadSessionCompleted = false;

  /// DB의 remaining_sessions 와 유사. 0이면 활성 디로드 없음.
  /// [getActiveDeloadRecommendation] / [isCurrentlyInDeload]에 반영된다.
  int simulatedRemainingSessions = 0;

  FakeDeloadService()
      : super(
          _NoopHistoryRepo(),
          _NoopProgressionRepo(),
          _NoopDeloadRepo(),
        );

  @override
  Future<bool> isCurrentlyInDeload() async =>
      simulatedRemainingSessions > 0;

  @override
  Future<DeloadRecommendation?> getActiveDeloadRecommendation() async {
    if (simulatedRemainingSessions <= 0) return null;
    return activeRecommendation;
  }

  @override
  Future<DeloadRecommendation> evaluateDeloadNeed(
    List<Exercise> exercises,
  ) async =>
      nextEvaluationResult;

  @override
  List<Exercise> applyDeload(
    List<Exercise> exercises,
    DeloadRecommendation rec,
  ) {
    if (!rec.shouldDeload) return exercises;
    return exercises.map((ex) {
      if (ex.isCardio || ex.isBodyweight) return ex;
      final reduced = (ex.weight * rec.reductionRatio).roundToDouble();
      return ex.copyWith(
        weight: reduced,
        setWeights: List.filled(ex.sets, reduced),
      );
    }).toList();
  }

  @override
  Future<void> recordDeload(DeloadRecommendation rec) async {}

  @override
  Future<void> completeDeloadSession() async {
    deloadSessionCompleted = true;
    if (simulatedRemainingSessions > 0) {
      simulatedRemainingSessions--;
    }
  }
}

class _NoopHistoryRepo implements WorkoutHistoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopProgressionRepo implements ProgressionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoopDeloadRepo implements DeloadRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
