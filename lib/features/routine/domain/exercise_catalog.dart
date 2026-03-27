class ExerciseCatalog {
  final int? id;
  final String name;
  final String category;
  final String equipment;
  final String primaryMuscles;
  final String secondaryMuscles;
  final String instructions;
  final String level;
  final String forceType;
  final String mechanic;

  const ExerciseCatalog({
    this.id,
    required this.name,
    required this.category,
    required this.equipment,
    required this.primaryMuscles,
    this.secondaryMuscles = '',
    required this.instructions,
    this.level = '',
    this.forceType = '',
    this.mechanic = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'equipment': equipment,
      'primary_muscles': primaryMuscles,
      'secondary_muscles': secondaryMuscles,
      'instructions': instructions,
      'level': level,
      'force_type': forceType,
      'mechanic': mechanic,
    };
  }

  factory ExerciseCatalog.fromMap(Map<String, dynamic> map) {
    return ExerciseCatalog(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      equipment: (map['equipment'] as String?) ?? '',
      primaryMuscles: (map['primary_muscles'] as String?) ?? '',
      secondaryMuscles: (map['secondary_muscles'] as String?) ?? '',
      instructions: (map['instructions'] as String?) ?? '',
      level: (map['level'] as String?) ?? '',
      forceType: (map['force_type'] as String?) ?? '',
      mechanic: (map['mechanic'] as String?) ?? '',
    );
  }
}
