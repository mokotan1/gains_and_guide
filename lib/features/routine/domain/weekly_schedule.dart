class WeeklySchedule {
  final int? id;
  final int routineId;
  final int weekday;

  const WeeklySchedule({
    this.id,
    required this.routineId,
    required this.weekday,
  });

  factory WeeklySchedule.fromMap(Map<String, dynamic> map) => WeeklySchedule(
    id: map['_id'] as int?,
    routineId: map['routine_id'] as int,
    weekday: map['weekday'] as int,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) '_id': id,
    'routine_id': routineId,
    'weekday': weekday,
  };
}
