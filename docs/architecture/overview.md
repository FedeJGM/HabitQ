# Arquitectura de HabitQ — estado implementado

> Este documento describe la arquitectura **tal como está implementada** al día de hoy (rama `feature/google-login`). Para el plan completo del MVP (incluyendo lo que todavía no está construido), ver [`../../HABITQ_DEVELOPMENT_PLAN.md`](../../HABITQ_DEVELOPMENT_PLAN.md). Para diagramas visuales, ver [`../diagrams/`](../diagrams/).

## Componentes

```text
┌──────────────────┐        HTTPS/REST        ┌──────────────────┐        SQL        ┌──────────────┐
│   Flutter app     │ ────────────────────────▶ │    FastAPI       │ ─────────────────▶ │  PostgreSQL   │
│   (mobile/)        │ ◀──────────────────────── │    (backend/)    │ ◀───────────────── │   (habitq)    │
└──────────────────┘        JSON + JWT          └──────────────────┘                    └──────────────┘
        │
        │ OAuth (ID token)
        ▼
┌──────────────────┐
│  Google Sign-In    │
└──────────────────┘
```

No hay más servicios todavía: no hay RAG, no hay pgvector poblado, no hay LLM integrado (Fase 3 del plan, sin empezar).

## Backend (`backend/app/`)

Capas, de afuera hacia adentro:

- **`api/routes/`** — un router por recurso (`auth.py`, `profile.py`, `habits.py`), montados en `main.py`.
- **`api/deps.py`** — dependencias de FastAPI compartidas: `get_db` (sesión SQLAlchemy) y `get_current_user` (decodifica el JWT, carga el `User`, lanza 401 si es inválido/expirado o el usuario no existe).
- **`services/`** — lógica de negocio por recurso (`auth_service.py`, `profile_service.py`, `habit_record_service.py`), sin conocimiento de HTTP.
- **`models/`** — modelos SQLAlchemy (`User`, `Profile`, `HabitRecord`).
- **`schemas/`** — modelos Pydantic de entrada/salida (validación + serialización).
- **`core/`** — configuración (`config.py`, lee `.env` de la raíz del repo) y JWT (`security.py`).
- **`db/`** — engine/sesión (`session.py`) y `Base` declarativa (`base.py`).

### Regla de seguridad aplicada consistentemente

Ningún endpoint privado confía en un `user_id` enviado por el cliente. Todos obtienen el usuario desde el JWT vía `get_current_user` (plan, sección 10). `PUT /habits/{id}` además verifica que el registro pertenezca al usuario autenticado antes de modificarlo, devolviendo 404 (no 403) si no es así, para no filtrar la existencia de registros ajenos.

### Endpoints actuales

| Método | Ruta | Protegido | Descripción |
|---|---|---|---|
| GET | `/health` | No | Liveness check |
| POST | `/auth/google` | No | Login: valida el ID token de Google, crea/recupera el usuario, emite JWT HabitQ |
| GET | `/auth/me` | Sí | Usuario autenticado actual |
| POST | `/auth/onboarding-complete` | Sí | Marca `onboarding_completed = true` |
| POST | `/auth/refresh` | Sí | Reemite un JWT nuevo a partir de uno todavía válido |
| POST | `/auth/logout` | Sí | 204 sin body — ver limitación abajo |
| GET | `/profile` | Sí | Perfil del usuario (404 si no existe todavía) |
| PUT | `/profile` | Sí | Crea o actualiza el perfil (upsert) |
| GET | `/habits` | Sí | Lista todos los `habit_records` del usuario |
| POST | `/habits` | Sí | Crea un nuevo registro de hábito |
| PUT | `/habits/{habit_id}` | Sí | Actualiza un registro existente propio |

**Limitación conocida y documentada:** el JWT es *stateless* y no existe tabla de sesiones/blacklist en el modelo de datos del plan. `POST /auth/logout` no puede invalidar un token todavía válido — solo exige que el llamador presente uno. La sesión termina realmente cuando el cliente descarta el token localmente (ver abajo) o cuando expira (24h, configurable en `.env`).

## Mobile (`mobile/lib/`)

```text
lib/
├── core/
│   ├── config/       # AppConfig — lee API_BASE_URL y GOOGLE_CLIENT_ID de --dart-define-from-file
│   ├── networking/   # ApiClient (get/post/put/getList + JWT automático), TokenStorage
│   └── theme/        # AppColors, AppTheme
├── features/
│   ├── auth/         # LoginScreen, AuthService (Google Sign-In + JWT)
│   ├── consent/      # ConsentScreen, ConsentStorage (local, por dispositivo)
│   ├── onboarding/    # OnboardingScreen (perfil), OnboardingHabitsScreen (9 preguntas), OnboardingService
│   ├── home/         # HomeScreen (hub de navegación)
│   ├── habits/       # HabitsScreen (ver/editar), HabitsService, habit_questions.dart (metadata compartida)
│   └── profile/      # ProfileScreen (ver/editar), ProfileService, profile_options.dart (metadata compartida)
└── app_routes.dart   # tabla central de rutas nombradas
```

### Flujo de navegación implementado

```text
Login ──(sign-in exitoso)──▶ ¿consentimiento local aceptado?
                                  │ no                    │ sí
                                  ▼                        ▼
                             Consent ──▶ ¿onboarding_completed?      ¿onboarding_completed?
                                              │ no        │ sí            │ no        │ sí
                                              ▼            ▼               ▼            ▼
                                        Onboarding       Home        Onboarding       Home
                                        (perfil)                     (perfil)
                                              │
                                              ▼
                                    OnboardingHabits (9 preguntas)
                                              │
                                              ▼
                                            Home
```

Desde Home: navegación a Mis Hábitos y Perfil (ambas reales). "Chat con HabitQ" queda como "Próximamente" — es lo único de la Fase 3 sin construir.

### Convención de inyección de dependencias

Todo widget con lógica async (`OnboardingScreen`, `HabitsScreen`, `ProfileScreen`, `HomeScreen`, `ConsentScreen`, etc.) acepta su servicio por constructor (`this.habitsService`, `this.profileService`, ...) con fallback a la construcción real (`?? HabitsService()`). Esto permite testear cada pantalla con un fake sin tocar red ni almacenamiento real.

**Excepción deliberada:** código que depende directamente de `FlutterSecureStorage` (`AuthService.signOut()`, `TokenStorage`, `ConsentStorage`) no tiene test unitario que ejercite su cuerpo real. Se comprobó empíricamente que una llamada real a `FlutterSecureStorage` sin mock **cuelga indefinidamente** un `testWidgets()` (no lanza excepción). Estas piezas solo se verifican vía los fakes que las sobreescriben por completo en los tests de las pantallas que las consumen.

## Base de datos

3 tablas hoy (migraciones `0001`–`0003`): `users`, `profiles`, `habit_records`. Ver [`../diagrams/er-diagram.md`](../diagrams/er-diagram.md) para el ER completo, incluyendo las tablas planeadas para RAG que todavía no existen.
