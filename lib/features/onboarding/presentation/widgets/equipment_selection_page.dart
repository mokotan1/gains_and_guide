import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/user_profile.dart';
import '../providers/onboarding_providers.dart';
import 'ai_hint_banner.dart';
import 'onboarding_page_layout.dart';
import 'selection_card.dart';

class EquipmentSelectionPage extends ConsumerWidget {
  const EquipmentSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSet = ref.watch(
      onboardingStateProvider.select((s) => s.equipment),
    );
    final notifier = ref.read(onboardingStateProvider.notifier);

    return OnboardingPageLayout(
      title: '주로 어떤 장비를 사용하여\n운동하시나요?',
      subtitle: '복수 선택이 가능합니다. 운동 카탈로그를 환경에 맞게 필터링합니다.',
      bottomHint: const AiHintBanner(
        text: '선택한 장비에 맞는 운동만 추천되어, 실제로 수행 가능한 루틴을 만들어 드립니다.',
      ),
      children: [
        for (final equip in EquipmentType.values) ...[
          SelectionCard(
            emoji: equip.emoji,
            title: equip.label,
            subtitle: equip.description,
            isSelected: selectedSet.contains(equip),
            onTap: () => notifier.toggleEquipment(equip),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
