import 'package:flutter/material.dart';

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

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    name: json['name'],
    sets: json['sets'],
    reps: json['reps'],
    weight: json['weight'].toDouble(),
    setStatus: List<bool>.from(json['setStatus'] ?? []),
    setRpe: List<int?>.from(json['setRpe'] ?? []),
    isBodyweight: json['isBodyweight'] ?? false,
    isCardio: json['isCardio'] ?? false,
  );
}
