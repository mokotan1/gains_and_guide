import '../../../core/constants/report_constants.dart';
import 'models/report_section.dart';
import 'models/weekly_metrics.dart';
import 'models/weekly_report.dart';

/// [WeeklyMetrics] 로부터 규칙 기반 [WeeklyReport] 를 생성하는 순수 함수 집합.
///
/// 외부 의존 없이 메트릭스만으로 4개 섹션(Headline, Performance, Warning, ActionItem)을
/// 결정론적으로 생성한다. AI 보강 텍스트는 서비스 레이어에서 별도 병합한다.
class WeeklyReportGenerator {
  WeeklyReportGenerator._();

  /// 메트릭스를 기반으로 주간 레포트를 생성한다.
  static WeeklyReport generate(WeeklyMetrics metrics) {
    final headline = _buildHeadline(metrics);
    final performances = _buildPerformances(metrics);
    final warnings = _buildWarnings(metrics);
    final actionItems = _buildActionItems(metrics, warnings);

    return WeeklyReport(
      weekStart: metrics.weekStart,
      weekEnd: metrics.weekEnd,
      headline: headline,
      performances: performances,
      warnings: warnings,
      actionItems: actionItems,
      metrics: metrics,
      generatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Headline
  // ---------------------------------------------------------------------------

  static ReportHeadline _buildHeadline(WeeklyMetrics metrics) {
    if (metrics.totalSessions == 0 && metrics.totalCardioSessions == 0) {
      return const ReportHeadline(
        text: '이번 주는 운동 기록이 없습니다. 다음 주에 다시 시작해봐요!',
        severity: InsightSeverity.neutral,
      );
    }

    if (metrics.totalSessions == 0 && metrics.totalCardioSessions > 0) {
      if (metrics.cardioAcwr > ReportConstants.cardioAcwrDangerMax) {
        return const ReportHeadline(
          text: '유산소 부하가 과도할 수 있습니다. 회복과 강도를 점검해보세요.',
          severity: InsightSeverity.critical,
        );
      }
      if (metrics.totalCardioMinutes >=
          ReportConstants.whoWeeklyModerateCardioMinutes) {
        return const ReportHeadline(
          text: '유산소 위주로 꾸준히 움직인 한 주였습니다!',
          severity: InsightSeverity.positive,
        );
      }
      return const ReportHeadline(
        text: '유산소 훈련을 이어가고 있습니다. 필요하면 시간을 조금씩 늘려보세요.',
        severity: InsightSeverity.neutral,
      );
    }

    if (metrics.acwr > ReportConstants.acwrDangerMax) {
      return const ReportHeadline(
        text: '오버트레이닝 위험! 즉시 볼륨 조절이 필요합니다.',
        severity: InsightSeverity.critical,
      );
    }

    if (metrics.acwr > ReportConstants.acwrSweetSpotMax) {
      return const ReportHeadline(
        text: '성장은 좋으나 피로 관리가 필요한 한 주였습니다.',
        severity: InsightSeverity.warning,
      );
    }

    final volumeGrowth = metrics.volumeChangePercent;
    if (volumeGrowth != null &&
        volumeGrowth >= ReportConstants.significantVolumeGrowthPercent) {
      return const ReportHeadline(
        text: '꾸준한 성장세를 이어가고 있습니다!',
        severity: InsightSeverity.positive,
      );
    }

    if (metrics.acwr > 0 && metrics.acwr < ReportConstants.acwrUndertraining) {
      return const ReportHeadline(
        text: '훈련 볼륨이 평소보다 낮았습니다. 컨디션을 점검해보세요.',
        severity: InsightSeverity.neutral,
      );
    }

    return const ReportHeadline(
      text: '안정적으로 훈련을 유지한 한 주였습니다.',
      severity: InsightSeverity.positive,
    );
  }

  // ---------------------------------------------------------------------------
  // Performance (Praise)
  // ---------------------------------------------------------------------------

  static List<PerformanceInsight> _buildPerformances(WeeklyMetrics metrics) {
    final results = <PerformanceInsight>[];

    // 1RM 증가 감지
    for (final entry in metrics.estimated1RMs.entries) {
      final est = entry.value;
      final delta = est.deltaKg;
      if (delta != null && delta > 0) {
        results.add(PerformanceInsight(
          title: '${est.exerciseName} 1RM 증가',
          description:
              '예상 1RM이 ${est.previous1RM!.toStringAsFixed(1)}kg → '
              '${est.current1RM.toStringAsFixed(1)}kg으로 '
              '${delta.toStringAsFixed(1)}kg 증가했습니다.',
        ));
      }
    }

    // 볼륨 성장
    final volumeGrowth = metrics.volumeChangePercent;
    if (volumeGrowth != null &&
        volumeGrowth >= ReportConstants.significantVolumeGrowthPercent) {
      results.add(PerformanceInsight(
        title: '전체 볼륨 성장',
        description: '총 볼륨이 지난 주 대비 '
            '${volumeGrowth.toStringAsFixed(1)}% 증가했습니다. '
            '(${metrics.prevWeekVolume!.toStringAsFixed(0)}kg → '
            '${metrics.totalVolume.toStringAsFixed(0)}kg)',
      ));
    }

    // 훈련 일관성
    if (metrics.totalSessions >= 3) {
      results.add(PerformanceInsight(
        title: '훈련 일관성',
        description:
            '이번 주 ${metrics.totalSessions}회 훈련을 완수했습니다.',
        severity: InsightSeverity.positive,
      ));
    }

    // WHO 권장 주간 중강도 유산소 (150분)
    if (metrics.totalCardioMinutes >=
        ReportConstants.whoWeeklyModerateCardioMinutes) {
      results.add(PerformanceInsight(
        title: '심혈관 건강의 정석',
        description:
            '이번 주 유산소 운동 ${metrics.totalCardioMinutes.toStringAsFixed(0)}분을 달성하여 '
            '주간 권장량(${ReportConstants.whoWeeklyModerateCardioMinutes.toStringAsFixed(0)}분)을 채웠습니다!',
        severity: InsightSeverity.positive,
      ));
    }

    // 무게 증가 운동
    for (final delta in metrics.exerciseDeltas) {
      final kg = delta.deltaKg;
      if (kg != null && kg > 0) {
        results.add(PerformanceInsight(
          title: '${delta.exerciseName} 무게 증가',
          description:
              '최대 무게가 ${delta.lastWeekMaxWeight!.toStringAsFixed(1)}kg → '
              '${delta.thisWeekMaxWeight.toStringAsFixed(1)}kg으로 '
              '${kg.toStringAsFixed(1)}kg 올랐습니다.',
        ));
      }
    }

    return results;
  }

  // ---------------------------------------------------------------------------
  // Warning
  // ---------------------------------------------------------------------------

  static List<WarningInsight> _buildWarnings(WeeklyMetrics metrics) {
    final results = <WarningInsight>[];

    // ACWR 위험
    if (metrics.acwr > ReportConstants.acwrSweetSpotMax) {
      final severity = metrics.acwr > ReportConstants.acwrDangerMax
          ? InsightSeverity.critical
          : InsightSeverity.warning;
      results.add(WarningInsight(
        title: 'ACWR 과부하 경고',
        description:
            'ACWR ${metrics.acwr.toStringAsFixed(2)}로 '
            '안전 범위(${ReportConstants.acwrSweetSpotMax} 이하)를 초과했습니다. '
            '오버트레이닝 위험이 있습니다.',
        severity: severity,
        metricValue: metrics.acwr,
        threshold: ReportConstants.acwrSweetSpotMax,
      ));
    }

    // 높은 평균 RPE
    if (metrics.avgRpe >= ReportConstants.highRpeThreshold) {
      results.add(WarningInsight(
        title: '높은 평균 RPE',
        description:
            '주간 평균 RPE가 ${metrics.avgRpe.toStringAsFixed(1)}로 높습니다. '
            '피로 누적에 주의하세요.',
        severity: InsightSeverity.warning,
        metricValue: metrics.avgRpe,
        threshold: ReportConstants.highRpeThreshold,
      ));
    }

    // 높은 실패율
    if (metrics.failureRate >= ReportConstants.highFailureRateThreshold) {
      final pct = (metrics.failureRate * 100).toStringAsFixed(0);
      results.add(WarningInsight(
        title: '높은 세트 실패율',
        description: '세트 실패율이 $pct%입니다. '
            '무게를 낮추거나 볼륨을 조절해보세요.',
        severity: InsightSeverity.warning,
        metricValue: metrics.failureRate,
        threshold: ReportConstants.highFailureRateThreshold,
      ));
    }

    // 근육군 불균형
    _detectMuscleImbalance(metrics).forEach(results.add);

    // 유산소 ACWR 과부하 (웨이트 ACWR과 분리)
    if (metrics.cardioAcwr > ReportConstants.cardioAcwrSweetSpotMax) {
      final severity = metrics.cardioAcwr > ReportConstants.cardioAcwrDangerMax
          ? InsightSeverity.critical
          : InsightSeverity.warning;
      results.add(WarningInsight(
        title: '유산소 부하 ACWR 경고',
        description:
            '유산소 급성 부하 대비 만성 평균 비율이 '
            '${metrics.cardioAcwr.toStringAsFixed(2)}로 '
            '권장 상한(${ReportConstants.cardioAcwrSweetSpotMax})을 넘었습니다. '
            '전체 피로·회복을 점검하세요.',
        severity: severity,
        metricValue: metrics.cardioAcwr,
        threshold: ReportConstants.cardioAcwrSweetSpotMax,
      ));
    }

    return results;
  }

  static List<WarningInsight> _detectMuscleImbalance(WeeklyMetrics metrics) {
    final volumes = metrics.volumeByMuscle;
    if (volumes.length < 2) return [];

    final maxVolume = volumes.values
        .reduce((a, b) => a > b ? a : b);
    if (maxVolume < ReportConstants.muscleVolumeNoiseFloor) return [];

    final threshold = maxVolume * ReportConstants.muscleImbalanceThreshold;
    final results = <WarningInsight>[];

    for (final entry in volumes.entries) {
      if (entry.key == 'other') continue;
      if (entry.value < threshold && entry.value > 0) {
        final ratio = (entry.value / maxVolume * 100).toStringAsFixed(0);
        results.add(WarningInsight(
          title: '${entry.key} 볼륨 부족',
          description:
              '${entry.key} 운동 볼륨이 최대 근육군 대비 $ratio% 수준입니다. '
              '균형 있는 훈련을 위해 비중을 높여보세요.',
          severity: InsightSeverity.warning,
          metricValue: entry.value,
          threshold: threshold,
        ));
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Action Items
  // ---------------------------------------------------------------------------

  static List<ActionItem> _buildActionItems(
    WeeklyMetrics metrics,
    List<WarningInsight> warnings,
  ) {
    final results = <ActionItem>[];
    int priority = 1;

    // ACWR 과부하 → 볼륨 감소 + RPE 조절 권장
    if (metrics.acwr > ReportConstants.acwrSweetSpotMax) {
      final reductionPct =
          ReportConstants.recommendedVolumeReductionPercent.toStringAsFixed(0);
      final targetRpe =
          ReportConstants.recommendedTargetRpe.toStringAsFixed(0);
      results.add(ActionItem(
        instruction:
            '다음 주는 총 볼륨을 $reductionPct% 줄이고, '
            'RPE $targetRpe 수준으로 강도를 낮추는 디로딩 주간을 권장합니다.',
        rationale:
            'ACWR ${metrics.acwr.toStringAsFixed(2)}로 과부하 상태이므로 '
            '부상 방지를 위해 단기 회복이 필요합니다.',
        priority: priority++,
      ));
    }

    // 근육군 불균형 → 비중 증가 권장
    final imbalanceWarnings =
        warnings.where((w) => w.title.contains('볼륨 부족')).toList();
    for (final w in imbalanceWarnings) {
      final muscleName = w.title.replaceAll(' 볼륨 부족', '');
      final boostPct =
          ReportConstants.recommendedMuscleBoostPercent.toStringAsFixed(0);
      results.add(ActionItem(
        instruction: '$muscleName 운동 비중을 $boostPct% 늘려보세요.',
        rationale: w.description,
        priority: priority++,
      ));
    }

    // 높은 실패율 → 무게 조절 권장
    if (metrics.failureRate >= ReportConstants.highFailureRateThreshold) {
      results.add(ActionItem(
        instruction: '현재 무게가 과도합니다. 주요 운동 무게를 5~10% 낮춰보세요.',
        rationale:
            '실패율 ${(metrics.failureRate * 100).toStringAsFixed(0)}%는 '
            '효율적인 근성장 범위를 벗어났습니다.',
        priority: priority++,
      ));
    }

    // 볼륨 부족 → 증가 권장
    if (metrics.acwr > 0 && metrics.acwr < ReportConstants.acwrUndertraining) {
      results.add(ActionItem(
        instruction: '다음 주는 훈련 빈도를 1회 늘리거나 세트 수를 추가해보세요.',
        rationale:
            'ACWR ${metrics.acwr.toStringAsFixed(2)}로 훈련 볼륨이 '
            '평소보다 낮아 자극이 부족할 수 있습니다.',
        priority: priority++,
      ));
    }

    // 유산소 과부하 → 강도·시간 조절
    if (metrics.cardioAcwr > ReportConstants.cardioAcwrSweetSpotMax) {
      results.add(ActionItem(
        instruction: '유산소는 시간이나 강도(RPE) 중 하나를 낮추고, 수면·영양으로 회복을 보강하세요.',
        rationale:
            '유산소 ACWR ${metrics.cardioAcwr.toStringAsFixed(2)}로 '
            '심폐 부하가 한동안의 평균보다 큽니다.',
        priority: priority++,
      ));
    }

    return results;
  }
}
