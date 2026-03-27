import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/muscle_group.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exercise_search_providers.dart';

/// 부위별 탭 (가로 스크롤 ChoiceChip).
class MuscleGroupTabs extends ConsumerWidget {
  const MuscleGroupTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      exerciseSearchProvider.select((s) => s.selectedMuscleGroup),
    );

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: MuscleGroup.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final group = MuscleGroup.values[index];
          final isSelected = group == selected;

          return ChoiceChip(
            label: Text(
              group.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            selected: isSelected,
            selectedColor: AppTheme.primaryBlue,
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide.none,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) {
              ref
                  .read(exerciseSearchProvider.notifier)
                  .selectMuscleGroup(group);
            },
          );
        },
      ),
    );
  }
}
