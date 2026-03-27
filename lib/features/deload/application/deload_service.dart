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

  /// DB에 remaining_sessions > 0인 레코드가 존재하는지 확인
  Future<bool> isCurrentlyInDeload() => _deloadRepo.isCurrentlyInDeload();

  /// 진행 중인 디로드의 reductionRatio를 포함한 DeloadRecommendation 반환.
  /// 활성 디로드가 없으면 null.
  Future<DeloadRecommendation?> getActiveDeloadRecommendation() async {
    final record = await _deloadRepo.getActiveDeloadRecord();
    if (record == null) return null;

    return DeloadRecommendation(
      shouldDeload: true,
      totalScore: (record['fatigue_score'] as num).toDouble(),
      signals: const [],
      reductionRatio: DeloadConstants.deloadWeightReductionRatio,
      cycleSessions: (record['remaining_sessions'] as num).toInt(),
      summary: (record['reason'] as String?) ?? '',
    );
  }

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

  /// 디로드 이력을 DB에 기록 (이미 진행 중인 디로드가 있으면 중복 삽입 방지)
  Future<void> recordDeload(DeloadRecommendation rec) async {
    final alreadyInDeload = await _deloadRepo.isCurrentlyInDeload();
    if (alreadyInDeload) return;

    final now = DateTime.now();
    await _deloadRepo.saveDeloadRecord(
      startDate: now,
      endDate: now,
      reason: rec.summary,
      fatigueScore: rec.totalScore,
      cycleSessions: rec.cycleSessions,
    );
  }

  /// 디로드 중 운동 1세션 완료 시 호출하여 남은 세션 차감
  Future<void> completeDeloadSession() async {
    await _deloadRepo.decrementDeloadSession();
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

  /// RPE 10 세트를 "실패"로 간주하여 실패율 산출
  /// 실패 = RPE 10 (세트 실패 시 RPE 10으로 자동 기록됨)
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

    int totalSets = rows.length;
    int failedSets = rows.where((r) => (r['rpe'] as int?) == 10).length;
    int successSets = totalSets - failedSets;

    return FatigueScoreCalculator.calculateFailureRate(
      completedSets: successSets,
      totalSets: totalSets,
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
