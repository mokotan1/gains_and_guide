/// 디로드 판단·적용에 사용되는 상수 (매직 넘버 제거)
class DeloadConstants {
  DeloadConstants._();

  // ---------------------------------------------------------------------------
  // 시그널 가중치 (합계 = 1.0)
  // ---------------------------------------------------------------------------
  static const double weightRpeFatigue = 0.35;
  static const double weightPlateau = 0.25;
  static const double weightTimeBased = 0.20;
  static const double weightFailureRate = 0.20;

  // ---------------------------------------------------------------------------
  // RPE 피로 시그널
  // ---------------------------------------------------------------------------
  static const double rpeHighThreshold = 9.0;
  static const double rpeLowBaseline = 7.0;
  static const int rpeLookbackSessions = 3;

  // ---------------------------------------------------------------------------
  // 정체/퇴보 시그널
  // ---------------------------------------------------------------------------
  static const int plateauLookbackEntries = 4;

  // ---------------------------------------------------------------------------
  // 주기 기반 시그널
  // ---------------------------------------------------------------------------
  static const int minWeeksWithoutDeload = 4;
  static const int maxWeeksWithoutDeload = 6;

  // ---------------------------------------------------------------------------
  // 실패율 시그널
  // ---------------------------------------------------------------------------
  static const double failureRateHighThreshold = 0.50;
  static const double failureRateLowBaseline = 0.15;
  static const int failureLookbackSessions = 3;

  // ---------------------------------------------------------------------------
  // 종합 판정
  // ---------------------------------------------------------------------------
  static const double fatigueScoreThreshold = 65.0;

  // ---------------------------------------------------------------------------
  // 디로드 적용
  // ---------------------------------------------------------------------------
  static const double deloadWeightReductionRatio = 0.60;

  /// 사이클 세션 수를 계산할 수 없을 때 사용하는 기본값
  static const int defaultDeloadCycleSessions = 3;
}
