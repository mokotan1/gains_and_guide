import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/presentation/home_screen.dart'; // Exercise 모델 공유를 위해

// 운동 목록 상태를 관리하는 Notifier
class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _loadRoutineByDay();
  }

  // AI 추천 보조 운동 목록을 별도로 관리
  List<Exercise> _aiRecommendedExercises = [];
  List<Exercise> get aiRecommendedExercises => _aiRecommendedExercises;

  void setAiRecommendations(List<Exercise> recommendations) {
    _aiRecommendedExercises = recommendations;
    // 상태를 새로고침하기 위해 현재 상태를 재할당 (UI 업데이트 유도)
    state = [...state];
  }

  // 현재 요일에 맞는 루틴 자동 로드 (기본 예시)
  void _loadRoutineByDay() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1: 월, 2: 화, ..., 7: 일

    // TODO: DB나 설정에서 저장된 프로그램 타입을 가져오는 로직 필요
    // 현재는 예시로 월/수/금은 5x5, 나머지는 휴식/커스텀으로 처리
  }

  // 특정 프로그램의 요일별 전체 루틴 적용
  Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  void applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) {
    _currentWeeklyRoutine = weeklyRoutine;
    updateRoutineByDay();
  }

  void updateRoutineByDay() {
    final weekday = DateTime.now().weekday;
    state = _currentWeeklyRoutine[weekday] ?? [];
  }

  // 세트 상태 업데이트
  void toggleSet(int exIndex, int setIndex, int? rpe) {
    var newState = [...state];
    var ex = newState[exIndex];
    var newStatus = [...ex.setStatus];
    var newRpe = [...ex.setRpe];
    
    newStatus[setIndex] = !newStatus[setIndex];
    newRpe[setIndex] = newStatus[setIndex] ? rpe : null;
    
    newState[exIndex] = ex.copyWith(setStatus: newStatus, setRpe: newRpe);
    state = newState;
  }

  // 운동 추가
  void addExercise(Exercise exercise) {
    state = [...state, exercise];
  }
}

// Provider 정의
final workoutProvider = StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) {
  return WorkoutNotifier();
});
