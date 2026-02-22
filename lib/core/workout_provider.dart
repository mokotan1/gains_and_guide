import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/home/presentation/home_screen.dart'; // Exercise 모델 공유를 위해

// 운동 목록 상태를 관리하는 Notifier
class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]);

  // 새로운 프로그램 적용
  void applyProgram(List<Exercise> newExercises) {
    state = newExercises;
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
