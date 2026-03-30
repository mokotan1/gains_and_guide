import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/exercise_name_ko.dart';
import '../../../core/theme/app_theme.dart';
import '../../routine/domain/exercise.dart';
import '../../routine/domain/exercise_catalog.dart';
import '../domain/exercise_search_state.dart';
import 'providers/exercise_search_providers.dart';
import 'widgets/equipment_filter_chips.dart';
import 'widgets/exercise_list_tile.dart';
import 'widgets/exercise_search_bar.dart';
import 'widgets/muscle_group_tabs.dart';
import 'widgets/quick_select_chips.dart';

/// 운동 추가 바텀시트.
/// [showModalBottomSheet]로 띄우며, 선택된 [Exercise]를 반환한다.
class ExerciseSearchBottomSheet extends ConsumerWidget {
  const ExerciseSearchBottomSheet({super.key});

  static Future<Exercise?> show(BuildContext context) {
    return showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExerciseSearchBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              const ExerciseSearchBar(),
              QuickSelectChips(
                onSelect: (name) => _showSetupDialog(context, ref, name),
              ),
              const SizedBox(height: 8),
              const MuscleGroupTabs(),
              const SizedBox(height: 8),
              const EquipmentFilterChips(),
              const SizedBox(height: 4),
              const Divider(height: 1),
              Expanded(
                child: _ExerciseResultList(
                  scrollController: scrollController,
                  onSelectStrength: (exercise) =>
                      _showSetupDialogFromCatalog(context, ref, exercise),
                  onSelectCardioByName: (name) =>
                      _showCardioSetupDialog(context, ref, name),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  void _showSetupDialog(
      BuildContext context, WidgetRef ref, String exerciseName) {
    final navigator = Navigator.of(context);
    _showExerciseSetupDialog(
      context: context,
      exerciseName: exerciseName,
      isCardio: false,
    ).then((exercise) {
      if (exercise != null) navigator.pop(exercise);
    });
  }

  void _showSetupDialogFromCatalog(
      BuildContext context, WidgetRef ref, ExerciseCatalog catalog) {
    final koName = ExerciseNameKo.get(catalog.name);
    final navigator = Navigator.of(context);
    _showExerciseSetupDialog(
      context: context,
      exerciseName: koName,
      isCardio: false,
    ).then((exercise) {
      if (exercise != null) navigator.pop(exercise);
    });
  }

  void _showCardioSetupDialog(
      BuildContext context, WidgetRef ref, String name) {
    final koName = ExerciseNameKo.get(name);
    final navigator = Navigator.of(context);
    _showExerciseSetupDialog(
      context: context,
      exerciseName: koName,
      isCardio: true,
    ).then((exercise) {
      if (exercise != null) navigator.pop(exercise);
    });
  }

  static Future<Exercise?> _showExerciseSetupDialog({
    required BuildContext context,
    required String exerciseName,
    required bool isCardio,
  }) {
    double weight = 0.0;
    int sets = isCardio ? 1 : 3;
    int reps = isCardio ? 30 : 10;

    return showDialog<Exercise>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget buildCounter(
              String label, String valueStr, VoidCallback onDec, VoidCallback onInc) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      onPressed: onDec,
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppTheme.primaryBlue),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 12),
                    Text(valueStr,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onInc,
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppTheme.primaryBlue),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(
              exerciseName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isCardio)
                    buildCounter(
                      '무게 (kg)',
                      weight.toStringAsFixed(1),
                      () => setDialogState(
                          () => weight = (weight - 2.5).clamp(0.0, 500.0)),
                      () => setDialogState(() => weight += 2.5),
                    ),
                  if (!isCardio) const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!isCardio)
                        Expanded(
                          child: buildCounter(
                            '세트',
                            '$sets',
                            () => setDialogState(
                                () => sets = (sets - 1).clamp(1, 20)),
                            () => setDialogState(() => sets += 1),
                          ),
                        ),
                      Expanded(
                        child: buildCounter(
                          isCardio ? '목표 시간 (분)' : '횟수',
                          '$reps',
                          () => setDialogState(
                              () => reps = (reps - 1).clamp(1, 100)),
                          () => setDialogState(() => reps += 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    Exercise.initial(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: exerciseName,
                      sets: isCardio ? 1 : sets,
                      reps: reps,
                      weight: weight,
                      isCardio: isCardio,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('추가'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseResultList extends ConsumerWidget {
  final ScrollController scrollController;
  final void Function(ExerciseCatalog) onSelectStrength;
  final void Function(String name) onSelectCardioByName;

  const _ExerciseResultList({
    required this.scrollController,
    required this.onSelectStrength,
    required this.onSelectCardioByName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseSearchProvider);

    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    if (state.isCardioTab) {
      return _buildCardioList(context, ref, state);
    }

    return _buildStrengthList(context, ref, state);
  }

  Widget _buildStrengthList(
      BuildContext context, WidgetRef ref, ExerciseSearchState state) {
    final exercises = state.strengthResults;

    if (exercises.isEmpty) {
      return _buildEmptyState('검색 결과가 없습니다');
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: exercises.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final koName = ExerciseNameKo.get(exercise.name);
        final isFav = state.favoriteStrengthIds.contains(exercise.id);
        final equipLabel =
            EquipmentFilter.labels[exercise.equipment.toLowerCase()] ??
                exercise.equipment;

        return ExerciseListTile(
          name: koName,
          subtitle: equipLabel.isNotEmpty ? equipLabel : null,
          isFavorite: isFav,
          onTap: () => onSelectStrength(exercise),
          onToggleFavorite: () {
            if (exercise.id == null) return;
            ref
                .read(exerciseSearchProvider.notifier)
                .toggleFavorite(exercise.id!, isCardio: false);
          },
        );
      },
    );
  }

  Widget _buildCardioList(
      BuildContext context, WidgetRef ref, ExerciseSearchState state) {
    final exercises = state.cardioResults;

    if (exercises.isEmpty) {
      return _buildEmptyState('유산소 운동이 없습니다');
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: exercises.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 16, endIndent: 16, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final koName = ExerciseNameKo.get(exercise.name);
        final isFav = state.favoriteCardioIds.contains(exercise.id);

        return ExerciseListTile(
          name: koName,
          subtitle: exercise.equipment.isNotEmpty ? exercise.equipment : null,
          isFavorite: isFav,
          onTap: () => onSelectCardioByName(exercise.name),
          onToggleFavorite: () {
            if (exercise.id == null) return;
            ref
                .read(exerciseSearchProvider.notifier)
                .toggleFavorite(exercise.id!, isCardio: true);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
