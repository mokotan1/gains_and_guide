import 'fatigue_signal.dart';

/// 디로드 판정 결과 (불변 값 객체)
class DeloadRecommendation {
  /// 디로드가 필요한지 여부
  final bool shouldDeload;

  /// 종합 피로도 점수 (0.0 ~ 100.0)
  final double totalScore;

  /// 개별 시그널 상세
  final List<FatigueSignal> signals;

  /// 무게 감량 비율 (예: 0.6 → 현재 무게의 60%로 감량)
  final double reductionRatio;

  /// 디로드에 필요한 훈련 세션 수 (예: Stronglifts A-B-A = 3)
  final int cycleSessions;

  /// 사용자에게 보여줄 요약 메시지
  final String summary;

  const DeloadRecommendation({
    required this.shouldDeload,
    required this.totalScore,
    required this.signals,
    required this.reductionRatio,
    required this.cycleSessions,
    required this.summary,
  });

  const DeloadRecommendation.none()
      : shouldDeload = false,
        totalScore = 0,
        signals = const [],
        reductionRatio = 1.0,
        cycleSessions = 0,
        summary = '';
}
