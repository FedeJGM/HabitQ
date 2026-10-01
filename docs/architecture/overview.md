# Arquitectura de HabitQ — estado implementado

> Este documento describe la arquitectura **tal como está implementada** al día de hoy. Para el plan completo del MVP (incluyendo lo que todavía no está construido), ver [`../../HABITQ_DEVELOPMENT_PLAN.md`](../../HABITQ_DEVELOPMENT_PLAN.md). Para diagramas visuales, ver [`../diagrams/`](../diagrams/).

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

La Fase 3 del plan (RAG) está completa: ingesta (PDF → texto → limpieza → chunking → embeddings → Postgres, `services/ingestion_service.py`), retrieval (similitud coseno en Python — `pgvector` no está disponible en el entorno de desarrollo, embeddings como `ARRAY(FLOAT)`, `docs/decisions.md` D-12), integración con Gemini (`services/llm_service.py`), orquestación y persistencia de conversaciones (`services/chat_service.py`, `POST /chat`), y personalización con perfil/hábitos cuando es relevante (D-15). Ver [`../../ingestion/README.md`](../../ingestion/README.md).

## Backend (`backend/app/`)

Capas, de afuera hacia adentro:

- **`api/routes/`** — un router por recurso (`auth.py`, `profile.py`, `habits.py`), montados en `main.py`.
- **`api/deps.py`** — dependencias de FastAPI compartidas: `get_db` (sesión SQLAlchemy) y `get_current_user` (decodifica el JWT, carga el `User`, lanza 401 si es inválido/expirado o el usuario no existe).
- **`services/`** — lógica de negocio por recurso (`auth_service.py`, `profile_service.py`, `habit_record_service.py`, `ingestion_service.py`, `retrieval_service.py`, `llm_service.py`, `chat_service.py`), sin conocimiento de HTTP.
- **`models/`** — modelos SQLAlchemy (`User`, `Profile`, `HabitRecord`, `ScientificDocument`, `DocumentChunk`, `Conversation`, `Message`).
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
| POST | `/chat` | Sí | Retrieval + Gemini (con personalización) en una conversación, nueva o existente; persiste ambos mensajes de forma atómica |
| GET | `/chat/conversations` | Sí | Lista las conversaciones del usuario, más reciente primero |
| GET | `/chat/conversations/{id}/messages` | Sí | Mensajes de una conversación propia, orden cronológico (404 si no existe o es de otro usuario) |
| DELETE | `/chat/conversations/{id}` | Sí | Borra la conversación y sus mensajes (404 si no existe o es de otro usuario) |

**Limitación conocida y documentada:** el JWT es *stateless* y no existe tabla de sesiones/blacklist en el modelo de datos del plan. `POST /auth/logout` no puede invalidar un token todavía válido — solo exige que el llamador presente uno. La sesión termina realmente cuando el cliente descarta el token localmente (ver abajo) o cuando expira (24h, configurable en `.env`).

## Mobile (`mobile/lib/`)

```text
lib/
├── core/
│   ├── config/       # AppConfig — lee API_BASE_URL y GOOGLE_CLIENT_ID de --dart-define-from-file
│   ├── networking/   # ApiClient (get/post/put/getList + JWT automático), TokenStorage (read/write/delete)
│   ├── utils/        # jwt.dart — decodifica el exp del JWT (sin verificar firma) para el refresh proactivo
│   └── theme/        # AppColors, AppTheme
├── features/
│   ├── auth/         # LoginScreen, AuthService (Google Sign-In + JWT + refresh proactivo)
│   ├── consent/      # ConsentScreen, ConsentStorage (local, por dispositivo)
│   ├── onboarding/    # OnboardingScreen (perfil), OnboardingHabitsScreen (9 preguntas), OnboardingService
│   ├── home/         # HomeScreen (hub de navegación)
│   ├── habits/       # HabitsScreen (ver/editar), HabitsService, habit_questions.dart (metadata compartida)
│   ├── profile/      # ProfileScreen (ver/editar), ProfileService, profile_options.dart (metadata compartida)
│   └── chat/         # ChatScreen (conversación en vivo), ConversationHistoryScreen, ChatService
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

Desde Home: navegación a Mis Hábitos, Perfil y Chat (las tres reales). Desde el Chat, un ícono en el `AppBar` navega al historial de conversaciones.

### Chat (RAG)

`ChatScreen` empieza vacía (nueva conversación) salvo que se abra con un `conversationId` — vía el parámetro del constructor (tests) o el argumento de la ruta `pushNamed` (navegación real desde `ConversationHistoryScreen`) — en cuyo caso precarga los mensajes existentes (`ChatService.fetchMessages`) antes de aceptar el primer mensaje nuevo. El envío es optimista: el mensaje del usuario se muestra antes de esperar la respuesta. El `conversationId` que devuelve `POST /chat` se reutiliza para los mensajes siguientes dentro de la misma sesión de pantalla, así el backend los mantiene en la misma conversación. Cada respuesta del asistente muestra sus fuentes (título + organización) debajo de la burbuja. `ConversationHistoryScreen` lista `GET /chat/conversations`, permite reabrir (navega a `ChatScreen` con el `conversationId`) o borrar (`DELETE`, sin recargar toda la lista).

### Refresh proactivo del JWT

`HabitQApp` (`main.dart`) implementa `WidgetsBindingObserver` y llama a `AuthService.refreshTokenIfNeeded()` en `initState` y cada vez que la app vuelve a primer plano (`AppLifecycleState.resumed`). Si el JWT guardado vence en menos de 60 minutos, se reemite vía `POST /auth/refresh` y se sobrescribe en `TokenStorage`. Es proactivo y no reactivo (no hay retry-on-401) porque `/auth/refresh` exige un JWT todavía válido — uno ya expirado no se puede recuperar reintentando (ver D-09 y D-13 en `docs/decisions.md`).

### Convención de inyección de dependencias

Todo widget con lógica async (`OnboardingScreen`, `HabitsScreen`, `ProfileScreen`, `HomeScreen`, `ConsentScreen`, etc.) acepta su servicio por constructor (`this.habitsService`, `this.profileService`, ...) con fallback a la construcción real (`?? HabitsService()`). Esto permite testear cada pantalla con un fake sin tocar red ni almacenamiento real.

**Excepción deliberada:** código que depende directamente de `FlutterSecureStorage` (`AuthService.signOut()`, `TokenStorage`, `ConsentStorage`) no tiene test unitario que ejercite su cuerpo real. Se comprobó empíricamente que una llamada real a `FlutterSecureStorage` sin mock **cuelga indefinidamente** un `testWidgets()` (no lanza excepción). Estas piezas solo se verifican vía los fakes que las sobreescriben por completo en los tests de las pantallas que las consumen.

## Base de datos

7 tablas hoy (migraciones `0001`–`0005`): `users`, `profiles`, `habit_records`, `scientific_documents`, `document_chunks` (con `embedding` como `ARRAY(FLOAT)`, no `Vector` — ver D-12 en `docs/decisions.md`), `conversations`, `messages`. Todo el modelo de datos del plan (sección 8) está implementado. Ver [`../diagrams/er-diagram.md`](../diagrams/er-diagram.md) para el ER completo.
