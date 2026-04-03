import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../error/app_exception.dart';

/// 모든 AI 서버 통신을 중앙 관리하는 네트워크 클라이언트.
///
/// raw HTTP 예외를 [AppException] 계층으로 변환하여
/// 서비스/UI 계층이 도메인 예외만 다루도록 보장한다.
class ApiClient {
  final AppConfig _config;
  final http.Client _httpClient;
  final Map<String, String> Function()? _extraHeaders;

  ApiClient(
    this._config, {
    http.Client? httpClient,
    Map<String, String> Function()? extraHeaders,
  })  : _httpClient = httpClient ?? http.Client(),
        _extraHeaders = extraHeaders;

  /// JSON POST 요청을 보내고 파싱된 응답을 반환한다.
  ///
  /// [path] 는 base URL 이후의 경로 (예: `/chat`, `/recommend`).
  /// [timeout] 을 명시하지 않으면 [AppConfig.defaultTimeout] 을 사용한다.
  ///
  /// 일부 프록시·게이트웨이는 본문에 정상 JSON(코치 답변·progression 등)을 실은 채
  /// HTTP 400 등 비정상 상태를 반환할 수 있다. 그 경우에도 본문이 유효한 AI 페이로드면
  /// [ServerException] 대신 파싱된 Map 을 반환한다.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${_config.apiBaseUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final extra = _extraHeaders?.call();
    if (extra != null) {
      headers.addAll(extra);
    }
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(timeout ?? _config.defaultTimeout);

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (ok) {
        try {
          return jsonDecode(utf8.decode(response.bodyBytes))
              as Map<String, dynamic>;
        } on FormatException catch (e) {
          throw ParseException(cause: e);
        }
      }

      final fallback = _tryDecodeJsonMap(response);
      if (fallback != null && _jsonContainsUsableAiPayload(fallback)) {
        return fallback;
      }

      throw ServerException(response.statusCode);
    } on AppException {
      rethrow;
    } on SocketException catch (e) {
      throw NetworkException(cause: e);
    } on TimeoutException catch (e) {
      throw ApiTimeoutException(cause: e);
    } on http.ClientException catch (e) {
      throw NetworkException(cause: e);
    }
  }

  static Map<String, dynamic>? _tryDecodeJsonMap(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
    return null;
  }

  /// 비정상 상태 코드 본문이라도 UI·서비스가 쓸 수 있는 필드가 있으면 true.
  static bool _jsonContainsUsableAiPayload(Map<String, dynamic> json) {
    final text = json['response'];
    if (text is String && text.trim().isNotEmpty) return true;
    if (json['progression'] is Map) return true;
    final routine = json['routine'];
    if (routine is Map && routine.isNotEmpty) return true;
    return false;
  }

  void dispose() => _httpClient.close();
}
