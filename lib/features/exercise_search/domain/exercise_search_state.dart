import '../../../core/domain/models/cardio_catalog.dart';
import '../../../core/domain/models/muscle_group.dart';
import '../../routine/domain/exercise_catalog.dart';

/// 운동 검색 바텀시트의 불변(immutable) 상태 모델.
class ExerciseSearchState {
  final String query;
  final MuscleGroup selectedMuscleGroup;
  final String? selectedEquipment;
  final List<ExerciseCatalog> strengthResults;
  final List<CardioCatalog> cardioResults;
  final List<String> recentExerciseNames;
  final Set<int> favoriteStrengthIds;
  final Set<int> favoriteCardioIds;
  final bool isLoading;

  const ExerciseSearchState({
    this.query = '',
    this.selectedMuscleGroup = MuscleGroup.all,
    this.selectedEquipment,
    this.strengthResults = const [],
    this.cardioResults = const [],
    this.recentExerciseNames = const [],
    this.favoriteStrengthIds = const {},
    this.favoriteCardioIds = const {},
    this.isLoading = false,
  });

  bool get isCardioTab => selectedMuscleGroup == MuscleGroup.cardio;

  ExerciseSearchState copyWith({
    String? query,
    MuscleGroup? selectedMuscleGroup,
    String? Function()? selectedEquipment,
    List<ExerciseCatalog>? strengthResults,
    List<CardioCatalog>? cardioResults,
    List<String>? recentExerciseNames,
    Set<int>? favoriteStrengthIds,
    Set<int>? favoriteCardioIds,
    bool? isLoading,
  }) {
    return ExerciseSearchState(
      query: query ?? this.query,
      selectedMuscleGroup: selectedMuscleGroup ?? this.selectedMuscleGroup,
      selectedEquipment: selectedEquipment != null
          ? selectedEquipment()
          : this.selectedEquipment,
      strengthResults: strengthResults ?? this.strengthResults,
      cardioResults: cardioResults ?? this.cardioResults,
      recentExerciseNames: recentExerciseNames ?? this.recentExerciseNames,
      favoriteStrengthIds: favoriteStrengthIds ?? this.favoriteStrengthIds,
      favoriteCardioIds: favoriteCardioIds ?? this.favoriteCardioIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 장비 필터에 사용할 영문키-한글라벨 매핑
class EquipmentFilter {
  static const Map<String, String> labels = {
    'barbell': '바벨',
    'dumbbell': '덤벨',
    'machine': '머신',
    'cable': '케이블',
    'kettlebell': '케틀벨',
    'bands': '밴드',
    'ez curl bar': 'EZ바',
    'none': '맨몸',
    'exercise ball': '짐볼',
    'foam roll': '폼롤러',
    'medicine ball': '메디신볼',
    'other': '기타',
  };

  EquipmentFilter._();
}
