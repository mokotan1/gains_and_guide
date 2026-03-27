import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/user_profile.dart';
import '../providers/onboarding_providers.dart';
import 'ai_hint_banner.dart';
import 'onboarding_page_layout.dart';
import 'selection_card.dart';

class GoalSelectionPage extends ConsumerWidget {
  const GoalSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      onboardingStateProvider.select((s) => s.goal),
    );
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingPageLayout(
      title: '운동을 통해 이루고 싶은\n가장 큰 목표는?',
      subtitle: 'AI 코치가 평가 가중치를 어디에 둘지 결정하는 핵심 질문입니다.',
      bottomHint: selected != null
          ? AiHintBanner(text: selected.aiHint)
          : null,
      children: [
        for (final goal in TrainingGoal.values) ...[
          SelectionCard(
            emoji: goal.emoji,
            title: goal.label,
            subtitle: goal.description,
            isSelected: selected == goal,
            onTap: () => notifier.setGoal(goal),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
