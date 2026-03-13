/// 신체 프로필 — 도메인 엔티티
class BodyProfile {
  final int? id;
  final double weight;
  final double muscleMass;

  BodyProfile({
    this.id,
    required this.weight,
    required this.muscleMass,
  });

  Map<String, dynamic> toMap() => {
        'id': id ?? 1,
        'weight': weight,
        'muscle_mass': muscleMass,
      };

  factory BodyProfile.fromMap(Map<String, dynamic> map) => BodyProfile(
        id: map['id'] as int?,
        weight: (map['weight'] as num?)?.toDouble() ?? 0,
        muscleMass: (map['muscle_mass'] as num?)?.toDouble() ?? 0,
      );
}
