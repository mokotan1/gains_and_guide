import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/coaching_example.dart';
import '../domain/repositories/coaching_knowledge_repository.dart';

/// JSON 에셋으로부터 코칭 학습 데이터를 로드하는 Repository 구현체.
///
/// 최초 [loadKnowledgeBase] 호출 시 에셋을 파싱하고, 이후에는 메모리 캐시를 반환한다.
/// [assetLoader]를 주입받아 테스트에서 `rootBundle` 의존성을 제거할 수 있다.
class CoachingKnowledgeRepositoryImpl implements CoachingKnowledgeRepository {
  static const String _defaultAssetPath = 'assets/data/ai_coach_training.json';

  final String _assetPath;
  final Future<String> Function(String) _assetLoader;

  CoachingKnowledgeBase? _cache;

  CoachingKnowledgeRepositoryImpl({
    String assetPath = _defaultAssetPath,
    Future<String> Function(String)? assetLoader,
  })  : _assetPath = assetPath,
        _assetLoader = assetLoader ?? rootBundle.loadString;

  @override
  Future<CoachingKnowledgeBase> loadKnowledgeBase() async {
    if (_cache != null) return _cache!;

    final raw = await _assetLoader(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _cache = CoachingKnowledgeBase.fromJson(json);
    return _cache!;
  }

  @override
  Future<List<CoachingExample>> findByCategory(String categoryId) async {
    final kb = await loadKnowledgeBase();
    return kb.findByCategory(categoryId);
  }

  @override
  Future<List<CoachingExample>> findByTags(Set<String> tags) async {
    final kb = await loadKnowledgeBase();
    return kb.examples.where((e) => e.matchesAny(tags)).toList();
  }

  @override
  Future<List<CoachingCategory>> getCategories() async {
    final kb = await loadKnowledgeBase();
    return kb.categories;
  }
}
