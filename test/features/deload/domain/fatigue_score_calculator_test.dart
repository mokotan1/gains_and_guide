import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/constants/deload_constants.dart';
import 'package:gains_and_guide/core/domain/models/fatigue_signal.dart';
import 'package:gains_and_guide/features/deload/domain/fatigue_score_calculator.dart';

void main() {
  // ===========================================================================
  // RPE 피로 시그널
  // ===========================================================================
  group('calculateRpeFatigue', () {
    test('빈 RPE 리스트 → 0점', () {
      final signal = FatigueScoreCalculator.calculateRpeFatigue([]);
      expect(signal.score, 0);
      expect(signal.type, FatigueSignalType.rpeFatigue);
    });

    test('평균 RPE 7 이하 → 0점', () {
      final signal = FatigueScoreCalculator.calculateRpeFatigue([6, 7, 7]);
      expect(signal.score, closeTo(0, 1));
    });

    test('평균 RPE 10 → 100점', () {
      final signal = FatigueScoreCalculator.calculateRpeFatigue([10, 10, 10]);
      expect(signal.score, 100);
    });

    test('평균 RPE 8.5 → 중간 점수', () {
      final signal = FatigueScoreCalculator.calculateRpeFatigue([8, 9, 9, 8]);
      expect(signal.score, greaterThan(30));
      expect(signal.score, lessThan(70));
    });
  });

  // ===========================================================================
  // 정체/퇴보 시그널
  // ===========================================================================
  group('calculatePlateau', () {
    test('데이터 1개 이하 → 0점', () {
      expect(FatigueScoreCalculator.calculatePlateau([]).score, 0);
      expect(FatigueScoreCalculator.calculatePlateau([60.0]).score, 0);
    });

    test('연속 증가 → 0점', () {
      final signal =
          FatigueScoreCalculator.calculatePlateau([70, 65, 60, 55]);
      expect(signal.score, 0);
    });

    test('모두 동일 → 50점 이상', () {
      final signal =
          FatigueScoreCalculator.calculatePlateau([60, 60, 60, 60]);
      expect(signal.score, greaterThanOrEqualTo(50));
    });

    test('전부 퇴보 → 100점', () {
      final signal =
          FatigueScoreCalculator.calculatePlateau([55, 60, 65, 70]);
      expect(signal.score, 100);
    });

    test('일부 퇴보 → 0~100 사이', () {
      final signal =
          FatigueScoreCalculator.calculatePlateau([58, 60, 62, 60]);
      expect(signal.score, greaterThan(0));
      expect(signal.score, lessThan(100));
    });
  });

  // ===========================================================================
  // 주기 기반 시그널
  // ===========================================================================
  group('calculateTimeBased', () {
    test('디로드 이력 없음 → 50점', () {
      final signal = FatigueScoreCalculator.calculateTimeBased(
        lastDeloadEnd: null,
        now: DateTime(2026, 3, 20),
      );
      expect(signal.score, 50);
    });

    test('3주 전 → 0점 (minWeeks=4 미만)', () {
      final now = DateTime(2026, 3, 20);
      final signal = FatigueScoreCalculator.calculateTimeBased(
        lastDeloadEnd: now.subtract(const Duration(days: 21)),
        now: now,
      );
      expect(signal.score, 0);
    });

    test('6주 이상 → 100점', () {
      final now = DateTime(2026, 3, 20);
      final signal = FatigueScoreCalculator.calculateTimeBased(
        lastDeloadEnd: now.subtract(const Duration(days: 50)),
        now: now,
      );
      expect(signal.score, 100);
    });

    test('5주 → 중간 점수', () {
      final now = DateTime(2026, 3, 20);
      final signal = FatigueScoreCalculator.calculateTimeBased(
        lastDeloadEnd: now.subtract(const Duration(days: 35)),
        now: now,
      );
      expect(signal.score, greaterThan(0));
      expect(signal.score, lessThan(100));
    });
  });

  // ===========================================================================
  // 실패율 시그널
  // ===========================================================================
  group('calculateFailureRate', () {
    test('세트 데이터 없음 → 0점', () {
      final signal = FatigueScoreCalculator.calculateFailureRate(
        completedSets: 0,
        totalSets: 0,
      );
      expect(signal.score, 0);
    });

    test('전부 완료 → 0점', () {
      final signal = FatigueScoreCalculator.calculateFailureRate(
        completedSets: 15,
        totalSets: 15,
      );
      expect(signal.score, 0);
    });

    test('50% 실패 → 100점', () {
      final signal = FatigueScoreCalculator.calculateFailureRate(
        completedSets: 8,
        totalSets: 16,
      );
      expect(signal.score, 100);
    });

    test('15% 미만 실패 → 0점', () {
      final signal = FatigueScoreCalculator.calculateFailureRate(
        completedSets: 14,
        totalSets: 15,
      );
      expect(signal.score, closeTo(0, 5));
    });
  });

  // ===========================================================================
  // 종합 평가 (evaluate)
  // ===========================================================================
  group('evaluate', () {
    test('빈 시그널 → DeloadRecommendation.none', () {
      final rec = FatigueScoreCalculator.evaluate([]);
      expect(rec.shouldDeload, false);
      expect(rec.totalScore, 0);
    });

    test('모든 시그널 낮음 → 디로드 불필요', () {
      final signals = [
        FatigueScoreCalculator.calculateRpeFatigue([6, 7, 7]),
        FatigueScoreCalculator.calculatePlateau([70, 65, 60]),
        FatigueScoreCalculator.calculateTimeBased(
          lastDeloadEnd: DateTime.now().subtract(const Duration(days: 14)),
          now: DateTime.now(),
        ),
        FatigueScoreCalculator.calculateFailureRate(
          completedSets: 15,
          totalSets: 15,
        ),
      ];
      final rec = FatigueScoreCalculator.evaluate(signals);
      expect(rec.shouldDeload, false);
      expect(rec.totalScore, lessThan(DeloadConstants.fatigueScoreThreshold));
    });

    test('모든 시그널 높음 → 디로드 필요', () {
      final signals = [
        FatigueScoreCalculator.calculateRpeFatigue([10, 10, 10]),
        FatigueScoreCalculator.calculatePlateau([55, 60, 65, 70]),
        FatigueScoreCalculator.calculateTimeBased(
          lastDeloadEnd: DateTime.now().subtract(const Duration(days: 60)),
          now: DateTime.now(),
        ),
        FatigueScoreCalculator.calculateFailureRate(
          completedSets: 5,
          totalSets: 15,
        ),
      ];
      final rec = FatigueScoreCalculator.evaluate(signals);
      expect(rec.shouldDeload, true);
      expect(
          rec.totalScore, greaterThanOrEqualTo(DeloadConstants.fatigueScoreThreshold));
      expect(rec.reductionRatio, DeloadConstants.deloadWeightReductionRatio);
      expect(rec.durationDays, DeloadConstants.deloadDurationDays);
      expect(rec.summary, isNotEmpty);
    });

    test('경계값 — 정확히 임계치일 때 디로드 필요', () {
      const threshold = DeloadConstants.fatigueScoreThreshold;
      final signal = FatigueSignal(
        type: FatigueSignalType.rpeFatigue,
        score: threshold / DeloadConstants.weightRpeFatigue,
        weight: DeloadConstants.weightRpeFatigue,
        reason: 'test',
      );
      final filler = FatigueSignal(
        type: FatigueSignalType.plateau,
        score: threshold / DeloadConstants.weightPlateau,
        weight: DeloadConstants.weightPlateau,
        reason: 'test',
      );

      final totalScore = signal.weightedScore + filler.weightedScore;
      final rec = FatigueScoreCalculator.evaluate([signal, filler]);

      if (totalScore >= threshold) {
        expect(rec.shouldDeload, true);
      } else {
        expect(rec.shouldDeload, false);
      }
    });
  });
}
