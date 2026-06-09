class CompetitionSeason {
  const CompetitionSeason({
    required this.id,
    required this.slug,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.isActive,
  });

  final String id;
  final String slug;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool isActive;

  factory CompetitionSeason.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final slug = json['slug'];
    final name = json['name'];
    if (id is! String || slug is! String || name is! String) {
      throw FormatException('Invalid competition season payload');
    }
    return CompetitionSeason(
      id: id,
      slug: slug,
      name: name,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      isActive: json['is_active'] == true,
    );
  }
}
