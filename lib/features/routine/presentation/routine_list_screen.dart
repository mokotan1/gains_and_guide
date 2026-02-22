import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/routine_repository.dart';
import '../domain/routine.dart';

// Riverpod Provider (데이터 fetch)
final routinesProvider = FutureProvider<List<Routine>>((ref) async {
  final repo = ref.watch(routineRepositoryProvider);
  return repo.readAllRoutines();
});

class RoutineListScreen extends ConsumerWidget {
  const RoutineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('나의 운동 루틴')),
      body: routines.when(
        data: (data) => ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(data[index].name),
            subtitle: Text(data[index].description),
            trailing: const Icon(Icons.arrow_forward_ios),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 새 루틴 만들기 화면으로 이동
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
