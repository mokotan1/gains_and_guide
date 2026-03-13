/// JSON 역직렬화 실패 시 사용 (스택/내부 정보 노출 방지)
class ExerciseParseException implements Exception {
  final String message;
  ExerciseParseException(this.message);
  @override
  String toString() => 'ExerciseParseException: $message';
}

class Exercise {
  final String id;
  final String name;
  final int sets;
  final int reps;
  final double weight;
  final List<bool> setStatus;
  final List<int?> setRpe;
  final bool isBodyweight;
  final bool isCardio;

  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    this.setStatus = const [],
    this.setRpe = const [],
    this.isBodyweight = false,
    this.isCardio = false,
  });

  factory Exercise.initial({
    required String id,
    required String name,
    required int sets,
    required int reps,
    required double weight,
    bool isBodyweight = false,
    bool isCardio = false,
  }) {
    return Exercise(
      id: id,
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
      setStatus: List.filled(sets, false),
      setRpe: List.filled(sets, null),
      isBodyweight: isBodyweight,
      isCardio: isCardio,
    );
  }

  Exercise copyWith({
    String? id,
    String? name,
    int? sets,
    int? reps,
    double? weight,
    List<bool>? setStatus,
    List<int?>? setRpe,
    bool? isBodyweight,
    bool? isCardio,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      setStatus: setStatus ?? this.setStatus,
      setRpe: setRpe ?? this.setRpe,
      isBodyweight: isBodyweight ?? this.isBodyweight,
      isCardio: isCardio ?? this.isCardio,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'setStatus': setStatus,
    'setRpe': setRpe,
    'isBodyweight': isBodyweight,
    'isCardio': isCardio,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    if (id == null || id.isEmpty) throw ExerciseParseException('id is required');
    if (name == null || name.isEmpty) throw ExerciseParseException('name is required');

    final sets = _parseInt(json['sets'], 'sets', min: 1);
    final reps = _parseInt(json['reps'], 'reps', min: 1);
    final weight = _parseDouble(json['weight'], 'weight', min: 0);

    final setStatus = _parseBoolList(json['setStatus'], sets);
    final setRpe = _parseNullableIntList(json['setRpe'], sets);

    return Exercise(
      id: id,
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
      setStatus: setStatus,
      setRpe: setRpe,
      isBodyweight: json['isBodyweight'] == true,
      isCardio: json['isCardio'] == true,
    );
  }

  static int _parseInt(dynamic v, String field, {int min = 0}) {
    if (v == null) return min;
    if (v is int) return v >= min ? v : min;
    if (v is num) return v.toInt().clamp(min, 999);
    final n = int.tryParse(v.toString());
    if (n == null) throw ExerciseParseException('$field must be a number');
    return n.clamp(min, 999);
  }

  static double _parseDouble(dynamic v, String field, {double min = 0}) {
    if (v == null) return min;
    if (v is num) return v.toDouble().clamp(min, double.infinity);
    final n = double.tryParse(v.toString());
    if (n == null) throw ExerciseParseException('$field must be a number');
    return n.clamp(min, double.infinity);
  }

  static List<bool> _parseBoolList(dynamic v, int length) {
    final result = List.filled(length, false);
    if (v is! List || length <= 0) return result;
    for (int i = 0; i < length && i < v.length; i++) {
      result[i] = v[i] == true;
    }
    return result;
  }

  static List<int?> _parseNullableIntList(dynamic v, int length) {
    final result = List<int?>.filled(length, null);
    if (v is! List || length <= 0) return result;
    for (int i = 0; i < length && i < v.length; i++) {
      final e = v[i];
      if (e == null) continue;
      if (e is int) result[i] = e;
      else result[i] = int.tryParse(e.toString());
    }
    return result;
  }
}
