import 'package:flutter/material.dart';

class OnboardingPageLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? bottomHint;

  const OnboardingPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.bottomHint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ...children,
          if (bottomHint != null) ...[
            const Spacer(),
            bottomHint!,
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
