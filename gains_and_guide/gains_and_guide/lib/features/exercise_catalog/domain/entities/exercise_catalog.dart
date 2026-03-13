/// 운동 카탈로그 한 항목 — 도메인 엔티티
class ExerciseCatalog {
  final int? id;
  final String name;
  final String category;
  final String equipment;
  final String primaryMuscles;
  final String instructions;

  ExerciseCatalog({
    this.id,
    required this.name,
    required this.category,
    required this.equipment,
    required this.primaryMuscles,
    required this.instructions,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'equipment': equipment,
        'primary_muscles': primaryMuscles,
        'instructions': instructions,
      };

  factory ExerciseCatalog.fromMap(Map<String, dynamic> map) => ExerciseCatalog(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        category: map['category'] as String? ?? '',
        equipment: map['equipment'] as String? ?? '',
        primaryMuscles: map['primary_muscles'] as String? ?? '',
        instructions: map['instructions'] as String? ?? '',
      );
}
