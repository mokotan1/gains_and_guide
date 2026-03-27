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

  ApiClient(
    this._config, {
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// JSON POST 요청을 보내고 파싱된 응답을 반환한다.
  ///
  /// [path] 는 base URL 이후의 경로 (예: `/chat`, `/recommend`).
  /// [timeout] 을 명시하지 않으면 [AppConfig.defaultTimeout] 을 사용한다.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${_config.apiBaseUrl}$path');
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout ?? _config.defaultTimeout);

      if (response.statusCode != 200) {
        throw ServerException(response.statusCode);
      }

      try {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } on FormatException catch (e) {
        throw ParseException(cause: e);
      }
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

  void dispose() => _httpClient.close();
}
