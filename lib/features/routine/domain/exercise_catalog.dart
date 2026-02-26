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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'equipment': equipment,
      'primary_muscles': primaryMuscles,
      'instructions': instructions,
    };
  }

  factory ExerciseCatalog.fromMap(Map<String, dynamic> map) {
    return ExerciseCatalog(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      equipment: map['equipment'],
      primaryMuscles: map['primary_muscles'],
      instructions: map['instructions'],
    );
  }
}
