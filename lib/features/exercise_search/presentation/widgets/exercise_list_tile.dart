import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// 운동 리스트 아이템 (근력/유산소 공용).
class ExerciseListTile extends StatelessWidget {
  final String name;
  final String? subtitle;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const ExerciseListTile({
    super.key,
    required this.name,
    this.subtitle,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: isFavorite ? Colors.amber : Colors.grey.shade400,
            ),
            onPressed: onToggleFavorite,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppTheme.primaryBlue, size: 22),
              onPressed: onTap,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
