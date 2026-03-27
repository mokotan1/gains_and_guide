import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/ai_coach/domain/coaching_example.dart';

void main() {
  group('CoachingMessage', () {
    test('fromJson creates valid instance', () {
      final json = {'role': 'user', 'content': '테스트 메시지'};
      final message = CoachingMessage.fromJson(json);

      expect(message.role, 'user');
      expect(message.content, '테스트 메시지');
    });

    test('fromJson throws on empty role', () {
      final json = {'role': '', 'content': '내용'};
      expect(() => CoachingMessage.fromJson(json), throwsFormatException);
    });

    test('fromJson throws on missing content', () {
      final json = {'role': 'user'};
      expect(() => CoachingMessage.fromJson(json), throwsFormatException);
    });

    test('fromJson throws on null role', () {
      final json = {'role': null, 'content': '내용'};
      expect(() => CoachingMessage.fromJson(json), throwsFormatException);
    });

    test('toJson produces correct map', () {
      const message = CoachingMessage(role: 'assistant', content: '응답');
      final json = message.toJson();

      expect(json, {'role': 'assistant', 'content': '응답'});
    });
  });

  group('CoachingExample', () {
    Map<String, dynamic> _validJson() => {
          'id': 'test_001',
          'category': 'volume_load_management',
          'tags': ['ACWR', 'deload'],
          'difficulty': 'intermediate',
          'conversations': [
            {'role': 'user', 'content': '볼륨 질문'},
            {'role': 'assistant', 'content': '볼륨 답변'},
          ],
        };

    test('fromJson creates valid instance', () {
      final example = CoachingExample.fromJson(_validJson());

      expect(example.id, 'test_001');
      expect(example.category, 'volume_load_management');
      expect(example.tags, ['ACWR', 'deload']);
      expect(example.difficulty, 'intermediate');
      expect(example.conversations.length, 2);
      expect(example.conversations.first.role, 'user');
    });

    test('fromJson throws on empty id', () {
      final json = _validJson()..['id'] = '';
      expect(() => CoachingExample.fromJson(json), throwsFormatException);
    });

    test('fromJson throws on missing category', () {
      final json = _validJson()..remove('category');
      expect(() => CoachingExample.fromJson(json), throwsFormatException);
    });

    test('fromJson throws on empty conversations', () {
      final json = _validJson()..['conversations'] = [];
      expect(() => CoachingExample.fromJson(json), throwsFormatException);
    });

    test('fromJson defaults difficulty to intermediate', () {
      final json = _validJson()..remove('difficulty');
      final example = CoachingExample.fromJson(json);
      expect(example.difficulty, 'intermediate');
    });

    test('matchesAny returns true for matching tag', () {
      final example = CoachingExample.fromJson(_validJson());
      expect(example.matchesAny({'ACWR', 'other'}), isTrue);
    });

    test('matchesAny returns true for matching category', () {
      final example = CoachingExample.fromJson(_validJson());
      expect(example.matchesAny({'volume_load_management'}), isTrue);
    });

    test('matchesAny returns false for no match', () {
      final example = CoachingExample.fromJson(_validJson());
      expect(example.matchesAny({'unrelated', 'keyword'}), isFalse);
    });
  });

  group('CoachingCategory', () {
    test('fromJson creates valid instance', () {
      final json = {
        'id': 'rpe_autoregulation',
        'name': 'RPE 자가 조절',
        'description': '설명',
        'system_instruction': '지시사항',
      };
      final category = CoachingCategory.fromJson(json);

      expect(category.id, 'rpe_autoregulation');
      expect(category.name, 'RPE 자가 조절');
      expect(category.systemInstruction, '지시사항');
    });

    test('fromJson throws on empty id', () {
      final json = {'id': '', 'name': 'test'};
      expect(() => CoachingCategory.fromJson(json), throwsFormatException);
    });

    test('fromJson defaults missing fields to empty strings', () {
      final json = {'id': 'test_cat'};
      final category = CoachingCategory.fromJson(json);

      expect(category.name, '');
      expect(category.description, '');
      expect(category.systemInstruction, '');
    });
  });

  group('CoachingKnowledgeBase', () {
    Map<String, dynamic> _validKnowledgeBaseJson() => {
          'version': '1.0.0',
          'categories': [
            {
              'id': 'cat_a',
              'name': 'Category A',
              'description': 'Desc A',
              'system_instruction': 'Instruction A',
            },
            {
              'id': 'cat_b',
              'name': 'Category B',
              'description': 'Desc B',
              'system_instruction': 'Instruction B',
            },
          ],
          'examples': [
            {
              'id': 'ex_1',
              'category': 'cat_a',
              'tags': ['tag1'],
              'conversations': [
                {'role': 'user', 'content': 'Q1'},
                {'role': 'assistant', 'content': 'A1'},
              ],
            },
            {
              'id': 'ex_2',
              'category': 'cat_a',
              'tags': ['tag2'],
              'conversations': [
                {'role': 'user', 'content': 'Q2'},
                {'role': 'assistant', 'content': 'A2'},
              ],
            },
            {
              'id': 'ex_3',
              'category': 'cat_b',
              'tags': ['tag3'],
              'conversations': [
                {'role': 'user', 'content': 'Q3'},
                {'role': 'assistant', 'content': 'A3'},
              ],
            },
          ],
        };

    test('fromJson creates valid instance', () {
      final kb = CoachingKnowledgeBase.fromJson(_validKnowledgeBaseJson());

      expect(kb.version, '1.0.0');
      expect(kb.categories.length, 2);
      expect(kb.examples.length, 3);
    });

    test('findByCategory filters correctly', () {
      final kb = CoachingKnowledgeBase.fromJson(_validKnowledgeBaseJson());
      final results = kb.findByCategory('cat_a');

      expect(results.length, 2);
      expect(results.every((e) => e.category == 'cat_a'), isTrue);
    });

    test('findByCategory returns empty for unknown category', () {
      final kb = CoachingKnowledgeBase.fromJson(_validKnowledgeBaseJson());
      expect(kb.findByCategory('nonexistent'), isEmpty);
    });

    test('getCategoryById returns correct category', () {
      final kb = CoachingKnowledgeBase.fromJson(_validKnowledgeBaseJson());
      final cat = kb.getCategoryById('cat_b');

      expect(cat, isNotNull);
      expect(cat!.name, 'Category B');
    });

    test('getCategoryById returns null for unknown id', () {
      final kb = CoachingKnowledgeBase.fromJson(_validKnowledgeBaseJson());
      expect(kb.getCategoryById('nonexistent'), isNull);
    });

    test('fromJson defaults version to 0.0.0', () {
      final kb = CoachingKnowledgeBase.fromJson({});
      expect(kb.version, '0.0.0');
      expect(kb.categories, isEmpty);
      expect(kb.examples, isEmpty);
    });
  });
}
