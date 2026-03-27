import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';

const _kTokenKey = 'api_bearer_token';
const _kSubjectKey = 'api_user_subject';

/// 서버 발급 JWT(또는 레거시 로컬 subject)를 보관하고 API 헤더를 제공한다.
///
/// [initialize] 는 [runApp] 전에 한 번 호출해야 한다.
class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _uuid = Uuid();

  String _subject = '';
  String? _token;

  String get subject => _subject;

  bool get hasBearer => _token != null && _token!.isNotEmpty;

  Map<String, String>? get authorizationHeader {
    if (!hasBearer) return null;
    return {'Authorization': 'Bearer $_token'};
  }

  /// [AppConfig.apiBaseUrl] 기준으로 익명 토큰을 발급받거나 로컬 subject 를 사용한다.
  Future<void> initialize(AppConfig config) async {
    try {
      final storedToken = await _storage.read(key: _kTokenKey);
      final storedSubject = await _storage.read(key: _kSubjectKey);
      if (storedToken != null &&
          storedToken.isNotEmpty &&
          storedSubject != null &&
          storedSubject.isNotEmpty) {
        _token = storedToken;
        _subject = storedSubject;
        return;
      }
    } on Object catch (e, st) {
      debugPrint('AuthSession: secure storage unavailable ($e)\n$st');
      _token = null;
      _subject = 'local_${_uuid.v4()}';
      return;
    }

    final uri = Uri.parse('${config.apiBaseUrl}/auth/anonymous');
    try {
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(config.defaultTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        final sub = data['subject'] as String?;
        if (token != null &&
            token.isNotEmpty &&
            sub != null &&
            sub.isNotEmpty) {
          _token = token;
          _subject = sub;
          try {
            await _storage.write(key: _kTokenKey, value: token);
            await _storage.write(key: _kSubjectKey, value: sub);
          } on Object catch (_) {}
          return;
        }
      }
    } on Object catch (e, st) {
      debugPrint('AuthSession: anonymous token failed: $e\n$st');
    }

    _useLocalSubjectOnly(null);
  }

  void _useLocalSubjectOnly(String? storedSubject) {
    _token = null;
    _subject = (storedSubject != null && storedSubject.isNotEmpty)
        ? storedSubject
        : 'local_${_uuid.v4()}';
    try {
      _storage.delete(key: _kTokenKey);
      _storage.write(key: _kSubjectKey, value: _subject);
    } on Object catch (_) {
      // 테스트·플러그인 미초기화 환경에서는 무시
    }
  }
}
