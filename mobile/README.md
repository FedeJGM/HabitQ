# HabitQ — app móvil

App Flutter de HabitQ (Android). Habla con el backend FastAPI y no guarda estado propio salvo el JWT (`flutter_secure_storage`) y los recordatorios locales.

## Estructura

```
lib/
├── main.dart, app_routes.dart
├── core/        # config (AppConfig), networking (ApiClient), theme, utils, widgets
└── features/    # auth, consent, onboarding, home, habits, profile, chat, activity
```

Cada pantalla recibe su servicio por constructor (con fallback al real) para poder testearla con fakes. Ver `../docs/architecture/overview.md`.

## Configuración

Los valores se inyectan en tiempo de ejecución desde el `.env` de la raíz (`API_BASE_URL`, `GOOGLE_CLIENT_ID`), leídos por `lib/core/config/app_config.dart`:

```
flutter pub get
flutter run --dart-define-from-file=../.env
```

La instalación del SDK, la generación de las carpetas nativas (`flutter create`) y los problemas de NDK están en el `README.md` de la raíz. Para probar en un celular físico sin cable, ver D-27 en `../docs/decisions.md`.

## Calidad

```
flutter analyze
flutter test
```

## Documentación

- Arquitectura: `../docs/architecture/overview.md`
- Casos de uso: `../docs/requirements/use-cases.md`
- Decisiones: `../docs/decisions.md`
