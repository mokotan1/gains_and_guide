/// 빌드 타임에 주입되는 앱 전역 설정.
///
/// 기본 [API_BASE_URL] 은 EC2에 연결된 Elastic IP 기준이다. IP를 바꾸면
/// `--dart-define` 으로 덮어쓰거나 이 기본값을 수정한다.
///
/// `--dart-define` 으로 값을 주입하며, 런타임에 변경 불가.
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://... --dart-define=API_TIMEOUT_SECONDS=30
/// ```
class AppConfig {
  final String apiBaseUrl;
  final Duration defaultTimeout;

  const AppConfig({
    required this.apiBaseUrl,
    required this.defaultTimeout,
  });

  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://15.134.24.132:8000',
    );
    const timeoutSeconds = int.fromEnvironment(
      'API_TIMEOUT_SECONDS',
      defaultValue: 30,
    );

    return AppConfig(
      apiBaseUrl: baseUrl,
      defaultTimeout: Duration(seconds: timeoutSeconds),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          runtimeType == other.runtimeType &&
          apiBaseUrl == other.apiBaseUrl &&
          defaultTimeout == other.defaultTimeout;

  @override
  int get hashCode => Object.hash(apiBaseUrl, defaultTimeout);
}
