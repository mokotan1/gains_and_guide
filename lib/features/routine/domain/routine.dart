import 'exercise.dart';

class Routine {
  final int? id;
  final String name;
  final String description;
  final String createdAt;
  final List<Exercise> exercises;
  final List<int> assignedWeekdays;

  Routine({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    this.exercises = const [],
    this.assignedWeekdays = const [],
  });

  factory Routine.fromMap(Map<String, dynamic> json) => Routine(
    id: json['_id'] as int?,
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    createdAt: json['created_at'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) '_id': id,
    'name': name,
    'description': description,
    'created_at': createdAt,
  };

  Routine copyWith({
    int? id,
    String? name,
    String? description,
    String? createdAt,
    List<Exercise>? exercises,
    List<int>? assignedWeekdays,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      exercises: exercises ?? this.exercises,
      assignedWeekdays: assignedWeekdays ?? this.assignedWeekdays,
    );
  }

  static String weekdayLabel(int weekday) {
    const labels = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};
    return labels[weekday] ?? '';
  }

  String get weekdaySummary =>
      assignedWeekdays.map(weekdayLabel).join(', ');
}
