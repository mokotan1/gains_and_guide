import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/muscle_group.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../application/exercise_search_service.dart';
import '../../domain/exercise_search_state.dart';

final exerciseSearchServiceProvider = Provider.autoDispose<ExerciseSearchService>((ref) {
  return ExerciseSearchService(
    catalogRepo: ref.watch(exerciseCatalogRepositoryProvider),
    cardioRepo: ref.watch(cardioCatalogRepositoryProvider),
    favoriteRepo: ref.watch(favoriteExerciseRepositoryProvider),
  );
});

final exerciseSearchProvider = StateNotifierProvider.autoDispose<
    ExerciseSearchNotifier, ExerciseSearchState>((ref) {
  final service = ref.watch(exerciseSearchServiceProvider);
  return ExerciseSearchNotifier(service);
});

class ExerciseSearchNotifier extends StateNotifier<ExerciseSearchState> {
  final ExerciseSearchService _service;
  Timer? _debounce;

  ExerciseSearchNotifier(this._service) : super(const ExerciseSearchState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _service.searchStrength(),
        _service.searchCardio(),
        _service.getRecentExerciseNames(),
        _service.getFavoriteStrengthIds(),
        _service.getFavoriteCardioIds(),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        strengthResults: results[0] as dynamic,
        cardioResults: results[1] as dynamic,
        recentExerciseNames: results[2] as dynamic,
        favoriteStrengthIds: results[3] as dynamic,
        favoriteCardioIds: results[4] as dynamic,
        isLoading: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void updateQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _performSearch);
  }

  void selectMuscleGroup(MuscleGroup group) {
    state = state.copyWith(
      selectedMuscleGroup: group,
      selectedEquipment: () => null,
    );
    _performSearch();
  }

  void toggleEquipment(String? equipment) {
    final current = state.selectedEquipment;
    state = state.copyWith(
      selectedEquipment: () => current == equipment ? null : equipment,
    );
    _performSearch();
  }

  Future<void> toggleFavorite(int catalogId, {required bool isCardio}) async {
    await _service.toggleFavorite(catalogId, isCardio: isCardio);
    if (!mounted) return;

    if (isCardio) {
      final ids = await _service.getFavoriteCardioIds();
      if (mounted) state = state.copyWith(favoriteCardioIds: ids);
    } else {
      final ids = await _service.getFavoriteStrengthIds();
      if (mounted) state = state.copyWith(favoriteStrengthIds: ids);
    }
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    try {
      if (state.isCardioTab) {
        final results = await _service.searchCardio(query: state.query);
        if (mounted) {
          state = state.copyWith(cardioResults: results, isLoading: false);
        }
      } else {
        final results = await _service.searchStrength(
          query: state.query,
          muscleGroup: state.selectedMuscleGroup,
          equipment: state.selectedEquipment,
        );
        if (mounted) {
          state = state.copyWith(strengthResults: results, isLoading: false);
        }
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
