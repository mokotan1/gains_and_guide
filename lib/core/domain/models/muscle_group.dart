/// 운동 부위 그룹 enum.
/// exercises.json의 primary_muscles 값을 사용자 친화적 한글 탭으로 매핑한다.
enum MuscleGroup {
  all('전체', []),
  chest('가슴', ['chest']),
  back('등', ['lats', 'middle back', 'lower back', 'traps']),
  legs('하체', ['quadriceps', 'hamstrings', 'glutes', 'calves', 'abductors', 'adductors']),
  shoulders('어깨', ['shoulders']),
  arms('팔', ['biceps', 'triceps', 'forearms']),
  core('코어', ['abs', 'neck']),
  cardio('유산소', []);

  const MuscleGroup(this.label, this.dbMuscleKeys);

  final String label;

  /// exercise_catalog.primary_muscles 컬럼에 저장된 영문 키 목록.
  /// cardio는 별도 테이블이므로 빈 리스트.
  final List<String> dbMuscleKeys;

  /// primary_muscles 문자열(쉼표 구분)이 이 그룹에 해당하는지 판별한다.
  bool matches(String primaryMuscles) {
    if (this == MuscleGroup.all) return true;
    if (this == MuscleGroup.cardio) return false;
    final lower = primaryMuscles.toLowerCase();
    return dbMuscleKeys.any((key) => lower.contains(key));
  }

  /// primary_muscles 문자열로부터 가장 적합한 MuscleGroup을 반환한다.
  /// 매칭되는 그룹이 없으면 null.
  static MuscleGroup? fromPrimaryMuscles(String primaryMuscles) {
    for (final group in MuscleGroup.values) {
      if (group == MuscleGroup.all || group == MuscleGroup.cardio) continue;
      if (group.matches(primaryMuscles)) return group;
    }
    return null;
  }
}
