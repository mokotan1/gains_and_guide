import 'dart:math';
import '../../../core/constants/deload_constants.dart';
import '../../../core/domain/models/deload_recommendation.dart';
import '../../../core/domain/models/fatigue_signal.dart';

/// 피로도 점수 산출 (순수 함수 — 외부 의존 없음, 테스트 용이)
class FatigueScoreCalculator {
  FatigueScoreCalculator._();

  /// 최근 세션들의 RPE 목록으로 피로 점수 산출 (0 ~ 100)
  ///
  /// 평균 RPE 7 이하 → 0점, 9 이상 → 75점, 10 → 100점 (선형 보간)
  static FatigueSignal calculateRpeFatigue(List<int> recentRpes) {
    if (recentRpes.isEmpty) {
      return const FatigueSignal(
        type: FatigueSignalType.rpeFatigue,
        score: 0,
        weight: DeloadConstants.weightRpeFatigue,
        reason: '분석할 RPE 데이터 없음',
      );
    }

    final avgRpe = recentRpes.reduce((a, b) => a + b) / recentRpes.length;
    final score = _linearInterpolate(
      value: avgRpe,
      low: DeloadConstants.rpeLowBaseline,
      high: 10.0,
    );

    return FatigueSignal(
      type: FatigueSignalType.rpeFatigue,
      score: score,
      weight: DeloadConstants.weightRpeFatigue,
      reason: '최근 ${recentRpes.length}세션 평균 RPE ${avgRpe.toStringAsFixed(1)}',
    );
  }

  /// 운동별 최근 무게 추이로 정체/퇴보 점수 산출 (0 ~ 100)
  ///
  /// [recentWeights] 는 **최신순** (index 0 = 가장 최근)
  /// - 모두 동일 → 50점
  /// - 연속 하락 → 100점
  /// - 증가 추세 → 0점
  static FatigueSignal calculatePlateau(List<double> recentWeights) {
    if (recentWeights.length < 2) {
      return const FatigueSignal(
        type: FatigueSignalType.plateau,
        score: 0,
        weight: DeloadConstants.weightPlateau,
        reason: '프로그레션 데이터 부족',
      );
    }

    int stagnantCount = 0;
    int regressionCount = 0;
    for (int i = 0; i < recentWeights.length - 1; i++) {
      final diff = recentWeights[i] - recentWeights[i + 1];
      if (diff.abs() < 0.01) {
        stagnantCount++;
      } else if (diff < 0) {
        regressionCount++;
      }
    }

    final totalPairs = recentWeights.length - 1;
    double score;
    String reason;

    if (regressionCount == totalPairs) {
      score = 100;
      reason = '${recentWeights.length}세션 연속 퇴보';
    } else if (stagnantCount == totalPairs) {
      score = 50.0 + (totalPairs / DeloadConstants.plateauLookbackEntries) * 25;
      score = min(score, 80);
      reason = '${recentWeights.length}세션 연속 정체';
    } else if (regressionCount > 0) {
      score = (regressionCount / totalPairs) * 80;
      reason = '최근 ${recentWeights.length}세션 중 $regressionCount회 퇴보';
    } else {
      score = (stagnantCount / totalPairs) * 40;
      reason = '최근 ${recentWeights.length}세션 중 $stagnantCount회 정체';
    }

    return FatigueSignal(
      type: FatigueSignalType.plateau,
      score: score.clamp(0, 100),
      weight: DeloadConstants.weightPlateau,
      reason: reason,
    );
  }

  /// 마지막 디로드 이후 경과 주수 기반 점수 (0 ~ 100)
  ///
  /// [minWeeks] 미만 → 0점, [maxWeeks] 이상 → 100점 (선형)
  static FatigueSignal calculateTimeBased({
    required DateTime? lastDeloadEnd,
    required DateTime now,
  }) {
    if (lastDeloadEnd == null) {
      return const FatigueSignal(
        type: FatigueSignalType.timeBased,
        score: 50,
        weight: DeloadConstants.weightTimeBased,
        reason: '디로드 이력 없음 (기본 50점)',
      );
    }

    final daysSince = now.difference(lastDeloadEnd).inDays;
    final weeksSince = daysSince / 7.0;

    final score = _linearInterpolate(
      value: weeksSince,
      low: DeloadConstants.minWeeksWithoutDeload.toDouble(),
      high: DeloadConstants.maxWeeksWithoutDeload.toDouble(),
    );

    return FatigueSignal(
      type: FatigueSignalType.timeBased,
      score: score,
      weight: DeloadConstants.weightTimeBased,
      reason: '마지막 디로드 후 ${weeksSince.toStringAsFixed(1)}주 경과',
    );
  }

  /// 미완료 세트 비율 기반 실패 점수 (0 ~ 100)
  ///
  /// [completedSets] / [totalSets] 에서 실패율을 계산
  static FatigueSignal calculateFailureRate({
    required int completedSets,
    required int totalSets,
  }) {
    if (totalSets <= 0) {
      return const FatigueSignal(
        type: FatigueSignalType.failureRate,
        score: 0,
        weight: DeloadConstants.weightFailureRate,
        reason: '분석할 세트 데이터 없음',
      );
    }

    final failureRate = 1.0 - (completedSets / totalSets);
    final score = _linearInterpolate(
      value: failureRate,
      low: DeloadConstants.failureRateLowBaseline,
      high: DeloadConstants.failureRateHighThreshold,
    );

    final pct = (failureRate * 100).toStringAsFixed(0);
    return FatigueSignal(
      type: FatigueSignalType.failureRate,
      score: score,
      weight: DeloadConstants.weightFailureRate,
      reason: '최근 세트 실패율 $pct% ($completedSets/$totalSets 완료)',
    );
  }

  /// 모든 시그널을 가중 합산하여 디로드 권고 생성
  static DeloadRecommendation evaluate(List<FatigueSignal> signals) {
    if (signals.isEmpty) return const DeloadRecommendation.none();

    final totalScore =
        signals.fold(0.0, (sum, s) => sum + s.weightedScore);

    final shouldDeload = totalScore >= DeloadConstants.fatigueScoreThreshold;

    final topReasons = (List<FatigueSignal>.from(signals)
          ..sort((a, b) => b.weightedScore.compareTo(a.weightedScore)))
        .take(2)
        .map((s) => s.reason)
        .join(', ');

    final summary = shouldDeload
        ? '피로도 ${totalScore.toStringAsFixed(0)}점 — $topReasons'
        : '';

    return DeloadRecommendation(
      shouldDeload: shouldDeload,
      totalScore: totalScore,
      signals: signals,
      reductionRatio: shouldDeload
          ? DeloadConstants.deloadWeightReductionRatio
          : 1.0,
      cycleSessions: shouldDeload ? DeloadConstants.defaultDeloadCycleSessions : 0,
      summary: summary,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// [low, high] 범위를 [0, 100]으로 선형 매핑. 범위 밖은 clamp.
  static double _linearInterpolate({
    required double value,
    required double low,
    required double high,
  }) {
    if (high <= low) return 0;
    return ((value - low) / (high - low) * 100).clamp(0, 100);
  }
}
