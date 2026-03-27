import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/exercise_search_providers.dart';

/// 최근 운동 + 즐겨찾기 가로 스크롤 칩.
/// 칩을 탭하면 해당 운동 이름을 반환(onSelect)하여 빠르게 루틴에 추가할 수 있게 한다.
class QuickSelectChips extends ConsumerWidget {
  final void Function(String exerciseName) onSelect;

  const QuickSelectChips({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseSearchProvider);
    final recentNames = state.recentExerciseNames;

    if (recentNames.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
          child: Text(
            '최근 운동',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recentNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final name = recentNames[index];
              return ActionChip(
                label: Text(name, style: const TextStyle(fontSize: 13)),
                avatar: const Icon(Icons.history, size: 16),
                backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.08),
                side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: () => onSelect(name),
              );
            },
          ),
        ),
      ],
    );
  }
}
