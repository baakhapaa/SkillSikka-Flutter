# SkillSikka Flutter

SkillSikka is a Flutter app organized by feature. Shared infrastructure lives
under `lib/core`, while user-facing slices live under `lib/features`.

## Architecture

- `lib/core/config`: compile-time environment and API configuration
- `lib/core/network`: the shared Dio client and authentication token provider
- `lib/core/routing`: the application-level go_router configuration
- `lib/features/<feature>`: feature presentation, domain, data, and providers
- `lib/app.dart`: Material 3 app composition and shared providers

Riverpod is initialized in `lib/main.dart`. Add feature providers inside their
feature directory and expose new destinations through the existing router
provider. Keep API repositories feature-owned and inject the shared `dioProvider`.

## Environments

Environment values are compile-time defines. `APP_ENV` accepts `development`,
`staging`, or `production`. `API_BASE_URL` overrides the configured URL and
should be supplied by each deployment pipeline.

```text
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://<staging-host>/api
flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://<production-host>/api
```

The checked-in defaults are local development plus placeholder SkillSikka
staging and production hosts. Replace them with the real backend URLs in the
deployment command or CI configuration; no credentials belong in Dart code.

## Verification

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```
