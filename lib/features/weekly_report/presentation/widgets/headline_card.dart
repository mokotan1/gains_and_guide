import 'package:flutter/material.dart';

import '../../domain/models/report_section.dart';

class HeadlineCard extends StatelessWidget {
  final ReportHeadline headline;

  const HeadlineCard({super.key, required this.headline});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _severityStyle(headline.severity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                headline.text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _severityStyle(InsightSeverity severity) {
    return switch (severity) {
      InsightSeverity.positive => (Icons.trending_up_rounded, Colors.green),
      InsightSeverity.neutral => (Icons.info_outline_rounded, Colors.blueGrey),
      InsightSeverity.warning => (Icons.warning_amber_rounded, Colors.orange),
      InsightSeverity.critical => (Icons.error_rounded, Colors.red),
    };
  }
}
