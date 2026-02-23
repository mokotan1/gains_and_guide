import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

@freezed
class Exercise with _$Exercise {
  const Exercise._();

  const factory Exercise({
    required String id,
    required String name,
    required int sets,
    required int reps,
    required double weight,
    @Default([]) List<bool> setStatus,
    @Default([]) List<int?> setRpe,
    @Default(false) bool isBodyweight,
    @Default(false) bool isCardio,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) => _$ExerciseFromJson(json);

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
}
