import 'package:flutter/material.dart';

import '../../domain/models/report_section.dart';

class PerformanceCard extends StatelessWidget {
  final List<PerformanceInsight> insights;

  const PerformanceCard({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  '퍼포먼스 리뷰',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...insights.map((insight) => _InsightTile(insight: insight)),
          ],
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final PerformanceInsight insight;

  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
