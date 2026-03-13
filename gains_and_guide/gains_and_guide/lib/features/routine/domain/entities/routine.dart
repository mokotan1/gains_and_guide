/// 루틴 — 도메인 엔티티
class Routine {
  final int? id;
  final String name;
  final String description;
  final String createdAt;

  Routine({
    this.id,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  factory Routine.fromMap(Map<String, dynamic> json) => Routine(
        id: json['_id'] as int?,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        '_id': id,
        'name': name,
        'description': description,
        'created_at': createdAt,
      };

  Routine copyWith({
    int? id,
    String? name,
    String? description,
    String? createdAt,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
