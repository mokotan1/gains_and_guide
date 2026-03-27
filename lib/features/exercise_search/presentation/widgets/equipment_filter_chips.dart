import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/exercise_search_state.dart';
import '../providers/exercise_search_providers.dart';

/// 장비 필터 칩 (바벨, 덤벨, 머신 등).
/// 유산소 탭에서는 표시하지 않는다.
class EquipmentFilterChips extends ConsumerWidget {
  const EquipmentFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseSearchProvider);

    if (state.isCardioTab) return const SizedBox.shrink();

    final selectedEq = state.selectedEquipment;
    final entries = EquipmentFilter.labels.entries.toList();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isSelected = entry.key == selectedEq;

          return FilterChip(
            label: Text(
              entry.value,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            selected: isSelected,
            selectedColor: AppTheme.primaryBlue,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryBlue
                    : Colors.grey.shade300,
              ),
            ),
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onSelected: (_) {
              ref
                  .read(exerciseSearchProvider.notifier)
                  .toggleEquipment(entry.key);
            },
          );
        },
      ),
    );
  }
}
