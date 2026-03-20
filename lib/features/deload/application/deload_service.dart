import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/deload_constants.dart';
import '../../../core/domain/models/deload_recommendation.dart';
import '../../../core/domain/models/fatigue_signal.dart';
import '../../../core/domain/repositories/deload_repository.dart';
import '../../../core/domain/repositories/progression_repository.dart';
import '../../../core/domain/repositories/workout_history_repository.dart';
import '../../../core/providers/repository_providers.dart';
import '../../routine/domain/exercise.dart';
import '../domain/fatigue_score_calculator.dart';

/// Repository 데이터를 수집 → FatigueScoreCalculator 에 전달 → 결과 반환
class DeloadService {
  final WorkoutHistoryRepository _historyRepo;
  final ProgressionRepository _progressionRepo;
  final DeloadRepository _deloadRepo;

  DeloadService(this._historyRepo, this._progressionRepo, this._deloadRepo);

  /// 현재 운동 목록을 기반으로 디로드 필요 여부를 종합 평가
  Future<DeloadRecommendation> evaluateDeloadNeed(
    List<Exercise> exercises,
  ) async {
    if (exercises.isEmpty) return const DeloadRecommendation.none();

    final isInDeload = await _deloadRepo.isCurrentlyInDeload();
    if (isInDeload) return const DeloadRecommendation.none();

    final signals = <FatigueSignal>[];

    signals.add(await _collectRpeSignal(exercises));
    signals.add(await _collectPlateauSignal(exercises));
    signals.add(await _collectTimeBasedSignal());
    signals.add(await _collectFailureSignal());

    return FatigueScoreCalculator.evaluate(signals);
  }

  /// 디로드 무게를 적용한 운동 리스트 반환
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

  /// 디로드 이력을 DB에 기록
  Future<void> recordDeload(DeloadRecommendation rec) async {
    final now = DateTime.now();
    await _deloadRepo.saveDeloadRecord(
      startDate: now,
      endDate: now.add(Duration(days: rec.durationDays)),
      reason: rec.summary,
      fatigueScore: rec.totalScore,
    );
  }

  // ---------------------------------------------------------------------------
  // Private signal collectors
  // ---------------------------------------------------------------------------

  Future<FatigueSignal> _collectRpeSignal(List<Exercise> exercises) async {
    final allRpes = <int>[];
    for (final ex in exercises) {
      if (ex.isCardio) continue;
      final rows = await _historyRepo.getRecentSessionsByExercise(
        ex.name,
        DeloadConstants.rpeLookbackSessions,
      );
      for (final row in rows) {
        final rpe = row['rpe'];
        if (rpe is int) allRpes.add(rpe);
      }
    }
    return FatigueScoreCalculator.calculateRpeFatigue(allRpes);
  }

  Future<FatigueSignal> _collectPlateauSignal(List<Exercise> exercises) async {
    double maxScore = 0;
    FatigueSignal? worst;

    for (final ex in exercises) {
      if (ex.isCardio || ex.isBodyweight) continue;
      final progressions = await _progressionRepo.getRecentProgressions(
        ex.name,
        DeloadConstants.plateauLookbackEntries,
      );
      if (progressions.length < 2) continue;

      final weights = progressions
          .map((r) => (r['weight'] as num).toDouble())
          .toList();
      final signal = FatigueScoreCalculator.calculatePlateau(weights);
      if (signal.score > maxScore) {
        maxScore = signal.score;
        worst = signal;
      }
    }

    return worst ??
        const FatigueSignal(
          type: FatigueSignalType.plateau,
          score: 0,
          weight: DeloadConstants.weightPlateau,
          reason: '프로그레션 데이터 부족',
        );
  }

  Future<FatigueSignal> _collectTimeBasedSignal() async {
    final lastEnd = await _deloadRepo.getLastDeloadEndDate();
    return FatigueScoreCalculator.calculateTimeBased(
      lastDeloadEnd: lastEnd,
      now: DateTime.now(),
    );
  }

  Future<FatigueSignal> _collectFailureSignal() async {
    final rows = await _historyRepo.getRecentSessions(
      DeloadConstants.failureLookbackSessions,
    );
    if (rows.isEmpty) {
      return FatigueScoreCalculator.calculateFailureRate(
        completedSets: 0,
        totalSets: 0,
      );
    }

    final sessionDates = rows
        .map((r) => (r['date'] as String).substring(0, 10))
        .toSet();

    int totalExpected = 0;
    int totalCompleted = rows.length;

    for (final date in sessionDates) {
      final dayRows = rows.where(
        (r) => (r['date'] as String).substring(0, 10) == date,
      );
      final exerciseNames = dayRows.map((r) => r['name'] as String).toSet();
      for (final name in exerciseNames) {
        final exRows =
            dayRows.where((r) => r['name'] == name).toList();
        final maxSet = exRows.fold<int>(
          0,
          (prev, r) => (r['sets'] as int) > prev ? (r['sets'] as int) : prev,
        );
        totalExpected += maxSet;
      }
    }

    if (totalExpected == 0) totalExpected = totalCompleted;

    return FatigueScoreCalculator.calculateFailureRate(
      completedSets: totalCompleted,
      totalSets: totalExpected,
    );
  }
}

final deloadServiceProvider = Provider<DeloadService>((ref) {
  return DeloadService(
    ref.watch(workoutHistoryRepositoryProvider),
    ref.watch(progressionRepositoryProvider),
    ref.watch(deloadRepositoryProvider),
  );
});
