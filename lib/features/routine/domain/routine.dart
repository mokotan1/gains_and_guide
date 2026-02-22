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
    id: json['_id'],
    name: json['name'],
    description: json['description'],
    createdAt: json['created_at'],
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
