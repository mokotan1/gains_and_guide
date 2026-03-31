import 'package:health/health.dart';

/// 심박 샘플 [HealthDataPoint] 목록에서 평균·최대 심박(bpm)을 계산한다.
/// HR이 없거나 비어 있으면 둘 다 null.
({int? avg, int? max}) averageAndMaxHeartRateBpm(List<HealthDataPoint> points) {
  final values = <double>[];
  for (final p in points) {
    if (p.type != HealthDataType.HEART_RATE) continue;
    final v = p.value;
    if (v is NumericHealthValue) {
      values.add(v.numericValue.toDouble());
    }
  }
  if (values.isEmpty) return (avg: null, max: null);
  final sum = values.fold<double>(0, (a, b) => a + b);
  final avg = (sum / values.length).round();
  final max = values.reduce((a, b) => a > b ? a : b).round();
  return (avg: avg, max: max);
}
