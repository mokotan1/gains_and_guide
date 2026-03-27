import 'package:flutter/material.dart';

import '../../domain/models/report_section.dart';

class WarningCard extends StatelessWidget {
  final List<WarningInsight> warnings;

  const WarningCard({super.key, required this.warnings});

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_rounded,
                    color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  '위험 감지 및 조언',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...warnings.map((w) => _WarningTile(warning: w)),
          ],
        ),
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  final WarningInsight warning;

  const _WarningTile({required this.warning});

  @override
  Widget build(BuildContext context) {
    final isCritical = warning.severity == InsightSeverity.critical;
    final accentColor = isCritical ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical
                    ? Icons.error_rounded
                    : Icons.warning_amber_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning.title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                ),
              ),
              if (warning.metricValue != null)
                _MetricBadge(
                  value: warning.metricValue!,
                  color: accentColor,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            warning.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final double value;
  final Color color;

  const _MetricBadge({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final display = value < 10
        ? value.toStringAsFixed(2)
        : value.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
