import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';

/// DB 초기화 및 운동 카탈로그 시딩 전용 (단일 책임).
/// 근력 운동은 exercise_catalog, 유산소 운동은 cardio_catalog으로 분리한다.
class DatabaseBootstrap {
  DatabaseBootstrap._();

  static const String _exercisesAssetPath = 'assets/data/exercises.json';

  /// DB 접속 확보 후 카탈로그가 비어 있으면 시딩 수행
  static Future<void> run(DatabaseHelper dbHelper) async {
    final strengthEmpty = await dbHelper.isExerciseCatalogEmpty();
    final cardioEmpty = await dbHelper.isCardioCatalogEmpty();

    if (!strengthEmpty && !cardioEmpty) return;

    try {
      final parsed = await _loadAndClassifyExercises();

      if (strengthEmpty && parsed.strength.isNotEmpty) {
        await dbHelper.seedExerciseCatalog(parsed.strength);
        debugPrint('근력 카탈로그 시딩 완료: ${parsed.strength.length}개');
      }
      if (cardioEmpty && parsed.cardio.isNotEmpty) {
        await dbHelper.seedCardioCatalog(parsed.cardio);
        debugPrint('유산소 카탈로그 시딩 완료: ${parsed.cardio.length}개');
      }
    } catch (e, st) {
      debugPrint('운동 카탈로그 시딩 실패: $e');
      if (kDebugMode) debugPrint('$st');
    }
  }

  static Future<_ClassifiedExercises> _loadAndClassifyExercises() async {
    final String raw = await rootBundle.loadString(_exercisesAssetPath);
    final Object? decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('exercises.json must be a JSON object');
    }
    final exercisesJson = decoded['exercises'];
    if (exercisesJson is! List) {
      throw const FormatException('exercises.json must contain "exercises" array');
    }

    final strength = <Map<String, dynamic>>[];
    final cardio = <Map<String, dynamic>>[];

    for (final e in exercisesJson) {
      if (e is! Map<String, dynamic>) continue;
      final category = _stringFrom(e['category']).toLowerCase();

      if (category == 'cardio') {
        cardio.add(_toCardioSeedRow(e));
      } else {
        strength.add(_toStrengthSeedRow(e));
      }
    }

    return _ClassifiedExercises(strength: strength, cardio: cardio);
  }

  static Map<String, dynamic> _toStrengthSeedRow(Map<String, dynamic> e) {
    return {
      'name': _stringFrom(e['name']),
      'category': _stringFrom(e['category']),
      'equipment': _stringOrListJoin(e['equipment']),
      'primary_muscles': _stringOrListJoin(e['primary_muscles']),
      'secondary_muscles': _stringOrListJoin(e['secondary_muscles']),
      'instructions': _stringOrListJoin(e['instructions'], sep: '\n'),
      'level': _stringFrom(e['level']),
      'force_type': _stringFrom(e['force']),
      'mechanic': _stringFrom(e['mechanic']),
    };
  }

  static Map<String, dynamic> _toCardioSeedRow(Map<String, dynamic> e) {
    return {
      'name': _stringFrom(e['name']),
      'equipment': _stringOrListJoin(e['equipment']),
      'instructions': _stringOrListJoin(e['instructions'], sep: '\n'),
      'level': _stringFrom(e['level']),
    };
  }

  static String _stringFrom(dynamic v) => v?.toString() ?? '';

  static String _stringOrListJoin(dynamic v, {String sep = ', '}) {
    if (v == null) return '';
    if (v is List) return v.map((e) => e?.toString() ?? '').join(sep);
    return v.toString();
  }
}

class _ClassifiedExercises {
  final List<Map<String, dynamic>> strength;
  final List<Map<String, dynamic>> cardio;

  const _ClassifiedExercises({required this.strength, required this.cardio});
}
