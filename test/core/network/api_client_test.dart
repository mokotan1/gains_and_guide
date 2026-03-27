import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import 'package:gains_and_guide/core/config/app_config.dart';
import 'package:gains_and_guide/core/error/app_exception.dart';
import 'package:gains_and_guide/core/network/api_client.dart';

void main() {
  const testConfig = AppConfig(
    apiBaseUrl: 'https://test.example.com',
    defaultTimeout: Duration(seconds: 5),
  );

  ApiClient _createClient(http.Client mockHttp) {
    return ApiClient(testConfig, httpClient: mockHttp);
  }

  group('ApiClient.post', () {
    test('200 정상 응답 → 파싱된 Map 반환', () async {
      final mockHttp = http_testing.MockClient((_) async {
        return http.Response(
          jsonEncode({'response': 'ok', 'value': 42}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = _createClient(mockHttp);
      final result = await client.post('/chat', {'message': 'hello'});

      expect(result['response'], 'ok');
      expect(result['value'], 42);
    });

    test('500 서버 에러 → ServerException throw', () async {
      final mockHttp = http_testing.MockClient((_) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = _createClient(mockHttp);

      expect(
        () => client.post('/chat', {'message': 'hello'}),
        throwsA(isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        )),
      );
    });

    test('404 Not Found → ServerException(404) throw', () async {
      final mockHttp = http_testing.MockClient((_) async {
        return http.Response('Not Found', 404);
      });

      final client = _createClient(mockHttp);

      expect(
        () => client.post('/unknown', {}),
        throwsA(isA<ServerException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        )),
      );
    });

    test('SocketException → NetworkException throw', () async {
      final mockHttp = http_testing.MockClient((_) async {
        throw const SocketException('Connection refused');
      });

      final client = _createClient(mockHttp);

      expect(
        () => client.post('/chat', {}),
        throwsA(isA<NetworkException>()),
      );
    });

    test('타임아웃 → ApiTimeoutException throw', () async {
      final mockHttp = http_testing.MockClient((_) async {
        await Future.delayed(const Duration(seconds: 10));
        return http.Response('{}', 200);
      });

      final client = _createClient(mockHttp);

      expect(
        () => client.post('/chat', {}, timeout: const Duration(milliseconds: 50)),
        throwsA(isA<ApiTimeoutException>()),
      );
    });

    test('잘못된 JSON 응답 → ParseException throw', () async {
      final mockHttp = http_testing.MockClient((_) async {
        return http.Response('this is not json{{{', 200);
      });

      final client = _createClient(mockHttp);

      expect(
        () => client.post('/chat', {}),
        throwsA(isA<ParseException>()),
      );
    });

    test('요청 URL에 baseUrl + path 가 올바르게 결합됨', () async {
      Uri? capturedUri;
      final mockHttp = http_testing.MockClient((request) async {
        capturedUri = request.url;
        return http.Response('{"ok": true}', 200);
      });

      final client = _createClient(mockHttp);
      await client.post('/recommend', {'data': 1});

      expect(capturedUri?.toString(), 'https://test.example.com/recommend');
    });

    test('요청 body가 JSON으로 올바르게 인코딩됨', () async {
      String? capturedBody;
      final mockHttp = http_testing.MockClient((request) async {
        capturedBody = request.body;
        return http.Response('{"ok": true}', 200);
      });

      final client = _createClient(mockHttp);
      await client.post('/chat', {'user_id': 'test', 'message': 'hi'});

      final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(decoded['user_id'], 'test');
      expect(decoded['message'], 'hi');
    });

    test('모든 AppException 하위 타입의 userMessage가 비어있지 않음', () {
      final exceptions = [
        const NetworkException(),
        ServerException(500),
        const ApiTimeoutException(),
        const ParseException(),
      ];

      for (final e in exceptions) {
        expect(e.userMessage.isNotEmpty, true,
            reason: '${e.runtimeType}.userMessage should not be empty');
        expect(e.message.isNotEmpty, true,
            reason: '${e.runtimeType}.message should not be empty');
      }
    });
  });
}
