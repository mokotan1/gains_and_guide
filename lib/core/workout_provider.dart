import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import '../features/routine/domain/exercise.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  WorkoutNotifier() : super([]) {
    _loadAllData();
  }

  bool isFinished = false;
  static const String _programKey = 'saved_weekly_program';
  static const String _sessionKey = 'current_workout_session';
  static const String _lastDateKey = 'last_session_date'; // 날짜 체크용 키 추가
  final Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 저장된 주간 프로그램 로드
    final savedProgram = prefs.getString(_programKey);
    if (savedProgram != null) {
      final decoded = jsonDecode(savedProgram) as Map<String, dynamic>;
      decoded.forEach((day, list) {
        _currentWeeklyRoutine[int.parse(day)] = (list as List)
            .map((i) => Exercise.fromJson(i as Map<String, dynamic>))
            .toList();
      });
    }

    // 2. [날짜 변경 체크] 날짜가 바뀌었는지 확인하여 자동 로드 결정
    final String? lastSavedDate = prefs.getString(_lastDateKey);
    final String todayDate = DateTime.now().toString().split(' ')[0];

    if (lastSavedDate != todayDate) {
      // 날짜가 바뀌었으면 기존 세션을 초기화하고 오늘의 루틴을 새로 불러옴
      isFinished = false;
      await updateRoutineByDay();
      await prefs.setString(_lastDateKey, todayDate); // 오늘 날짜로 갱신
    } else {
      // 같은 날짜라면 기존에 진행 중이던 세션 로드
      final savedSession = prefs.getString(_sessionKey);
      if (savedSession != null) {
        final List<dynamic> decodedList = jsonDecode(savedSession);
        state = decodedList.map((i) => Exercise.fromJson(i as Map<String, dynamic>)).toList();
        isFinished = prefs.getBool('is_workout_finished') ?? false;
      } else {
        await updateRoutineByDay();
      }
    }
  }

  // [증량 반영 로직] AI의 증량 제안을 주간 루틴 데이터에 영구적으로 반영
  Future<void> applyProgression(List<dynamic> progressions) async {
    for (var p in progressions) {
      final String name = p['name'];
      final double increase = (p['increase'] as num).toDouble();

      // 저장된 모든 요일의 루틴에서 해당 운동의 무게를 수정
      _currentWeeklyRoutine.forEach((day, exercises) {
        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i].name == name) {
            exercises[i] = exercises[i].copyWith(weight: exercises[i].weight + increase);
          }
        }
      });
    }

    // 변경된 주간 루틴을 SharedPreferences에 영구 저장
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    _currentWeeklyRoutine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_programKey, jsonEncode(data));

    // UI에 반영하기 위해 상태 갱신 (선택 사항: 현재 화면 무게도 바로 바꿀 경우)
    state = [...state];
  }

  Future<void> _saveCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(state.map((e) => e.toJson()).toList()));
    await prefs.setBool('is_workout_finished', isFinished);
  }

  void replaceRecommendedExercises(List<Exercise> newExercises) {
    final coreNames = ['백 스쿼트', '플랫 벤치 프레스', '펜들레이 로우', '오버헤드 프레스 (OHP)', '컨벤셔널 데드리프트', '스쿼트', '벤치 프레스'];
    final coreState = state.where((ex) => coreNames.contains(ex.name)).toList();
    state = [...coreState, ...newExercises];
    _saveCurrentSession();
  }

  void finishWorkout() {
    isFinished = true;
    _saveCurrentSession();
    state = [...state];
  }

  void addExercise(Exercise ex) {
    state = [...state, ex];
    _saveCurrentSession();
  }

  void removeExercise(String id) {
    state = state.where((ex) => ex.id != id).toList();
    _saveCurrentSession();
  }

  Future<void> applyWeeklyProgram(Map<int, List<Exercise>> weeklyRoutine) async {
    isFinished = false;
    _currentWeeklyRoutine.clear();
    _currentWeeklyRoutine.addAll(weeklyRoutine);

    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    weeklyRoutine.forEach((day, exList) {
      data[day.toString()] = exList.map((e) => e.toJson()).toList();
    });
    await prefs.setString(_programKey, jsonEncode(data));

    // 적용 시점의 날짜도 저장하여 오늘 루틴이 바로 뜨게 함
    await prefs.setString(_lastDateKey, DateTime.now().toString().split(' ')[0]);
    await updateRoutineByDay();
  }

  void toggleSet(int exIdx, int sIdx, int? rpe) {
    final newState = [...state];
    final ex = newState[exIdx];
    final newStatus = [...ex.setStatus];
    final newRpe = [...ex.setRpe];
    newStatus[sIdx] = !newStatus[sIdx];
    newRpe[sIdx] = newStatus[sIdx] ? rpe : null;
    newState[exIdx] = ex.copyWith(setStatus: newStatus, setRpe: newRpe);
    state = newState;
    _saveCurrentSession();
  }

  Future<void> updateRoutineByDay() async {
    final weekday = DateTime.now().weekday;
    final routine = _currentWeeklyRoutine[weekday] ?? [];

    if (routine.isNotEmpty) {
      state = routine.map((ex) => Exercise.initial(
        id: ex.id,
        name: ex.name,
        sets: ex.sets,
        reps: ex.reps,
        weight: ex.weight,
        isBodyweight: ex.isBodyweight,
        isCardio: ex.isCardio,
      )).toList();
    } else if (weekday == 1 || weekday == 3 || weekday == 5) {
      final history = await DatabaseHelper.instance.getAllHistory();
      if (history.isEmpty) {
        state = _getWorkoutA();
      } else {
        final lastB = history.first['name'] == '오버헤드 프레스 (OHP)' || history.first['name'] == '컨벤셔널 데드리프트';
        state = lastB ? _getWorkoutA() : _getWorkoutB();
      }
    } else {
      state = [];
    }
    _saveCurrentSession();
  }

  List<Exercise> _getWorkoutA() => [
    Exercise.initial(id: 'a1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
    Exercise.initial(id: 'a2', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 80),
    Exercise.initial(id: 'a3', name: '펜들레이 로우', sets: 5, reps: 5, weight: 80),
  ];

  List<Exercise> _getWorkoutB() => [
    Exercise.initial(id: 'b1', name: '백 스쿼트', sets: 5, reps: 5, weight: 100),
    Exercise.initial(id: 'b2', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 55),
    Exercise.initial(id: 'b3', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 145),
  ];

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.setBool('is_workout_finished', false);
      isFinished = false;
    }
  }
}

final workoutProvider =
StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) => WorkoutNotifier());