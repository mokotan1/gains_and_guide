import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';

class BodyProfileScreen extends StatefulWidget {
  const BodyProfileScreen({super.key});

  @override
  State<BodyProfileScreen> createState() => _BodyProfileScreenState();
}

class _BodyProfileScreenState extends State<BodyProfileScreen> {
  final _wController = TextEditingController();
  final _mController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final p = await DatabaseHelper.instance.getProfile();
    if (p != null) {
      setState(() {
        _wController.text = p['weight'].toString();
        _mController.text = p['muscle_mass'].toString();
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
                await DatabaseHelper.instance.saveProfile({
                  'id': 1,
                  'weight': double.tryParse(_wController.text) ?? 0,
                  'muscle_mass': double.tryParse(_mController.text) ?? 0
                });
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
