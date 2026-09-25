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

  /// The backend confirms a **`/api/v1/`** prefix, so it is part of every URL
  /// here. The staging and production *hosts* are still unconfirmed on both
  /// sides — they are placeholders, and `v1` is the only segment of them that is
  /// settled. Override with `--dart-define=API_BASE_URL=...` when they are known.
  ///
  /// **`127.0.0.1` is the host machine only on web, desktop and the iOS
  /// simulator.** An Android emulator has its own loopback, so `127.0.0.1` there
  /// is the emulator itself and every request fails with `Connection refused`
  /// (errno 111) — which reads like the backend being down when it is not. Use
  /// the emulator's alias for the host instead:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  /// ```
  ///
  /// `10.0.2.2` is routed to the host's *loopback*, so Django's default
  /// `runserver` is reachable through it.
  ///
  /// **A physical device is a different problem, and `10.0.2.2` is meaningless
  /// there** — it is just a private address nothing routes to, so the failure
  /// changes from `Connection refused` to a **connect timeout**. Tunnel the port
  /// instead of addressing the host over the network:
  ///
  /// ```
  /// adb reverse tcp:8000 tcp:8000
  /// flutter run          // the default below already points at 127.0.0.1:8000
  /// ```
  ///
  /// That forwards the *device's* `127.0.0.1:8000` to the host, so the default
  /// base URL works unchanged — and requests arrive with `Host: 127.0.0.1:8000`,
  /// which Django's default `ALLOWED_HOSTS` accepts under `DEBUG`, unlike
  /// `10.0.2.2`. It must be re-run after the device reconnects.
  ///
  /// The alternative is the host's LAN address, which additionally needs the
  /// server bound beyond loopback and that address in `ALLOWED_HOSTS`:
  /// `python manage.py runserver 0.0.0.0:8000`.
  static const _defaultUrls = <AppEnvironment, String>{
    AppEnvironment.development: 'http://127.0.0.1:8000/api/v1',
    AppEnvironment.staging: 'https://staging-api.skillsikka.com/api/v1',
    AppEnvironment.production: 'https://api.skillsikka.com/api/v1',
  };
}
