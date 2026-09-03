enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromName(String value) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == value.toLowerCase(),
      orElse: () => AppEnvironment.development,
    );
  }
}

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  factory AppConfig.fromDefines() {
    final environment = AppEnvironment.fromName(
      const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    );
    final configuredUrl = const String.fromEnvironment('API_BASE_URL');

    return AppConfig(
      environment: environment,
      apiBaseUrl: configuredUrl.isNotEmpty
          ? configuredUrl
          : _defaultUrls[environment]!,
    );
  }

  final AppEnvironment environment;
  final String apiBaseUrl;

  static const _defaultUrls = <AppEnvironment, String>{
    AppEnvironment.development: 'http://localhost:8000/api',
    AppEnvironment.staging: 'https://staging-api.skillsikka.com/api',
    AppEnvironment.production: 'https://api.skillsikka.com/api',
  };
}
