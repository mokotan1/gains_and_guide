import '../coaching_example.dart';

/// AI 코치 학습 데이터(Few-shot 예시)에 대한 읽기 전용 Repository 인터페이스.
///
/// 데이터 소스(JSON 에셋, 원격 API 등)로부터 코칭 지식 베이스를 로드하며,
/// 카테고리·태그 기반 필터링을 지원한다.
abstract class CoachingKnowledgeRepository {
  /// 전체 지식 베이스를 로드한다. 최초 호출 시 파싱, 이후 캐시 반환.
  Future<CoachingKnowledgeBase> loadKnowledgeBase();

  /// 특정 카테고리에 해당하는 예시만 반환한다.
  Future<List<CoachingExample>> findByCategory(String categoryId);

  /// 태그 집합과 하나라도 겹치는 예시를 반환한다.
  Future<List<CoachingExample>> findByTags(Set<String> tags);

  /// 모든 카테고리 메타데이터를 반환한다.
  Future<List<CoachingCategory>> getCategories();
}
