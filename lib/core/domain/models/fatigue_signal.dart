/// 피로도 판단에 사용되는 개별 시그널 (불변 값 객체)
class FatigueSignal {
  final FatigueSignalType type;

  /// 0.0 ~ 100.0 정규화된 점수
  final double score;

  /// 가중치 (0.0 ~ 1.0)
  final double weight;

  /// 점수 산출 근거를 사람이 읽을 수 있는 형태로 보관
  final String reason;

  const FatigueSignal({
    required this.type,
    required this.score,
    required this.weight,
    required this.reason,
  });

  double get weightedScore => score * weight;
}

enum FatigueSignalType {
  rpeFatigue,
  plateau,
  timeBased,
  failureRate,
}
