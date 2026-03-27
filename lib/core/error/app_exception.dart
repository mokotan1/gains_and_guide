/// 앱 전역에서 사용하는 도메인 예외 계층.
///
/// [userMessage] 는 최종 사용자에게 노출 가능한 한국어 메시지이며,
/// [message] 는 디버깅/로깅 전용 영문 메시지이다.
sealed class AppException implements Exception {
  final String message;
  final String userMessage;
  final Object? cause;

  const AppException({
    required this.message,
    required this.userMessage,
    this.cause,
  });

  @override
  String toString() => '$runtimeType: $message';
}

/// 네트워크 연결 자체가 불가능한 경우 (Wi-Fi/데이터 꺼짐, DNS 실패 등).
class NetworkException extends AppException {
  const NetworkException({super.cause})
      : super(
          message: 'Network connection failed',
          userMessage: '네트워크 연결을 확인해주세요.',
        );
}

/// 서버가 2xx 이외의 상태 코드를 반환한 경우.
class ServerException extends AppException {
  final int statusCode;

  ServerException(this.statusCode, {super.cause})
      : super(
          message: 'Server responded with status $statusCode',
          userMessage: '서버에 일시적인 문제가 발생했습니다. '
              '잠시 후 다시 시도해주세요.',
        );
}

/// 요청이 지정된 시간 내에 완료되지 않은 경우.
class ApiTimeoutException extends AppException {
  const ApiTimeoutException({super.cause})
      : super(
          message: 'Request timed out',
          userMessage: '서버 응답이 지연되고 있습니다. '
              '잠시 후 다시 시도해주세요.',
        );
}

/// 서버 응답을 파싱하는 데 실패한 경우.
class ParseException extends AppException {
  const ParseException({super.cause})
      : super(
          message: 'Response parsing failed',
          userMessage: '데이터 처리 중 오류가 발생했습니다.',
        );
}
