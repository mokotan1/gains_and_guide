/// 유산소 운동 카탈로그 엔티티.
/// 근력 운동(ExerciseCatalog)과 분리하여 유산소 전용 속성을 관리한다.
class CardioCatalog {
  final int? id;
  final String name;
  final String equipment;
  final String instructions;
  final String level;

  const CardioCatalog({
    this.id,
    required this.name,
    this.equipment = '',
    this.instructions = '',
    this.level = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'equipment': equipment,
      'instructions': instructions,
      'level': level,
    };
  }

  factory CardioCatalog.fromMap(Map<String, dynamic> map) {
    return CardioCatalog(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      equipment: (map['equipment'] as String?) ?? '',
      instructions: (map['instructions'] as String?) ?? '',
      level: (map['level'] as String?) ?? '',
    );
  }
}
