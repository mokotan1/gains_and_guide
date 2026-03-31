import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/cardio_source.dart';
import '../domain/health/cardio_remote_sync.dart';
import '../domain/repositories/cardio_history_repository.dart';

/// Supabase `cardio_history` 에 웨어러블 구간을 반영한다.
///
/// RLS(`auth.uid()::text = user_id`)를 통과하려면 Supabase Auth 세션이 필요하다.
/// 세션이 없으면 동기화를 건너뛴다.
class SupabaseCardioRemoteSync implements CardioRemoteSync {
  SupabaseCardioRemoteSync({
    required SupabaseClient client,
    required CardioHistoryRepository cardioHistoryRepository,
  })  : _client = client,
        _cardioRepo = cardioHistoryRepository;

  final SupabaseClient _client;
  final CardioHistoryRepository _cardioRepo;

  @override
  Future<void> pushHealthCardioWindow({
    required String userId,
    required String startDate,
    required String endDate,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (_client.auth.currentSession == null) {
      debugPrint(
        'SupabaseCardioRemoteSync: Supabase Auth 세션이 없어 cardio 원격 동기화를 건너뜁니다.',
      );
      return;
    }

    try {
      await _client
          .from('cardio_history')
          .delete()
          .eq('user_id', userId)
          .eq('source', kCardioSourceHealth)
          .gte('date', startDate)
          .lte('date', endDate);

      if (rows.isEmpty) return;

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final mapped = rows.map((r) => _toSupabaseRow(r, syncedAt: nowIso)).toList();
      await _client.from('cardio_history').insert(mapped);

      final ids = rows
          .map((r) => r['external_id'] as String?)
          .whereType<String>()
          .toList();
      await _cardioRepo.updateSyncedAtForExternalIds(ids, nowIso);
    } catch (e, st) {
      debugPrint('SupabaseCardioRemoteSync: $e\n$st');
    }
  }

  static Map<String, dynamic> _toSupabaseRow(
    Map<String, dynamic> r, {
    required String syncedAt,
  }) {
    final dateStr = r['date']?.toString() ?? '';
    final dateOnly =
        dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
    return {
      'user_id': r['user_id'],
      'cardio_name': r['cardio_name'],
      'duration_minutes': r['duration_minutes'],
      'distance_km': r['distance_km'],
      'calories': r['calories'],
      'rpe': r['rpe'],
      'date': dateOnly,
      'avg_heart_rate': r['avg_heart_rate'],
      'max_heart_rate': r['max_heart_rate'],
      'source': r['source'] ?? kCardioSourceHealth,
      'external_id': r['external_id'],
      'synced_at': syncedAt,
    };
  }
}
