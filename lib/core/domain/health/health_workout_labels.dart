import 'package:health/health.dart';

/// 유산소로 분류할 워크아웃 타입 (러닝·사이클·수영·걷기·HIIT 등).
bool isAerobicCardioWorkout(HealthWorkoutActivityType t) {
  const aerobic = <HealthWorkoutActivityType>{
    HealthWorkoutActivityType.RUNNING,
    HealthWorkoutActivityType.RUNNING_TREADMILL,
    HealthWorkoutActivityType.BIKING,
    HealthWorkoutActivityType.BIKING_STATIONARY,
    HealthWorkoutActivityType.HAND_CYCLING,
    HealthWorkoutActivityType.ELLIPTICAL,
    HealthWorkoutActivityType.ROWING,
    HealthWorkoutActivityType.ROWING_MACHINE,
    HealthWorkoutActivityType.SWIMMING,
    HealthWorkoutActivityType.SWIMMING_POOL,
    HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
    HealthWorkoutActivityType.WALKING,
    HealthWorkoutActivityType.WALKING_TREADMILL,
    HealthWorkoutActivityType.HIKING,
    HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
    HealthWorkoutActivityType.STAIR_CLIMBING,
    HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE,
    HealthWorkoutActivityType.STAIRS,
    HealthWorkoutActivityType.MIXED_CARDIO,
    HealthWorkoutActivityType.JUMP_ROPE,
    HealthWorkoutActivityType.CROSS_COUNTRY_SKIING,
    HealthWorkoutActivityType.SKIING,
    HealthWorkoutActivityType.SNOWSHOEING,
  };
  return aerobic.contains(t);
}

/// 한글 표기 (주간 레포트·AI 컨텍스트용).
String koreanLabelForWorkoutType(HealthWorkoutActivityType t) {
  switch (t) {
    case HealthWorkoutActivityType.RUNNING:
      return '달리기';
    case HealthWorkoutActivityType.RUNNING_TREADMILL:
      return '런닝머신';
    case HealthWorkoutActivityType.BIKING:
    case HealthWorkoutActivityType.HAND_CYCLING:
      return '사이클';
    case HealthWorkoutActivityType.BIKING_STATIONARY:
      return '실내 사이클';
    case HealthWorkoutActivityType.ELLIPTICAL:
      return '일립티컬';
    case HealthWorkoutActivityType.ROWING:
    case HealthWorkoutActivityType.ROWING_MACHINE:
      return '로잉';
    case HealthWorkoutActivityType.SWIMMING:
    case HealthWorkoutActivityType.SWIMMING_POOL:
    case HealthWorkoutActivityType.SWIMMING_OPEN_WATER:
      return '수영';
    case HealthWorkoutActivityType.WALKING:
    case HealthWorkoutActivityType.WALKING_TREADMILL:
      return '걷기';
    case HealthWorkoutActivityType.HIKING:
      return '하이킹';
    case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
      return 'HIIT';
    case HealthWorkoutActivityType.STAIR_CLIMBING:
    case HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE:
    case HealthWorkoutActivityType.STAIRS:
      return '계단';
    case HealthWorkoutActivityType.MIXED_CARDIO:
      return 'mixed cardio';
    case HealthWorkoutActivityType.JUMP_ROPE:
      return '줄넘기';
    default:
      return t.name;
  }
}
