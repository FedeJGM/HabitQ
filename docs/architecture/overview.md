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

Servicios externos además de Google Sign-In: **Gemini** (respuestas del chat), **Europe PMC** (búsqueda y PDFs del panel de administración) y **Hugging Face Hub** (descarga única del modelo de embeddings; después se carga desde disco).

La Fase 3 del plan (RAG) está completa: ingesta (PDF → texto → limpieza → chunking → embeddings → Postgres, `services/ingestion_service.py`), retrieval (similitud coseno en Python — `pgvector` no está disponible en el entorno de desarrollo, embeddings como `ARRAY(FLOAT)`, `docs/decisions.md` D-12), integración con Gemini (`services/llm_service.py`), orquestación y persistencia de conversaciones (`services/chat_service.py`, `POST /chat`), y personalización con perfil/hábitos cuando es relevante (D-15). Los embeddings los genera `intfloat/multilingual-e5-small` (`services/embedding_service.py`, D-20). La base de conocimiento se amplía desde un panel de administración ([abajo](#administración-de-la-base-de-conocimiento)). Ver [`../../ingestion/README.md`](../../ingestion/README.md).

## Backend (`backend/app/`)

Capas, de afuera hacia adentro:

- **`api/routes/`** — un router por recurso (`auth.py`, `profile.py`, `habits.py`, `chat.py`, `admin.py`), montados en `main.py`.
- **`api/deps.py`** — dependencias de FastAPI compartidas: `get_db` (sesión SQLAlchemy), `get_current_user` (decodifica el JWT, carga el `User`, lanza 401 si es inválido/expirado o el usuario no existe), `require_admin` (sobre `get_current_user`: 403 si el correo no está en `ADMIN_EMAILS`) y `get_embedding_model` (carga el modelo una vez y lo reutiliza).
- **`services/`** — lógica de negocio por recurso sin conocimiento de HTTP. Cuentas y perfil: `auth_service.py`, `google_auth.py`, `profile_service.py`, `habit_record_service.py`. RAG y chat: `embedding_service.py`, `ingestion_service.py`, `retrieval_service.py`, `llm_service.py`, `chat_service.py`. Descubrimiento de documentos: `discovery_service.py` (Europe PMC), `candidate_service.py` (ejecuciones, revisión y recuperación), `download_service.py` (PDF) y `candidate_ingestion_service.py` (orquesta descarga + indexación).
- **`models/`** — modelos SQLAlchemy (`User`, `Profile`, `HabitRecord`, `ScientificDocument`, `DocumentChunk`, `Conversation`, `Message`, `DiscoveryRun`, `DocumentCandidate`).
- **`schemas/`** — modelos Pydantic de entrada/salida (validación + serialización).
- **`core/`** — configuración (`config.py`, lee `.env` de la raíz del repo) y JWT (`security.py`).
- **`db/`** — engine/sesión (`session.py`) y `Base` declarativa (`base.py`).
- **`web/`** — `admin.html`, el panel de administración (HTML + JS sin framework, servido por `GET /admin`).

### Regla de seguridad aplicada consistentemente

Ningún endpoint privado confía en un `user_id` enviado por el cliente. Todos obtienen el usuario desde el JWT vía `get_current_user` (plan, sección 10). `PUT /habits/{id}` además verifica que el registro pertenezca al usuario autenticado antes de modificarlo, devolviendo 404 (no 403) si no es así, para no filtrar la existencia de registros ajenos. Lo mismo hacen `PUT /tasks/{id}`, `DELETE /tasks/{id}` y `PUT /tasks/{id}/progress`: una tarea ajena, inexistente o ya archivada responde 404.

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
| GET | `/tasks/catalog` | Sí | Tareas del catálogo para el objetivo del perfil (`key`, `label`, `target`, `unit`, `step`); lista vacía si no hay perfil |
| GET | `/tasks?day=YYYY-MM-DD` | Sí | Tareas activas del usuario ese día con `progress`, `completed` y `archived`. Un día pasado solo es de lectura (lo hace cumplir la app) |
| POST | `/tasks` | Sí | Activa una tarea del catálogo del objetivo (`task_key`, `reminder_time` opcional). 422 si no es del objetivo; 409 si ya está activa |
| PUT | `/tasks/{id}` | Sí | Cambia o quita (`null`) la hora del recordatorio (404 si no existe, es ajena o está archivada) |
| DELETE | `/tasks/{id}` | Sí | Archiva la tarea y conserva su historial (204) |
| PUT | `/tasks/{id}/progress` | Sí | Guarda el progreso de un día (`day`, `progress` de 0 a la meta); `day` debe estar a ±1 día de la fecha UTC del servidor |
| GET | `/tasks/stats?day=AAAA-MM-DD` | Sí | Cumplimiento de los 7 días que terminan en `day` (fecha local de la persona, a ±1 día de la fecha UTC; 422 si no): por día `active` y `completed`, promedio de las tareas con contador y el mejor día (D-28). Aplica las mismas reglas de visibilidad que `GET /tasks` |
| POST | `/chat` | Sí | Retrieval + Gemini (con personalización) en una conversación, nueva o existente; persiste ambos mensajes de forma atómica. Devuelve `sources` (título, organización, URL, autores, año, DOI y páginas recuperadas) y las guarda con el mensaje del asistente |
| GET | `/chat/conversations` | Sí | Lista las conversaciones del usuario, más reciente primero |
| GET | `/chat/conversations/{id}/messages` | Sí | Mensajes de una conversación propia, orden cronológico; cada uno trae sus `sources` (lista vacía si no tiene) (404 si no existe o es de otro usuario) |
| DELETE | `/chat/conversations/{id}` | Sí | Borra la conversación y sus mensajes (404 si no existe o es de otro usuario) |
| GET | `/admin` | No | Panel de administración (HTML estático; sus datos pasan por los endpoints protegidos de abajo) |
| POST | `/admin/discovery` | Admin | Busca 30 candidatos en Europe PMC para los dominios pedidos (los 7 por defecto) y los guarda como `pending` (201); 502 si Europe PMC no responde; 422 si un dominio no existe |
| GET | `/admin/candidates` | Admin | Lista candidatos; filtros opcionales `?status=` y `?run_id=`. Cada uno trae `stuck` (indexación interrumpida) |
| POST | `/admin/candidates/{id}/approve` | Admin | Aprueba un candidato (404 si no existe; 409 si ya se está indexando o se indexó) |
| POST | `/admin/candidates/{id}/reject` | Admin | Rechaza un candidato (mismos 404/409) |
| GET | `/admin/documents` | Admin | Lista los documentos indexados (`scientific_documents`, incluidos los cargados por CLI), del más nuevo al más antiguo, con `chunk_count`; filtro opcional `?domain=` |
| DELETE | `/admin/documents/{id}` | Admin | Elimina el documento y sus chunks en una transacción y marca como `rejected` el candidato `ingested` con el mismo DOI (204; 404 si no existe) |
| POST | `/admin/ingest` | Admin | Devuelve a la cola los candidatos bloqueados y encola en segundo plano la indexación de los aprobados (202 con `{queued, recovered}`) |

**Admin** = JWT válido **y** correo en `ADMIN_EMAILS`: 401 sin sesión, 403 si la cuenta no es administradora.

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
│   ├── activity/     # ActivityScreen (checklist diario), TasksService, ReminderService (+ LocalNotificationGateway sobre flutter_local_notifications)
│   ├── stats/        # StatsScreen (cumplimiento de 7 días con fl_chart y resumen de hábitos), StatsService
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

Desde Home: navegación a Mis Hábitos, Perfil y Chat (las tres reales). En Home, el chat es un botón único («Chat con HabitQ») hasta que existe alguna conversación; a partir de ahí son dos: «Continuar conversación» (abre la más reciente) y «Nuevo chat con HabitQ». Desde el Chat, un ícono en el `AppBar` navega al historial de conversaciones.

La barra inferior tiene cinco pestañas: Inicio, **Actividad**, **Estadísticas**, Chat y Perfil (D-23, D-28). Actividad es el checklist diario: franja semanal (hoy editable, días pasados en solo lectura), tareas con casilla o contador, botón del lápiz para elegir tareas de un catálogo por objetivo y recordatorios locales por tarea (D-24, D-25). Los recordatorios los programa el propio teléfono, sin servidor: `ReminderService` decide qué programar y `LocalNotificationGateway` habla con el plugin de notificaciones; al cerrar sesión se cancelan todos.

### Estadísticas

`StatsScreen` (D-28) muestra los últimos 7 días terminando hoy, con la fecha local de la persona. `StatsService.fetchStats` llama a `GET /tasks/stats?day=` y la pantalla dibuja con `fl_chart` las barras de cumplimiento por día (tareas completadas sobre tareas activas), el resumen «Hoy: X de Y tareas», el mejor día y el promedio de cada tarea con contador. Si ningún día tuvo tareas, muestra un mensaje con un botón hacia Actividad. Debajo, el resumen de hábitos es una lista de solo lectura por dominio con las respuestas actuales del cuestionario: reutiliza `HabitsService.fetchHabits` y las etiquetas de `habit_questions.dart`, empareja por dominio y clave, usa el registro más reciente cuando una pregunta tiene varios y muestra «Sin responder» si falta. Cada fuente falla por separado: un error al leer los hábitos no oculta los gráficos. La etiqueta de la barra inferior baja a 11 sp para que «Estadísticas» quepa en una pantalla de 360 dp con cinco pestañas.

### Chat (RAG)

`ChatScreen` empieza vacía (nueva conversación) salvo que se abra con un `conversationId` — vía el parámetro del constructor (tests) o el argumento de la ruta `pushNamed` (navegación real desde `ConversationHistoryScreen`) — en cuyo caso precarga los mensajes existentes (`ChatService.fetchMessages`) antes de aceptar el primer mensaje nuevo. El envío es optimista: el mensaje del usuario se muestra antes de esperar la respuesta. El `conversationId` que devuelve `POST /chat` se reutiliza para los mensajes siguientes dentro de la misma sesión de pantalla, así el backend los mantiene en la misma conversación. Cada respuesta del asistente muestra debajo de la burbuja un bloque «Referencias»: una línea por documento (autores, año, título, revista y páginas) con su enlace DOI —o la URL de origen— tocable, que abre el navegador (`url_launcher`); si no se puede abrir, avisa con un `SnackBar`. Solo se aceptan enlaces `http(s)`, porque el valor viene de metadatos de terceros. Al reabrir una conversación desde el historial, cada respuesta conserva sus referencias. `ConversationHistoryScreen` lista `GET /chat/conversations`, permite reabrir (navega a `ChatScreen` con el `conversationId`) o borrar (`DELETE`, sin recargar toda la lista).

### Refresh proactivo del JWT

`HabitQApp` (`main.dart`) implementa `WidgetsBindingObserver` y llama a `AuthService.refreshTokenIfNeeded()` en `initState` y cada vez que la app vuelve a primer plano (`AppLifecycleState.resumed`). Si el JWT guardado vence en menos de 60 minutos, se reemite vía `POST /auth/refresh` y se sobrescribe en `TokenStorage`. Es proactivo y no reactivo (no hay retry-on-401) porque `/auth/refresh` exige un JWT todavía válido — uno ya expirado no se puede recuperar reintentando (ver D-09 y D-13 en `docs/decisions.md`).

### Convención de inyección de dependencias

Todo widget con lógica async (`OnboardingScreen`, `HabitsScreen`, `ProfileScreen`, `HomeScreen`, `ConsentScreen`, etc.) acepta su servicio por constructor (`this.habitsService`, `this.profileService`, ...) con fallback a la construcción real (`?? HabitsService()`). Esto permite testear cada pantalla con un fake sin tocar red ni almacenamiento real.

**Excepción deliberada:** código que depende directamente de `FlutterSecureStorage` (`TokenStorage`, `ConsentStorage`) no tiene test unitario que ejercite su cuerpo real. `AuthService.signOut()` sí se testea, porque `AuthService` recibe `GoogleSignIn` y el almacenamiento por constructor. Se comprobó empíricamente que una llamada real a `FlutterSecureStorage` sin mock **cuelga indefinidamente** un `testWidgets()` (no lanza excepción). Estas piezas solo se verifican vía los fakes que las sobreescriben por completo en los tests de las pantallas que las consumen.

## Administración de la base de conocimiento

Pipeline de dos pasos con una persona en el medio (decisiones D-17 y D-21):

```text
POST /admin/discovery ──▶ Europe PMC ──▶ document_candidates (pending)
        │
        ▼  el admin abre cada enlace y decide
approve / reject ──▶ approved | rejected
        │
        ▼
POST /admin/ingest ──▶ (segundo plano) descarga el PDF ──▶ ingest_document
        └─ ingesting ──▶ ingested | failed        ──▶ scientific_documents + document_chunks
```

| Estado | Significado | ¿Se puede aprobar o rechazar? |
|---|---|---|
| `pending` | Propuesto, sin revisar | Sí |
| `approved` | Aprobado, en espera de indexar | Sí |
| `rejected` | Rechazado; no se vuelve a proponer | Sí |
| `ingesting` | Lote en curso | No |
| `ingested` | Indexado | No |
| `failed` | Falló la descarga o el embedding (motivo en `error`) | Sí: aprobarlo de nuevo lo reintenta |

**Robustez**

- El lote reclama todos los aprobados de una vez (un segundo disparo no los repite) y renueva un *latido* (`heartbeat_at`) tras cada documento.
- Un candidato en `ingesting` sin latido en 15 minutos se considera bloqueado (`stuck`): `POST /admin/ingest` lo devuelve a `approved` antes de contar.
- Antes de descargar se comprueba por DOI si el documento ya está indexado, para que un reintento tras una caída no lo duplique.
- `ingest_document` guarda el documento y sus chunks en un solo commit: un fallo al generar embeddings no deja documentos huérfanos.
- `download_service` solo descarga por `https`, exige que el archivo empiece con `%PDF` y limita su tamaño a 50 MB. El PDF se pide al endpoint de API de Europe PMC (`/api/getPdf`), porque la URL «de navegador» está detrás de Cloudflare y responde 403 a clientes que no son navegador.
- Historial (D-22): `GET /admin/documents` lista el corpus indexado (`services/document_history_service.py`) y `DELETE /admin/documents/{id}` borra primero los chunks (la FK no tiene `ON DELETE CASCADE`) y luego el documento, en un solo commit. El candidato `ingested` con el mismo DOI (sin distinguir mayúsculas) pasa a `rejected` para que el descubrimiento no lo proponga de nuevo. El PDF no se borra del disco. No hubo migración.
- Limitación conocida: `messages.sources` no es una FK, así que los mensajes de chat anteriores conservan el texto de la referencia aunque el documento ya no exista (D-18).
- El panel muestra títulos y resúmenes de terceros solo con `textContent`, nunca como HTML.

## Base de datos

11 tablas hoy (migraciones `0001`–`0009`): `users`, `profiles`, `habit_records`, `scientific_documents` (con `doi` y `domain`), `document_chunks` (con `embedding` como `ARRAY(FLOAT)`, no `Vector` — ver D-12 en `docs/decisions.md`), `conversations`, `messages` (con `sources` JSONB), las dos del descubrimiento de documentos (`discovery_runs` y `document_candidates`) y las dos del checklist diario (`daily_tasks` y `task_progress`). Las siete primeras son el modelo de datos del plan (sección 8); las del descubrimiento son un agregado posterior (D-17) y las de tareas otro (D-23, D-24). Ver [`../diagrams/er-diagram.md`](../diagrams/er-diagram.md) para el ER completo.
