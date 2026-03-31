import 'package:health/health.dart';

/// [WorkoutHealthValue]의 거리를 km 로 환산한다. 알 수 없는 단위면 null.
double? workoutDistanceKm(WorkoutHealthValue w) {
  final d = w.totalDistance;
  final u = w.totalDistanceUnit;
  if (d == null || u == null) return null;
  final n = d.toDouble();
  switch (u) {
    case HealthDataUnit.METER:
      return n / 1000.0;
    case HealthDataUnit.MILE:
      return n * 1.609344;
    case HealthDataUnit.YARD:
      return n * 0.0009144;
    case HealthDataUnit.FOOT:
      return n * 0.0003048;
    case HealthDataUnit.INCH:
      return n * 0.0000254;
    case HealthDataUnit.CENTIMETER:
      return n / 100000.0;
    default:
      return null;
  }
}

/// [WorkoutHealthValue]의 에너지를 kcal 로 환산한다.
double? workoutEnergyKcal(WorkoutHealthValue w) {
  final e = w.totalEnergyBurned;
  final u = w.totalEnergyBurnedUnit;
  if (e == null || u == null) return null;
  final n = e.toDouble();
  switch (u) {
    case HealthDataUnit.KILOCALORIE:
    case HealthDataUnit.LARGE_CALORIE:
      return n;
    case HealthDataUnit.SMALL_CALORIE:
      return n / 1000.0;
    case HealthDataUnit.JOULE:
      return n / 4184.0;
    default:
      return null;
  }
}
