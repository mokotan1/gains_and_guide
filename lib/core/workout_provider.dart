import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import '../features/routine/domain/exercise.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _loadSavedProgram();
  }

  bool isFinished = false; // 정산 완료 상태 관리
  static const String _storageKey = 'saved_weekly_program';
  final Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  // 정산 완료 처리
  void finishWorkout() {
    isFinished = true;
    state = [...state];
  }

  // 프로그램 설정 및 초기화
  Future<void> applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    isFinished = false;
    _currentWeeklyRoutine.clear();
    _currentWeeklyRoutine.addAll(weeklyRoutine);
    await _saveProgram(weeklyRoutine);
    await updateRoutineByDay();
  }

  // 운동 삭제
  void removeExercise(String id) async {
    await DatabaseHelper.instance.deleteExercise(id);
    state = state.where((ex) => ex.id != id).toList();
  }

  // 격주 순환 로직이 포함된 루틴 업데이트
  Future<void> updateRoutineByDay() async {
    final weekday = DateTime.now().weekday;

    // Stronglifts 5x5 핵심 요일 (월, 수, 금) 체크
    if (weekday == 1 || weekday == 3 || weekday == 5) {
      final history = await DatabaseHelper.instance.getAllHistory();

      // 기록이 없으면 첫 운동(Workout A)으로 시작
      if (history.isEmpty) {
        state = _getWorkoutA();
        return;
      }

      // 가장 최근에 완료한 운동 확인
      final lastWorkoutName = history.first['name'];

      // Workout B의 특징적인 운동이 포함되어 있는지 확인
      bool wasLastB = lastWorkoutName == '오버헤드 프레스 (OHP)' ||
          lastWorkoutName == '컨벤셔널 데드리프트';

      // 마지막이 B였다면 A를, A였다면 B를 배정 (격주 순환)
      if (wasLastB) {
        state = _getWorkoutA();
      } else {
        state = _getWorkoutB();
      }
    } else {
      // 그 외 요일은 기존 요일별 설정값 로드
      final routine = _currentWeeklyRoutine[weekday] ?? [];
      state = routine.map((ex) => Exercise.initial(
        id: ex.id,
        name: ex.name,
        sets: ex.sets,
        reps: ex.reps,
        weight: ex.weight,
        isBodyweight: ex.isBodyweight,
        isCardio: ex.isCardio,
      )).toList();
    }
  }

  // Workout A 리스트 정의
  List<Exercise> _getWorkoutA() {
    return [
      Exercise.initial(id: 'a1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(id: 'a2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
      Exercise.initial(id: 'a3', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
    ];
  }

  // Workout B 리스트 정의
  List<Exercise> _getWorkoutB() {
    return [
      Exercise.initial(id: 'b1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
      Exercise.initial(id: 'b2', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
      Exercise.initial(id: 'b3', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
    ];
  }

  // 저장 및 로드 로직
  Future<void> _saveProgram(Map<int, List<Exercise>> routine) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    routine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> _loadSavedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null) {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        _currentWeeklyRoutine[int.parse(day)] = (list as List)
            .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
            .toList();
      });
      await updateRoutineByDay();
    }
  }

  // 세트 상태 업데이트
  void toggleSet(int exIdx, int sIdx, int? rpe) {
    final newState = [...state];
    final ex = newState[exIdx];
    final newStatus = [...ex.setStatus];
    final newRpe = [...ex.setRpe];
    newStatus[sIdx] = !newStatus[sIdx];
    newRpe[sIdx] = newStatus[sIdx] ? rpe : null;
    newState[exIdx] = ex.copyWith(setStatus: newStatus, setRpe: newRpe);
    state = newState;
  }

  void addExercise(Exercise ex) {
    state = [...state, ex];
  }

  // 히스토리 저장
  Future<void> saveCurrentWorkoutToHistory() async {
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> historyData = [];

    for (var ex in state) {
      for (int i = 0; i < ex.sets; i++) {
        if (ex.setStatus[i]) {
          historyData.add({
            'name': ex.name,
            'sets': i + 1,
            'reps': ex.reps,
            'weight': ex.weight,
            'rpe': ex.setRpe[i] ?? 8,
            'date': now,
          });
        }
      }
    }

    if (historyData.isNotEmpty) {
      await DatabaseHelper.instance.saveWorkoutHistory(historyData);
    }
  }
}

final workoutProvider =
StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) => WorkoutNotifier());