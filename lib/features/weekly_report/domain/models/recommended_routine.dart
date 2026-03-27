import 'dart:convert';

/// AI가 주간 분석 결과를 바탕으로 추천한 다음 주 루틴 (불변 값 객체)
class RecommendedRoutine {
  final String title;
  final String rationale;
  final List<RoutineExercise> exercises;
  final DateTime generatedAt;

  const RecommendedRoutine({
    required this.title,
    required this.rationale,
    required this.exercises,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'rationale': rationale,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory RecommendedRoutine.fromJson(Map<String, dynamic> json) {
    return RecommendedRoutine(
      title: json['title'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => RoutineExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RecommendedRoutine.fromJsonString(String jsonStr) {
    return RecommendedRoutine.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }
}

/// 추천 루틴 내 개별 운동 항목 (불변 값 객체)
class RoutineExercise {
  final String name;
  final int sets;
  final int reps;
  final double weight;

  const RoutineExercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
      };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) {
    return RoutineExercise(
      name: json['name'] as String? ?? '',
      sets: json['sets'] as int? ?? 0,
      reps: json['reps'] as int? ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
    );
  }
}
