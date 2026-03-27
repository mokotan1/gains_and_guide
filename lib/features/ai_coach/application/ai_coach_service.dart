import '../domain/coaching_example.dart';
import '../domain/repositories/coaching_knowledge_repository.dart';

/// 사용자 메시지를 분석하여 관련 학습 데이터를 선별하고,
/// 서버에 전송할 Few-shot 컨텍스트 프롬프트를 구성하는 서비스.
class AiCoachService {
  final CoachingKnowledgeRepository _repository;

  static const int _maxExamplesPerRequest = 3;

  static const Map<String, Set<String>> _keywordCategoryMap = {
    'volume_load_management': {
      '볼륨', 'ACWR', '부하', '디로딩', 'deload', '오버트레이닝',
      'overtraining', '총량', '위험', '과부하',
    },
    'rpe_autoregulation': {
      'RPE', 'rpe', '자각도', '힘들', '무겁', '가볍', '여유',
      'RIR', '증량', '감량', '강도',
    },
    'volume_distribution': {
      '세트', '밸런스', '가슴', '등', '하체', '어깨', '팔',
      '분배', '불균형', '루틴 평가', 'push', 'pull',
    },
    'fitness_fatigue_model': {
      '피로', '회복', '연속', '떨어', '약해', '초과회복',
      '수행능력', '근력 저하', '체력', '휴식',
    },
  };

  AiCoachService(this._repository);

  /// 사용자 메시지를 키워드 분석하여, 관련 카테고리를 감지한다.
  Set<String> detectCategories(String userMessage) {
    final detected = <String>{};
    for (final entry in _keywordCategoryMap.entries) {
      if (entry.value.any((kw) => userMessage.contains(kw))) {
        detected.add(entry.key);
      }
    }
    return detected;
  }

  /// 감지된 카테고리에 해당하는 Few-shot 예시들을 최대 [_maxExamplesPerRequest]개 반환한다.
  Future<List<CoachingExample>> selectRelevantExamples(String userMessage) async {
    final categories = detectCategories(userMessage);
    if (categories.isEmpty) return [];

    final allRelevant = <CoachingExample>[];
    for (final categoryId in categories) {
      final examples = await _repository.findByCategory(categoryId);
      allRelevant.addAll(examples);
    }

    final seen = <String>{};
    final unique = allRelevant.where((e) => seen.add(e.id)).toList();

    if (unique.length <= _maxExamplesPerRequest) return unique;
    return unique.sublist(0, _maxExamplesPerRequest);
  }

  /// 사용자 메시지에 맞는 Few-shot 프롬프트 문자열을 구성한다.
  ///
  /// [personalizedContext] 는 기존 `_buildPersonalizedContext` 에서 생성된 문자열이다.
  /// 관련 카테고리의 시스템 지시와 대화 예시를 추가하여 풍부한 컨텍스트를 만든다.
  Future<String> buildEnrichedContext({
    required String userMessage,
    required String personalizedContext,
  }) async {
    final categories = detectCategories(userMessage);
    final examples = await selectRelevantExamples(userMessage);
    final kb = await _repository.loadKnowledgeBase();

    final buffer = StringBuffer();

    buffer.writeln('=== COACHING KNOWLEDGE (v${kb.version}) ===');
    buffer.writeln();

    if (categories.isNotEmpty) {
      buffer.writeln('RELEVANT_COACHING_DOMAINS:');
      for (final catId in categories) {
        final cat = kb.getCategoryById(catId);
        if (cat != null) {
          buffer.writeln('- [${cat.name}] ${cat.systemInstruction}');
        }
      }
      buffer.writeln();
    }

    if (examples.isNotEmpty) {
      buffer.writeln('FEW_SHOT_EXAMPLES:');
      for (var i = 0; i < examples.length; i++) {
        final ex = examples[i];
        buffer.writeln('--- Example ${i + 1} (${ex.category}) ---');
        for (final msg in ex.conversations) {
          buffer.writeln('[${msg.role}]: ${msg.content}');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('=== USER CONTEXT ===');
    buffer.writeln(personalizedContext);

    return buffer.toString();
  }
}
