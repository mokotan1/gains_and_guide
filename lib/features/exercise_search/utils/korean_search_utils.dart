/// 한글 초성 검색 및 부분 문자열 검색 유틸리티.
///
/// 유니코드 한글 음절 블록(0xAC00~0xD7A3)에서 초성 인덱스를 추출하여
/// "ㅂㅊ" -> "벤치 프레스" 매칭 등을 지원한다.
class KoreanSearchUtils {
  KoreanSearchUtils._();

  static const int _hangulBase = 0xAC00;
  static const int _hangulEnd = 0xD7A3;
  static const int _jungsungCount = 21;
  static const int _jongsungCount = 28;

  static const List<String> _chosung = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ',
    'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
  ];

  /// 한글 한 글자에서 초성을 추출한다. 한글이 아니면 원래 문자를 반환.
  static String _getChosung(String char) {
    final code = char.codeUnitAt(0);
    if (code < _hangulBase || code > _hangulEnd) return char;
    final index = (code - _hangulBase) ~/ (_jungsungCount * _jongsungCount);
    if (index < 0 || index >= _chosung.length) return char;
    return _chosung[index];
  }

  /// 문자열에서 초성만 추출한다.
  /// "벤치 프레스" -> "ㅂㅊ ㅍㄹㅅ"
  static String extractChosung(String text) {
    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(_getChosung(char));
    }
    return buffer.toString();
  }

  /// 쿼리가 순수 초성으로만 구성되어 있는지 판별한다.
  static bool _isChosungOnly(String query) {
    for (final char in query.split('')) {
      if (char == ' ') continue;
      if (!_chosung.contains(char)) return false;
    }
    return true;
  }

  /// 통합 검색: 일반 부분 문자열 매칭 + 초성 매칭을 함께 수행한다.
  ///
  /// - "벤치" -> "벤치 프레스" 매칭 (부분 문자열)
  /// - "ㅂㅊ" -> "벤치 프레스" 매칭 (초성)
  /// - "인클" -> "인클라인 벤치 프레스" 매칭 (부분 문자열)
  static bool matchesSearch(String query, String target) {
    if (query.isEmpty) return true;
    if (target.isEmpty) return false;

    final lowerQuery = query.toLowerCase().trim();
    final lowerTarget = target.toLowerCase();

    if (lowerTarget.contains(lowerQuery)) return true;

    if (_isChosungOnly(lowerQuery)) {
      final targetChosung = extractChosung(lowerTarget);
      final queryNoSpace = lowerQuery.replaceAll(' ', '');
      final targetChosungNoSpace = targetChosung.replaceAll(' ', '');
      return targetChosungNoSpace.contains(queryNoSpace);
    }

    return false;
  }
}
