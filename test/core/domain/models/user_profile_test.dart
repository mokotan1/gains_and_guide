import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/domain/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    final sampleProfile = UserProfile(
      id: 1,
      goal: TrainingGoal.hypertrophy,
      level: TrainingLevel.intermediate,
      frequency: WeeklyFrequency.moderate,
      equipment: {EquipmentType.freeWeight, EquipmentType.machine},
      createdAt: DateTime(2026, 3, 27),
    );

    group('toMap / fromMap 직렬화', () {
      test('toMap → fromMap 라운드트립 시 동일한 값 복원', () {
        final map = sampleProfile.toMap();
        final restored = UserProfile.fromMap(map);

        expect(restored.id, sampleProfile.id);
        expect(restored.goal, sampleProfile.goal);
        expect(restored.level, sampleProfile.level);
        expect(restored.frequency, sampleProfile.frequency);
        expect(restored.equipment, sampleProfile.equipment);
        expect(restored.createdAt, sampleProfile.createdAt);
      });

      test('toMap의 equipment는 JSON 배열 문자열', () {
        final map = sampleProfile.toMap();
        final decoded = json.decode(map['equipment'] as String);

        expect(decoded, isA<List>());
        expect(decoded, contains('freeWeight'));
        expect(decoded, contains('machine'));
        expect(decoded, isNot(contains('bodyweight')));
      });

      test('equipment가 단일 선택이어도 정상 직렬화', () {
        final single = UserProfile(
          goal: TrainingGoal.strength,
          level: TrainingLevel.beginner,
          frequency: WeeklyFrequency.low,
          equipment: {EquipmentType.bodyweight},
          createdAt: DateTime(2026, 1, 1),
        );

        final restored = UserProfile.fromMap(single.toMap());
        expect(restored.equipment.length, 1);
        expect(restored.equipment.first, EquipmentType.bodyweight);
      });
    });

    group('fromMap 엣지 케이스', () {
      test('알 수 없는 enum 값이면 ArgumentError 발생', () {
        final badMap = {
          'id': 1,
          'goal': 'unknownGoal',
          'level': 'beginner',
          'frequency': 'low',
          'equipment': '["freeWeight"]',
          'created_at': '2026-01-01T00:00:00.000',
        };

        expect(() => UserProfile.fromMap(badMap), throwsArgumentError);
      });

      test('빈 equipment JSON 배열도 파싱 가능', () {
        final map = {
          'id': 1,
          'goal': 'strength',
          'level': 'beginner',
          'frequency': 'low',
          'equipment': '[]',
          'created_at': '2026-01-01T00:00:00.000',
        };

        final profile = UserProfile.fromMap(map);
        expect(profile.equipment, isEmpty);
      });
    });

    group('copyWith', () {
      test('goal만 변경 시 나머지 필드는 유지', () {
        final updated = sampleProfile.copyWith(goal: TrainingGoal.fatLoss);

        expect(updated.goal, TrainingGoal.fatLoss);
        expect(updated.level, sampleProfile.level);
        expect(updated.frequency, sampleProfile.frequency);
        expect(updated.equipment, sampleProfile.equipment);
      });

      test('equipment 변경 시 새 Set으로 교체', () {
        final updated = sampleProfile.copyWith(
          equipment: {EquipmentType.bodyweight},
        );

        expect(updated.equipment.length, 1);
        expect(updated.equipment.first, EquipmentType.bodyweight);
      });
    });

    group('Enum 속성 검증', () {
      test('모든 TrainingGoal에 label/emoji/description/aiHint이 존재', () {
        for (final goal in TrainingGoal.values) {
          expect(goal.label, isNotEmpty);
          expect(goal.emoji, isNotEmpty);
          expect(goal.description, isNotEmpty);
          expect(goal.aiHint, isNotEmpty);
        }
      });

      test('모든 TrainingLevel에 label/emoji/description/aiHint이 존재', () {
        for (final level in TrainingLevel.values) {
          expect(level.label, isNotEmpty);
          expect(level.emoji, isNotEmpty);
          expect(level.description, isNotEmpty);
          expect(level.aiHint, isNotEmpty);
        }
      });

      test('모든 WeeklyFrequency에 label/emoji/description/splitRecommendation이 존재', () {
        for (final freq in WeeklyFrequency.values) {
          expect(freq.label, isNotEmpty);
          expect(freq.emoji, isNotEmpty);
          expect(freq.description, isNotEmpty);
          expect(freq.splitRecommendation, isNotEmpty);
        }
      });

      test('모든 EquipmentType에 label/emoji/description이 존재', () {
        for (final equip in EquipmentType.values) {
          expect(equip.label, isNotEmpty);
          expect(equip.emoji, isNotEmpty);
          expect(equip.description, isNotEmpty);
        }
      });
    });
  });
}
