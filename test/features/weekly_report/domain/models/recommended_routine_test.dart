import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/weekly_report/domain/models/recommended_routine.dart';

void main() {
  group('RoutineExercise', () {
    test('toJson / fromJson 왕복 변환이 동일하다', () {
      const exercise = RoutineExercise(
        name: 'Lat Pulldown',
        sets: 4,
        reps: 12,
        weight: 50.0,
      );

      final json = exercise.toJson();
      final restored = RoutineExercise.fromJson(json);

      expect(restored.name, exercise.name);
      expect(restored.sets, exercise.sets);
      expect(restored.reps, exercise.reps);
      expect(restored.weight, exercise.weight);
    });

    test('빈 JSON 에서 기본값으로 생성된다', () {
      final exercise = RoutineExercise.fromJson(const {});

      expect(exercise.name, '');
      expect(exercise.sets, 0);
      expect(exercise.reps, 0);
      expect(exercise.weight, 0);
    });
  });

  group('RecommendedRoutine', () {
    final now = DateTime(2026, 3, 27, 12, 0);

    RecommendedRoutine _createSample() {
      return RecommendedRoutine(
        title: '다음 주 추천 루틴',
        rationale: 'ACWR 1.12로 안정, 등 볼륨 부족 보완',
        exercises: const [
          RoutineExercise(name: 'Lat Pulldown', sets: 4, reps: 12, weight: 50),
          RoutineExercise(
              name: 'Seated Cable Row', sets: 3, reps: 12, weight: 45),
        ],
        generatedAt: now,
      );
    }

    test('toJson / fromJson 왕복 변환이 동일하다', () {
      final routine = _createSample();
      final json = routine.toJson();
      final restored = RecommendedRoutine.fromJson(json);

      expect(restored.title, routine.title);
      expect(restored.rationale, routine.rationale);
      expect(restored.exercises.length, routine.exercises.length);
      expect(restored.exercises[0].name, 'Lat Pulldown');
      expect(restored.exercises[1].weight, 45);
      expect(restored.generatedAt, now);
    });

    test('toJsonString / fromJsonString 왕복 변환이 동일하다', () {
      final routine = _createSample();
      final jsonStr = routine.toJsonString();
      final restored = RecommendedRoutine.fromJsonString(jsonStr);

      expect(restored.title, routine.title);
      expect(restored.exercises.length, 2);
    });

    test('jsonString 이 유효한 JSON 이다', () {
      final routine = _createSample();
      final jsonStr = routine.toJsonString();

      expect(() => jsonDecode(jsonStr), returnsNormally);
    });

    test('exercises 가 빈 리스트일 때 정상 동작한다', () {
      final routine = RecommendedRoutine(
        title: '빈 루틴',
        rationale: '데이터 부족',
        exercises: const [],
        generatedAt: now,
      );

      final json = routine.toJson();
      final restored = RecommendedRoutine.fromJson(json);

      expect(restored.exercises, isEmpty);
      expect(restored.title, '빈 루틴');
    });

    test('null exercises 필드에서 빈 리스트로 복원된다', () {
      final routine = RecommendedRoutine.fromJson({
        'title': '테스트',
        'rationale': '테스트',
        'exercises': null,
        'generatedAt': now.toIso8601String(),
      });

      expect(routine.exercises, isEmpty);
    });
  });
}
