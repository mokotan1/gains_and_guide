import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';

/// DB 초기화 및 운동 카탈로그 시딩 전용 (단일 책임)
class DatabaseBootstrap {
  DatabaseBootstrap._();

  static const String _exercisesAssetPath = 'assets/data/exercises.json';

  /// DB 접속 확보 후 카탈로그가 비어 있으면 시딩 수행
  static Future<void> run(DatabaseHelper dbHelper) async {
    if (!await dbHelper.isExerciseCatalogEmpty()) return;
    try {
      final exercisesToSeed = await _loadAndParseExercisesJson();
      await dbHelper.seedExerciseCatalog(exercisesToSeed);
      debugPrint('운동 카탈로그 시딩 완료: ${exercisesToSeed.length}개 운동');
    } catch (e, st) {
      debugPrint('운동 카탈로그 시딩 실패: $e');
      if (kDebugMode) debugPrint('$st');
    }
  }

  static Future<List<Map<String, dynamic>>> _loadAndParseExercisesJson() async {
    final String raw = await rootBundle.loadString(_exercisesAssetPath);
    final Object? decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('exercises.json must be a JSON object');
    }
    final exercisesJson = decoded['exercises'];
    if (exercisesJson is! List) {
      throw FormatException('exercises.json must contain "exercises" array');
    }
    return exercisesJson.map((e) => _toSeedRow(e)).toList();
  }

  static Map<String, dynamic> _toSeedRow(dynamic e) {
    if (e is! Map<String, dynamic>) {
      throw FormatException('Each exercise entry must be an object');
    }
    return {
      'name': _stringFrom(e['name']),
      'category': _stringFrom(e['category']),
      'equipment': _stringOrListJoin(e['equipment']),
      'primary_muscles': _stringOrListJoin(e['primary_muscles']),
      'instructions': _stringOrListJoin(e['instructions'], sep: '\n'),
    };
  }

  static String _stringFrom(dynamic v) =>
      v?.toString() ?? '';

  static String _stringOrListJoin(dynamic v, {String sep = ', '}) {
    if (v == null) return '';
    if (v is List) return v.map((e) => e?.toString() ?? '').join(sep);
    return v.toString();
  }
}
