/// 레포트 섹션의 심각도 수준
enum InsightSeverity { positive, neutral, warning, critical }

/// 한 줄 요약 (Headline)
class ReportHeadline {
  final String text;
  final InsightSeverity severity;

  const ReportHeadline({required this.text, required this.severity});

  Map<String, dynamic> toJson() => {
        'text': text,
        'severity': severity.name,
      };

  factory ReportHeadline.fromJson(Map<String, dynamic> json) {
    return ReportHeadline(
      text: json['text'] as String,
      severity: InsightSeverity.values.byName(json['severity'] as String),
    );
  }
}

/// 퍼포먼스 리뷰 (Praise) 섹션의 개별 인사이트
class PerformanceInsight {
  final String title;
  final String description;
  final InsightSeverity severity;

  const PerformanceInsight({
    required this.title,
    required this.description,
    this.severity = InsightSeverity.positive,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'severity': severity.name,
      };

  factory PerformanceInsight.fromJson(Map<String, dynamic> json) {
    return PerformanceInsight(
      title: json['title'] as String,
      description: json['description'] as String,
      severity: InsightSeverity.values.byName(json['severity'] as String),
    );
  }
}

/// 위험 감지 및 조언 (Warning) 섹션의 개별 인사이트
class WarningInsight {
  final String title;
  final String description;
  final InsightSeverity severity;

  /// 해당 경고를 유발한 지표 수치 (예: ACWR 1.32)
  final double? metricValue;

  /// 지표의 기준 임계값
  final double? threshold;

  const WarningInsight({
    required this.title,
    required this.description,
    this.severity = InsightSeverity.warning,
    this.metricValue,
    this.threshold,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'severity': severity.name,
        'metricValue': metricValue,
        'threshold': threshold,
      };

  factory WarningInsight.fromJson(Map<String, dynamic> json) {
    return WarningInsight(
      title: json['title'] as String,
      description: json['description'] as String,
      severity: InsightSeverity.values.byName(json['severity'] as String),
      metricValue: (json['metricValue'] as num?)?.toDouble(),
      threshold: (json['threshold'] as num?)?.toDouble(),
    );
  }
}

/// 다음 주 미션 (Action Item)
class ActionItem {
  final String instruction;
  final String rationale;

  /// 우선순위 (1 = 최우선)
  final int priority;

  const ActionItem({
    required this.instruction,
    required this.rationale,
    this.priority = 1,
  });

  Map<String, dynamic> toJson() => {
        'instruction': instruction,
        'rationale': rationale,
        'priority': priority,
      };

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      instruction: json['instruction'] as String,
      rationale: json['rationale'] as String,
      priority: json['priority'] as int? ?? 1,
    );
  }
}
