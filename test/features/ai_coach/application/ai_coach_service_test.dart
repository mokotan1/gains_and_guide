import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/ai_coach/application/ai_coach_service.dart';
import 'package:gains_and_guide/features/ai_coach/data/coaching_knowledge_repository_impl.dart';

const _testTrainingData = '''
{
  "version": "1.0.0",
  "categories": [
    {
      "id": "volume_load_management",
      "name": "볼륨 부하 관리",
      "description": "ACWR 기반 분석",
      "system_instruction": "ACWR을 계산하세요."
    },
    {
      "id": "rpe_autoregulation",
      "name": "RPE 자가 조절",
      "description": "RPE 변화 추적",
      "system_instruction": "RPE 기반으로 중량을 조절하세요."
    },
    {
      "id": "volume_distribution",
      "name": "볼륨 분배",
      "description": "근육군별 세트 수 분석",
      "system_instruction": "근육군별 밸런스를 확인하세요."
    },
    {
      "id": "fitness_fatigue_model",
      "name": "피트니스-피로 모델",
      "description": "체력과 피로 분석",
      "system_instruction": "피로 마스킹 효과를 설명하세요."
    }
  ],
  "examples": [
    {
      "id": "acwr_001",
      "category": "volume_load_management",
      "tags": ["ACWR", "deload"],
      "conversations": [
        {"role": "user", "content": "볼륨 질문"},
        {"role": "assistant", "content": "ACWR 답변"}
      ]
    },
    {
      "id": "rpe_001",
      "category": "rpe_autoregulation",
      "tags": ["RPE", "strength_gain"],
      "conversations": [
        {"role": "user", "content": "RPE 질문"},
        {"role": "assistant", "content": "RPE 답변"}
      ]
    },
    {
      "id": "vol_001",
      "category": "volume_distribution",
      "tags": ["밸런스", "가슴"],
      "conversations": [
        {"role": "user", "content": "밸런스 질문"},
        {"role": "assistant", "content": "밸런스 답변"}
      ]
    },
    {
      "id": "ffm_001",
      "category": "fitness_fatigue_model",
      "tags": ["피로", "회복"],
      "conversations": [
        {"role": "user", "content": "피로 질문"},
        {"role": "assistant", "content": "피로 답변"}
      ]
    }
  ]
}
''';

CoachingKnowledgeRepositoryImpl _createTestRepo() {
  return CoachingKnowledgeRepositoryImpl(
    assetLoader: (_) async => _testTrainingData,
  );
}

void main() {
  group('AiCoachService', () {
    late AiCoachService service;

    setUp(() {
      service = AiCoachService(_createTestRepo());
    });

    group('detectCategories', () {
      test('detects volume_load_management from 볼륨 keyword', () {
        final categories = service.detectCategories('이번 주 총 볼륨이 15000kg이야');
        expect(categories, contains('volume_load_management'));
      });

      test('detects rpe_autoregulation from RPE keyword', () {
        final categories = service.detectCategories('오늘 RPE가 9였어');
        expect(categories, contains('rpe_autoregulation'));
      });

      test('detects volume_distribution from 가슴 keyword', () {
        final categories = service.detectCategories('가슴 운동 22세트 했어');
        expect(categories, contains('volume_distribution'));
      });

      test('detects fitness_fatigue_model from 피로 keyword', () {
        final categories = service.detectCategories('피로가 쌓인 것 같아');
        expect(categories, contains('fitness_fatigue_model'));
      });

      test('detects multiple categories from complex message', () {
        final categories = service.detectCategories('이번 주 볼륨 많았고 RPE도 높았어');
        expect(categories, containsAll(['volume_load_management', 'rpe_autoregulation']));
      });

      test('returns empty set for unrelated message', () {
        final categories = service.detectCategories('오늘 날씨 좋다');
        expect(categories, isEmpty);
      });
    });

    group('selectRelevantExamples', () {
      test('returns examples for matching category', () async {
        final examples = await service.selectRelevantExamples('볼륨이 너무 높아');
        expect(examples.isNotEmpty, isTrue);
        expect(examples.first.category, 'volume_load_management');
      });

      test('returns empty list for unrelated message', () async {
        final examples = await service.selectRelevantExamples('오늘 날씨 좋다');
        expect(examples, isEmpty);
      });

      test('limits results to max 3 examples', () async {
        final examples = await service.selectRelevantExamples(
          '볼륨 RPE 가슴 피로 전부 다 알려줘',
        );
        expect(examples.length, lessThanOrEqualTo(3));
      });

      test('deduplicates examples by id', () async {
        final examples = await service.selectRelevantExamples('볼륨 과부하 디로딩');
        final ids = examples.map((e) => e.id).toSet();
        expect(ids.length, examples.length);
      });
    });

    group('buildEnrichedContext', () {
      test('includes coaching knowledge header', () async {
        final context = await service.buildEnrichedContext(
          userMessage: '볼륨이 높아',
          personalizedContext: 'USER_PROFILE: test',
        );
        expect(context, contains('COACHING KNOWLEDGE'));
        expect(context, contains('v1.0.0'));
      });

      test('includes relevant coaching domain instructions', () async {
        final context = await service.buildEnrichedContext(
          userMessage: '볼륨이 높아',
          personalizedContext: '',
        );
        expect(context, contains('볼륨 부하 관리'));
        expect(context, contains('ACWR을 계산하세요'));
      });

      test('includes few-shot examples', () async {
        final context = await service.buildEnrichedContext(
          userMessage: 'RPE가 9야',
          personalizedContext: '',
        );
        expect(context, contains('FEW_SHOT_EXAMPLES'));
        expect(context, contains('RPE 답변'));
      });

      test('includes personalized context at the end', () async {
        const personalCtx = 'USER_PROFILE: weight_kg: 80';
        final context = await service.buildEnrichedContext(
          userMessage: '볼륨 질문',
          personalizedContext: personalCtx,
        );
        expect(context, contains('USER CONTEXT'));
        expect(context, contains(personalCtx));
      });

      test('omits few-shot section when no match', () async {
        final context = await service.buildEnrichedContext(
          userMessage: '오늘 날씨 좋다',
          personalizedContext: 'test',
        );
        expect(context, isNot(contains('FEW_SHOT_EXAMPLES')));
      });
    });
  });

  group('CoachingKnowledgeRepositoryImpl', () {
    test('caches after first load', () async {
      var callCount = 0;
      final repo = CoachingKnowledgeRepositoryImpl(
        assetLoader: (_) async {
          callCount++;
          return _testTrainingData;
        },
      );

      await repo.loadKnowledgeBase();
      await repo.loadKnowledgeBase();
      expect(callCount, 1);
    });

    test('findByCategory returns filtered results', () async {
      final repo = _createTestRepo();
      final results = await repo.findByCategory('rpe_autoregulation');

      expect(results.length, 1);
      expect(results.first.id, 'rpe_001');
    });

    test('findByTags returns matching examples', () async {
      final repo = _createTestRepo();
      final results = await repo.findByTags({'ACWR'});

      expect(results.length, 1);
      expect(results.first.id, 'acwr_001');
    });

    test('getCategories returns all categories', () async {
      final repo = _createTestRepo();
      final categories = await repo.getCategories();

      expect(categories.length, 4);
    });

    test('throws on invalid JSON', () async {
      final repo = CoachingKnowledgeRepositoryImpl(
        assetLoader: (_) async => 'invalid json',
      );

      expect(() => repo.loadKnowledgeBase(), throwsA(isA<FormatException>()));
    });
  });
}
