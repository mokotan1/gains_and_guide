/// 빌드 타임에 주입되는 앱 전역 설정.
///
/// 기본 [API_BASE_URL] 은 Render 무료 티어 HTTPS 엔드포인트다.
/// 로컬/다른 호스트는 `--dart-define=API_BASE_URL=...` 로 덮어쓴다.
///
/// `--dart-define` 으로 값을 주입하며, 런타임에 변경 불가.
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://... --dart-define=API_TIMEOUT_SECONDS=30
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// Supabase 동기화는 [supabaseConfigured] 이 true 이고, Supabase Auth 세션이 있을 때만
/// `cardio_history` 원격 반영이 동작한다 (RLS `auth.uid()`).
class AppConfig {
  final String apiBaseUrl;
  final Duration defaultTimeout;

  /// 비어 있으면 Supabase 클라이언트를 초기화하지 않는다.
  final String supabaseUrl;

  /// 비어 있으면 Supabase 클라이언트를 초기화하지 않는다.
  final String supabaseAnonKey;

  const AppConfig({
    required this.apiBaseUrl,
    required this.defaultTimeout,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  bool get supabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  factory AppConfig.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://gains-and-guide-1.onrender.com',
    );
    const timeoutSeconds = int.fromEnvironment(
      'API_TIMEOUT_SECONDS',
      defaultValue: 30,
    );
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const supabaseAnonKey =
        String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

    return AppConfig(
      apiBaseUrl: baseUrl,
      defaultTimeout: Duration(seconds: timeoutSeconds),
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          runtimeType == other.runtimeType &&
          apiBaseUrl == other.apiBaseUrl &&
          defaultTimeout == other.defaultTimeout &&
          supabaseUrl == other.supabaseUrl &&
          supabaseAnonKey == other.supabaseAnonKey;

  @override
  int get hashCode =>
      Object.hash(apiBaseUrl, defaultTimeout, supabaseUrl, supabaseAnonKey);
}
