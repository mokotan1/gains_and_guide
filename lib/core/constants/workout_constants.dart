/// 운동·증량·RPE 관련 상수 (매직 넘버/문자열 제거)
class WorkoutConstants {
  WorkoutConstants._();

  /// RPE 기준: 이 미만이면 증량 적용
  static const int rpeThresholdForFullIncrement = 3;
  static const int rpeThresholdForHalfIncrement = 8;

  /// 증량 단위 (kg)
  static const double weightIncrementFull = 5.0;
  static const double weightIncrementHalf = 2.5;

  /// 기본 RPE (미입력 시)
  static const int defaultRpe = 8;

  /// Stronglifts 5x5 A/B 코스 구분용 (직전 운동에 있으면 다음은 반대 코스)
  static const List<String> strongliftsRoutineAKeys = [
    '플랫 벤치 프레스',
    '펜들레이 로우',
  ];
  static const List<String> strongliftsRoutineBKeys = [
    '오버헤드 프레스 (OHP)',
    '컨벤셔널 데드리프트',
  ];

  /// A/B 코스의 메인 운동 이름 (이것만 A/B 교체 대상, 나머지는 보조로 유지)
  static const List<String> strongliftsMainA = [
    '백 스쿼트',
    '플랫 벤치 프레스',
    '펜들레이 로우',
  ];
  static const List<String> strongliftsMainB = [
    '백 스쿼트',
    '오버헤드 프레스 (OHP)',
    '컨벤셔널 데드리프트',
  ];

  /// AI 추천 교체 시 유지할 코어 운동 이름
  static const List<String> coreExerciseNamesToKeep = [
    '백 스쿼트',
    '플랫 벤치 프레스',
    '펜들레이 로우',
    '오버헤드 프레스 (OHP)',
    '컨벤셔널 데드리프트',
    '스쿼트',
    '벤치 프레스',
  ];
}
