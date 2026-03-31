import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/deload/application/deload_service.dart';
import '../features/routine/domain/exercise.dart';
import '../features/routine/application/workout_service.dart';
import 'auth/user_identity.dart';
import 'constants/workout_constants.dart';
import 'domain/models/deload_recommendation.dart';
import 'providers/repository_providers.dart';

class WorkoutNotifier extends StateNotifier<List<Exercise>> {
  final WorkoutService _service;
  final DeloadService _deloadService;
  final UserIdentity _userIdentity;

  WorkoutNotifier(this._service, this._deloadService, this._userIdentity)
      : super([]) {
    _loadAllData();
  }

  bool isFinished = false;
  DeloadRecommendation? deloadRecommendation;
  final Map<int, List<Exercise>> _currentWeeklyRoutine = {};

  Future<void> _loadAllData() async {
    _currentWeeklyRoutine.addAll(await _service.loadWeeklyProgram());

    final String? lastSavedDate = await _service.getLastDate();
    final String todayDate = DateTime.now().toString().split(' ')[0];

    if (lastSavedDate != todayDate) {
      isFinished = false;
      await updateRoutineByDay();
      await _service.updateLastDate(todayDate);
    } else {
      final session = await _service.loadCurrentSession();
      if (session != null) {
        state = session;
        isFinished = await _service.getIsFinished();
        // 같은 날 세션은 SharedPreferences 에 캐시되므로, DB 프로그레션/디로드만
        // 고친 경우에도 여기서 무게를 다시 맞춘다.
        await _reconcileSessionWeightsWithProgression();
        await _refreshFatigueScore();
      } else {
        await updateRoutineByDay();
      }
    }
  }

  /// 오늘 저장된 세션 복원 시: SQLite 프로그레션과 활성 디로드(DB) 기준으로
  /// 무게만 갱신하고, 세트 완료·RPE·실패·횟수는 유지한다.
  Future<void> _reconcileSessionWeightsWithProgression() async {
    if (state.isEmpty) return;

    final activeRec = await _deloadService.getActiveDeloadRecommendation();
    final updated = <Exercise>[];

    for (final ex in state) {
      if (ex.isCardio || ex.isBodyweight) {
        updated.add(ex);
        continue;
      }

      final baseW = await _service.getLatestWeight(ex.name) ?? ex.weight;
      final withBase = ex.copyWith(
        weight: baseW,
        setWeights: List.filled(ex.sets, baseW),
      );
      final weighted = activeRec != null
          ? _deloadService.applyDeload([withBase], activeRec).first
          : withBase;

      updated.add(weighted.copyWith(
        setStatus: ex.setStatus,
        setRpe: ex.setRpe,
        setFailed: ex.setFailed,
        setReps: ex.setReps,
      ));
    }

    state = updated;
    await _saveCurrentSession();
  }

  /// 앱 재시작 시 피로도를 재평가하되, 진행 중인 디로드 상태는 보존
  Future<void> _refreshFatigueScore() async {
    if (state.isEmpty) {
      deloadRecommendation = null;
      return;
    }

    final activeRec = await _deloadService.getActiveDeloadRecommendation();
    if (activeRec != null) {
      deloadRecommendation = activeRec;
      return;
    }

    deloadRecommendation = await _deloadService.evaluateDeloadNeed(state);
  }

  Future<void> applyProgression(List<dynamic> progressions) async {
    for (var p in progressions) {
      final String name = p['name'];
      final double increase = (p['increase'] as num).toDouble();

      _currentWeeklyRoutine.forEach((day, exercises) {
        for (int i = 0; i < exercises.length; i++) {
          if (exercises[i].name == name) {
            exercises[i] = exercises[i].copyWith(weight: exercises[i].weight + increase);
          }
        }
      });
    }

    await _service.saveWeeklyProgram(_currentWeeklyRoutine);
    state = [...state];
  }

  Future<void> _saveCurrentSession() async {
    await _service.saveCurrentSession(state, isFinished);
  }

  void replaceRecommendedExercises(List<Exercise> newExercises) {
    final coreState = state
        .where((ex) => WorkoutConstants.coreExerciseNamesToKeep.contains(ex.name))
        .toList();
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

    await _service.saveWeeklyProgram(weeklyRoutine);
    await _service.clearSession();
    await updateRoutineByDay();
  }

  void toggleSet(int exIdx, int sIdx, int? rpe) {
    final newState = [...state];
    final ex = newState[exIdx];
    final newStatus = [...ex.setStatus];
    final newRpe = [...ex.setRpe];
    newStatus[sIdx] = !newStatus[sIdx];
    newRpe[sIdx] = newStatus[sIdx] ? rpe : null;
    final newFailed = [...ex.setFailed];
    if (newStatus[sIdx]) newFailed[sIdx] = false;
    newState[exIdx] = ex.copyWith(setStatus: newStatus, setRpe: newRpe, setFailed: newFailed);
    state = newState;
    _saveCurrentSession();
  }

  /// 세트 실패 기록: 실제 완료한 횟수와 RPE 10을 저장
  void failSet(int exIdx, int sIdx, int actualReps) {
    final newState = [...state];
    final ex = newState[exIdx];
    final newFailed = [...ex.setFailed];
    final newStatus = [...ex.setStatus];
    final newRpe = [...ex.setRpe];
    final newReps = [...ex.setReps];
    newFailed[sIdx] = true;
    newStatus[sIdx] = true;
    newRpe[sIdx] = 10;
    newReps[sIdx] = actualReps;
    newState[exIdx] = ex.copyWith(
      setFailed: newFailed, setStatus: newStatus,
      setRpe: newRpe, setReps: newReps,
    );
    state = newState;
    _saveCurrentSession();
  }

  void updateSetWeight(int exIdx, int sIdx, double newWeight, {bool applyToRemaining = false}) {
    final newState = [...state];
    final ex = newState[exIdx];
    final weights = [...ex.setWeights];
    if (applyToRemaining) {
      for (int i = sIdx; i < weights.length; i++) {
        weights[i] = newWeight;
      }
    } else {
      weights[sIdx] = newWeight;
    }
    newState[exIdx] = ex.copyWith(setWeights: weights);
    state = newState;
    _saveCurrentSession();
  }

  void updateSetReps(int exIdx, int sIdx, int newReps, {bool applyToRemaining = false}) {
    final newState = [...state];
    final ex = newState[exIdx];
    final repsList = [...ex.setReps];
    if (applyToRemaining) {
      for (int i = sIdx; i < repsList.length; i++) {
        repsList[i] = newReps;
      }
    } else {
      repsList[sIdx] = newReps;
    }
    newState[exIdx] = ex.copyWith(setReps: repsList);
    state = newState;
    _saveCurrentSession();
  }

  void addSetToExercise(int exIdx) {
    final newState = [...state];
    final ex = newState[exIdx];
    final lastWeight = ex.setWeights.isNotEmpty ? ex.setWeights.last : ex.weight;
    final lastReps = ex.setReps.isNotEmpty ? ex.setReps.last : ex.reps;
    newState[exIdx] = ex.copyWith(
      sets: ex.sets + 1,
      setStatus: [...ex.setStatus, false],
      setRpe: [...ex.setRpe, null],
      setWeights: [...ex.setWeights, lastWeight],
      setReps: [...ex.setReps, lastReps],
      setFailed: [...ex.setFailed, false],
    );
    state = newState;
    _saveCurrentSession();
  }

  void removeSetFromExercise(int exIdx, int sIdx) {
    final newState = [...state];
    final ex = newState[exIdx];
    if (ex.sets <= 1) return;
    newState[exIdx] = ex.copyWith(
      sets: ex.sets - 1,
      setStatus: [...ex.setStatus]..removeAt(sIdx),
      setRpe: [...ex.setRpe]..removeAt(sIdx),
      setWeights: [...ex.setWeights]..removeAt(sIdx),
      setReps: [...ex.setReps]..removeAt(sIdx),
      setFailed: [...ex.setFailed]..removeAt(sIdx),
    );
    state = newState;
    _saveCurrentSession();
  }

  Future<void> updateRoutineByDay() async {
    final weekday = DateTime.now().weekday;
    List<Exercise> routine = _currentWeeklyRoutine[weekday] ?? [];

    // [수정 1] 백 스쿼트가 포함된 루틴이라면, 요일 무시하고 이전 운동 기록을 기반으로 A/B 코스 결정
    if (routine.isNotEmpty && routine.any((e) => e.name == '백 스쿼트')) {
      routine = await _getSmartStrongliftsRoutine(routine);
    }

    if (routine.isNotEmpty) {
      final List<Exercise> updatedRoutine = [];
      for (var ex in routine) {
        final w = await _service.getLatestWeight(ex.name) ?? ex.weight;
        updatedRoutine.add(ex.copyWith(
          weight: w,
          setWeights: List.filled(ex.sets, w),
          setReps: List.filled(ex.sets, ex.reps),
          setStatus: List.filled(ex.sets, false),
          setRpe: List.filled(ex.sets, null),
        ));
      }

      final activeRec = await _deloadService.getActiveDeloadRecommendation();

      if (activeRec != null) {
        deloadRecommendation = activeRec;
        state = _deloadService.applyDeload(updatedRoutine, activeRec);
      } else {
        final cycleSessions = _currentWeeklyRoutine.length;
        var rec = await _deloadService.evaluateDeloadNeed(updatedRoutine);

        if (rec.shouldDeload && rec.cycleSessions != cycleSessions) {
          rec = DeloadRecommendation(
            shouldDeload: true,
            totalScore: rec.totalScore,
            signals: rec.signals,
            reductionRatio: rec.reductionRatio,
            cycleSessions: cycleSessions,
            summary: rec.summary,
          );
        }

        deloadRecommendation = rec;

        if (rec.shouldDeload) {
          state = _deloadService.applyDeload(updatedRoutine, rec);
          await _deloadService.recordDeload(rec);
        } else {
          state = updatedRoutine;
        }
      }
    } else {
      deloadRecommendation = null;
      state = [];
    }
    _saveCurrentSession();
  }

  /// A/B 양쪽 메인 운동 이름 (보조 운동 필터링에 사용)
  static final Set<String> _allStrongliftsMainNames = {
    ...WorkoutConstants.strongliftsMainA,
    ...WorkoutConstants.strongliftsMainB,
  };

  /// 기록 기반 Stronglifts 5x5 A/B 코스 교차 로직
  /// - workout_history는 date DESC로 조회되므로 첫 행이 가장 최근 날짜
  /// - 날짜는 항상 YYYY-MM-DD로 정규화해 비교 (DB/시간대 차이 대비)
  /// - A-key(벤치) 또는 B-key(OHP) 외에 데드리프트도 B 판별에 사용
  Future<List<Exercise>> _getSmartStrongliftsRoutine(List<Exercise> defaultRoutine) async {
    final history = await _service.getAllHistory();
    if (history.isEmpty) return defaultRoutine;

    final lastDate = _normalizeDateString(history.first['date']);
    if (lastDate.isEmpty) return defaultRoutine;

    final lastExercises = history
        .where((h) => _normalizeDateString(h['date']) == lastDate)
        .map((h) => (h['name']?.toString() ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    final routineA = [
      Exercise.initial(id: 's1_a', name: '백 스쿼트', sets: 5, reps: 5, weight: 0),
      Exercise.initial(id: 's2_a', name: '플랫 벤치 프레스', sets: 5, reps: 5, weight: 0),
      Exercise.initial(id: 's3_a', name: '펜들레이 로우', sets: 5, reps: 5, weight: 0),
    ];
    final routineB = [
      Exercise.initial(id: 's1_b', name: '백 스쿼트', sets: 5, reps: 5, weight: 0),
      Exercise.initial(id: 's4_b', name: '오버헤드 프레스 (OHP)', sets: 5, reps: 5, weight: 0),
      Exercise.initial(id: 's5_b', name: '컨벤셔널 데드리프트', sets: 1, reps: 5, weight: 0),
    ];

    final bool lastWasA = lastExercises.any(
        (e) => WorkoutConstants.strongliftsRoutineAKeys.contains(e));
    final bool lastWasB = lastExercises.any(
        (e) => WorkoutConstants.strongliftsRoutineBKeys.contains(e) ||
               e == '컨벤셔널 데드리프트');

    if (lastWasA && !lastWasB) {
      return _mergeWithAccessories(routineB, defaultRoutine);
    }
    if (lastWasB && !lastWasA) {
      return _mergeWithAccessories(routineA, defaultRoutine);
    }

    return defaultRoutine;
  }

  /// 메인 루틴(A 또는 B) 뒤에, 사용자가 직접 추가한 보조 운동만 붙임
  /// A/B 양쪽 메인 운동은 모두 제외하여 교차 오염을 방지
  static List<Exercise> _mergeWithAccessories(
    List<Exercise> mainRoutine,
    List<Exercise> dayRoutine,
  ) {
    final accessories = dayRoutine
        .where((e) => !_allStrongliftsMainNames.contains(e.name))
        .toList();
    if (accessories.isEmpty) return mainRoutine;
    return [...mainRoutine, ...accessories];
  }

  /// DB/SharedPreferences 등에서 오는 날짜 값을 YYYY-MM-DD로 통일
  static String _normalizeDateString(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    final part = s.split(' ').first;
    return part.length >= 10 ? part.substring(0, 10) : part;
  }

  Future<void> saveCurrentWorkoutToHistory() async {
    final now = DateTime.now().toString().split(' ')[0];
    final List<Map<String, dynamic>> weightHistory = [];
    final List<Map<String, dynamic>> cardioRows = [];
    final isDeloadSession = (deloadRecommendation?.shouldDeload ?? false) ||
        await _deloadService.isCurrentlyInDeload();

    for (var ex in state) {
      if (ex.isCardio) {
        for (int i = 0; i < ex.sets; i++) {
          if (!ex.setStatus[i]) continue;
          final int rpe = ex.setRpe[i] ?? WorkoutConstants.defaultRpe;
          final double durationMinutes =
              (ex.setReps[i] > 0 ? ex.setReps[i] : ex.reps).toDouble();
          cardioRows.add({
            'user_id': _userIdentity.userId,
            'cardio_name': ex.name,
            'duration_minutes': durationMinutes,
            'distance_km': null,
            'calories': null,
            'rpe': rpe.toDouble(),
            'date': now,
          });
        }
        continue;
      }

      int successSets = 0;
      int countBelow3 = 0;
      int countBelow8 = 0;

      for (int i = 0; i < ex.sets; i++) {
        if (!ex.setStatus[i]) continue;

        final bool failed = ex.setFailed[i];
        int rpe = ex.setRpe[i] ?? WorkoutConstants.defaultRpe;

        if (!failed) {
          successSets++;
          if (rpe < WorkoutConstants.rpeThresholdForFullIncrement) countBelow3++;
          if (rpe < WorkoutConstants.rpeThresholdForHalfIncrement) countBelow8++;
        }

        weightHistory.add({
          'name': ex.name,
          'sets': i + 1,
          'reps': ex.setReps[i],
          'weight': ex.setWeights[i],
          'rpe': rpe,
          'date': now,
          'is_deload': isDeloadSession ? 1 : 0,
        });
      }

      final isDeloading = deloadRecommendation?.shouldDeload ?? false;
      final hasFailures = ex.failedSetCount > 0;
      if (successSets > 0 && !isDeloading && !hasFailures) {
        final double maxSetWeight = ex.setWeights
            .asMap().entries
            .where((e) => ex.setStatus[e.key] && !ex.setFailed[e.key])
            .fold(0.0, (prev, e) => e.value > prev ? e.value : prev);
        double newWeight = maxSetWeight > 0 ? maxSetWeight : ex.weight;
        if (countBelow3 >= successSets) {
          newWeight += WorkoutConstants.weightIncrementFull;
          await _service.saveProgression(ex.name, newWeight);
        } else if (countBelow8 >= successSets) {
          newWeight += WorkoutConstants.weightIncrementHalf;
          await _service.saveProgression(ex.name, newWeight);
        }
      }
    }

    if (weightHistory.isNotEmpty) {
      await _service.saveWorkoutHistory(weightHistory);
    }
    if (cardioRows.isNotEmpty) {
      await _service.saveCardioHistory(cardioRows);
    }

    if (weightHistory.isNotEmpty || cardioRows.isNotEmpty) {
      // DB에 활성 디로드가 있으면 반드시 차감 (notifier 플래그와 불일치해도 동작)
      if (await _deloadService.isCurrentlyInDeload()) {
        await _deloadService.completeDeloadSession();
        final activeRec = await _deloadService.getActiveDeloadRecommendation();
        deloadRecommendation = activeRec ??
            await _deloadService.evaluateDeloadNeed(state);
        state = [...state];
      }

      await _service.clearSession();
      isFinished = false;
    }
  }
}

final workoutProvider =
StateNotifierProvider<WorkoutNotifier, List<Exercise>>((ref) {
  final service = ref.watch(workoutServiceProvider);
  final deloadService = ref.watch(deloadServiceProvider);
  final userIdentity = ref.watch(userIdentityProvider);
  return WorkoutNotifier(service, deloadService, userIdentity);
});