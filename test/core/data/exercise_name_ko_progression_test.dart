import 'package:flutter_test/flutter_test.dart';
import 'package:gains_and_guide/core/data/exercise_name_ko.dart';

void main() {
  group('ExerciseNameKo progression', () {
    test('progressionLookupAliases links English catalog and Korean display', () {
      final en = 'Barbell Squat';
      final ko = '백 스쿼트';
      final fromEn = ExerciseNameKo.progressionLookupAliases(en);
      expect(fromEn, contains(en));
      expect(fromEn, contains(ko));

      final fromKo = ExerciseNameKo.progressionLookupAliases(ko);
      expect(fromKo, contains(en));
      expect(fromKo, contains(ko));
    });

    test('progressionLookupAliases returns single entry for unmapped name', () {
      final a = ExerciseNameKo.progressionLookupAliases('Custom Lift');
      expect(a, ['Custom Lift']);
    });

    test('canonicalProgressionName maps English key to Korean', () {
      expect(
        ExerciseNameKo.canonicalProgressionName('Barbell Squat'),
        '백 스쿼트',
      );
    });

    test('canonicalProgressionName leaves Korean unchanged', () {
      expect(
        ExerciseNameKo.canonicalProgressionName('백 스쿼트'),
        '백 스쿼트',
      );
    });

    test('Stronglifts preset Korean links to catalog for progression', () {
      final aliases = ExerciseNameKo.progressionLookupAliases('플랫 벤치 프레스');
      expect(aliases, contains('Barbell Bench Press - Medium Grip'));
      expect(aliases, contains('바벨 벤치 프레스 (미디엄 그립)'));

      expect(
        ExerciseNameKo.canonicalProgressionName('플랫 벤치 프레스'),
        '바벨 벤치 프레스 (미디엄 그립)',
      );
    });

    test('Pendlay preset maps to Bent Over Barbell Row catalog', () {
      final aliases = ExerciseNameKo.progressionLookupAliases('펜들레이 로우');
      expect(aliases, contains('Bent Over Barbell Row'));
      expect(aliases, contains('바벨 벤트오버 로우'));
    });
  });
}
