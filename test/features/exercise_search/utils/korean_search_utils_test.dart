import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/features/exercise_search/utils/korean_search_utils.dart';

void main() {
  group('KoreanSearchUtils.extractChosung', () {
    test('한글 문자열에서 초성을 정확히 추출한다', () {
      expect(KoreanSearchUtils.extractChosung('벤치 프레스'), 'ㅂㅊ ㅍㄹㅅ');
    });

    test('영문/숫자는 그대로 반환한다', () {
      expect(KoreanSearchUtils.extractChosung('ABC 123'), 'ABC 123');
    });

    test('빈 문자열은 빈 문자열을 반환한다', () {
      expect(KoreanSearchUtils.extractChosung(''), '');
    });

    test('한글+영문 혼합 문자열을 처리한다', () {
      expect(KoreanSearchUtils.extractChosung('EZ바 컬'), 'EZㅂ ㅋ');
    });
  });

  group('KoreanSearchUtils.matchesSearch', () {
    test('초성으로 매칭한다 (ㅂㅊ -> 벤치 프레스)', () {
      expect(KoreanSearchUtils.matchesSearch('ㅂㅊ', '벤치 프레스'), isTrue);
    });

    test('부분 문자열로 매칭한다 (인클 -> 인클라인 벤치 프레스)', () {
      expect(
          KoreanSearchUtils.matchesSearch('인클', '인클라인 벤치 프레스'), isTrue);
    });

    test('영문 부분 문자열로 매칭한다', () {
      expect(
          KoreanSearchUtils.matchesSearch('bench', 'Barbell Bench Press'),
          isTrue);
    });

    test('대소문자를 무시한다', () {
      expect(
          KoreanSearchUtils.matchesSearch('BENCH', 'barbell bench press'),
          isTrue);
    });

    test('매칭되지 않는 경우 false를 반환한다', () {
      expect(KoreanSearchUtils.matchesSearch('스쿼트', '벤치 프레스'), isFalse);
    });

    test('빈 쿼리는 항상 true를 반환한다', () {
      expect(KoreanSearchUtils.matchesSearch('', '아무 문자열'), isTrue);
    });

    test('빈 대상에 비어있지 않은 쿼리는 false를 반환한다', () {
      expect(KoreanSearchUtils.matchesSearch('ㅂㅊ', ''), isFalse);
    });

    test('초성 ㅃ(쌍비읍)을 올바르게 처리한다', () {
      expect(KoreanSearchUtils.matchesSearch('ㅃ', '빠른 스킵'), isTrue);
    });

    test('공백 포함 초성 검색도 동작한다', () {
      expect(KoreanSearchUtils.matchesSearch('ㅂㅊ ㅍㄹㅅ', '벤치 프레스'), isTrue);
    });
  });
}
