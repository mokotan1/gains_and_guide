import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../body_profile/domain/entities/body_profile.dart';
import '../../body_profile/infrastructure/providers.dart';

class BodyProfileScreen extends ConsumerStatefulWidget {
  const BodyProfileScreen({super.key});

  @override
  ConsumerState<BodyProfileScreen> createState() => _BodyProfileScreenState();
}

class _BodyProfileScreenState extends ConsumerState<BodyProfileScreen> {
  final _wController = TextEditingController();
  final _mController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(bodyProfileRepositoryProvider).get();
    if (profile != null && mounted) {
      setState(() {
        _wController.text = profile.weight.toString();
        _mController.text = profile.muscleMass.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('신체 프로필',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(
              controller: _wController,
              decoration: const InputDecoration(labelText: '몸무게 (kg)'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 15),
          TextField(
              controller: _mController,
              decoration: const InputDecoration(labelText: '골격근량 (kg)'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final profile = BodyProfile(
                  id: 1,
                  weight: double.tryParse(_wController.text) ?? 0,
                  muscleMass: double.tryParse(_mController.text) ?? 0,
                );
                await ref.read(bodyProfileRepositoryProvider).save(profile);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('정보가 저장되었습니다.')));
                }
              },
              child: const Text('저장하기'),
            ),
          )
        ]),
      ),
    );
  }
}
