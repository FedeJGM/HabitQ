# HabitQ

Aplicación móvil de proyecto de grado — orientación personalizada de hábitos saludables mediante un asistente conversacional respaldado por evidencia científica (RAG). Ver [`HABITQ_DEVELOPMENT_PLAN.md`](./HABITQ_DEVELOPMENT_PLAN.md) para el plan funcional y técnico completo.

## Alcance actual

Ver también [`docs/architecture/overview.md`](./docs/architecture/overview.md) (arquitectura y tabla de endpoints), [`docs/requirements/use-cases.md`](./docs/requirements/use-cases.md) (casos de uso) y [`docs/decisions.md`](./docs/decisions.md) (decisiones no explícitas en el plan).

**Backend (FastAPI)**
- **Auth, perfil y hábitos:** `POST /auth/google`, `GET /auth/me`, `POST /auth/onboarding-complete`, `POST /auth/refresh`, `POST /auth/logout`, `GET/PUT /profile`, `GET/POST /habits`, `PUT /habits/{id}`.
- **Tareas diarias:** `GET /tasks/catalog`, `GET /tasks?day=`, `POST /tasks`, `PUT /tasks/{id}`, `DELETE /tasks/{id}`, `PUT /tasks/{id}/progress`.
- **Chat:** `POST /chat`, `GET /chat/conversations`, `GET /chat/conversations/{id}/messages`, `DELETE /chat/conversations/{id}`.
- **Administración:** panel web en `GET /admin` más `POST /admin/discovery`, `GET /admin/candidates`, `POST /admin/candidates/{id}/approve`, `POST /admin/candidates/{id}/reject`, `POST /admin/ingest`, `GET /admin/documents` y `DELETE /admin/documents/{id}`.
- Todos los endpoints privados exigen JWT válido (`get_current_user`). Los de `/admin` además exigen que el correo del usuario esté en `ADMIN_EMAILS` (`require_admin`): 401 sin sesión, 403 si no es admin.

**Mobile (Flutter)**
- Login con Google + consentimiento inicial (una vez por dispositivo, guardado localmente).
- Onboarding: perfil básico (edad + objetivo principal) + cuestionario de 9 preguntas por los 6 dominios de hábitos.
- Home: saludo según la hora (de 19:00 a 04:59 «Es una gran noche», si no «Es un nuevo día»), cerrar sesión, navegación a Mis Hábitos y Perfil, y el chat: un botón único hasta la primera conversación; después «Continuar conversación» y «Nuevo chat con HabitQ».
- Actividad: checklist diario por objetivo. Eliges tareas de un catálogo fijo para tu objetivo, las marcas (casilla o contador) y la lista parte en cero a tu medianoche; la franja semanal muestra días anteriores en solo lectura. Cada tarea puede tener un recordatorio local a la hora que elijas (notificación del propio teléfono, sin servidor). Ver `docs/decisions.md` D-23 a D-25.
- Mis Hábitos: ver y editar los hábitos ya registrados (autosave).
- Perfil: ver y editar edad y objetivo principal (autosave).
- Chat con HabitQ: conversación con IA respaldada por RAG, con referencias completas por cada respuesta (autores, año, revista, páginas y enlace DOI tocable) y personalización según perfil/hábitos cuando es relevante.
- Historial: lista de conversaciones pasadas, reabrir para continuar chateando (cada respuesta conserva sus referencias), o borrarlas.

**RAG completo (Fase 3 del plan)** — ingesta (PDF → texto → limpieza → chunking → embeddings → Postgres), retrieval (similitud coseno en Python, sin pgvector — no está disponible en el entorno de desarrollo, ver `docs/decisions.md` D-12), integración con Gemini (`POST /chat`), y persistencia de conversaciones. Los embeddings los genera `intfloat/multilingual-e5-small` (configurable con `EMBEDDING_MODEL_NAME`) para que las preguntas en español encuentren documentos en inglés (D-20). Verificado extremo a extremo contra Postgres y la API real de Gemini (ver [`ingestion/README.md`](./ingestion/README.md), [`docs/rag-chat-progress.md`](./docs/rag-chat-progress.md) y `docs/decisions.md` D-12 a D-21).

**Base de conocimiento administrable** — un administrador (correo en `ADMIN_EMAILS`) abre `/admin`, busca 30 artículos de acceso abierto en Europe PMC repartidos entre 7 dominios (sueño, alimentación, actividad física, hidratación, pantallas, estrés y consumo de sustancias), abre cada enlace para leerlo y aprueba o rechaza. Solo los aprobados se descargan, se les extraen los metadatos (autores, año, revista, DOI) y se indexan en segundo plano. El panel también lista el historial de documentos indexados y permite eliminarlos. Ver [Panel de administración](#7-panel-de-administración-opcional) y `docs/decisions.md` D-17 y D-21.

**Pendiente** (ver `HABITQ_DEVELOPMENT_PLAN.md` para el detalle completo): hardening de seguridad general.

> **Nota de alcance (Login):** el boceto de Figma (`Diseño/Inicio de sesión.png`) incluye un formulario de correo/contraseña. El plan (secciones 2, 3, 10, 20) excluye explícitamente el login tradicional del MVP — solo Google Sign-In. La pantalla implementada usa **solo Google**, adaptando el boceto (sin campos de correo/contraseña ni link de registro).
>
> **Nota de alcance (Home y Actividad):** el boceto `Diseño/Inicio.png` incluye gamificación (logros, racha, badge de puntos) que el plan (sección 2, "Fuera del MVP") excluye explícitamente; la pantalla Home implementada sigue el plan escrito, no el boceto. El boceto `Diseño/Actividad.png` (agenda diaria con franja semanal, tareas con casilla o contador y recordatorios) se implementó el 2026-10-15 como la pestaña **Actividad**, limitada al checklist diario: sin gamificación, estadísticas ni tareas generadas automáticamente (D-23). La caminata se mide en minutos con un contador manual.

## Estructura

```text
habitq/
├── mobile/     # Flutter (Persona 1)
├── backend/    # FastAPI (Persona 2); incluye el panel de administración (app/web/admin.html)
├── ingestion/  # PDFs de fuentes + scripts: ingest.py (carga por manifest) y reindex.py (tras cambiar de modelo) — ver ingestion/README.md
├── Diseño/     # Bocetos de Figma exportados (PNG)
├── docs/       # Arquitectura, diagramas, casos de uso, decisiones — ver docs/architecture/overview.md
├── .env.example  # Config compartida (ver abajo)
└── HABITQ_DEVELOPMENT_PLAN.md
```

## Configuración compartida (`.env`)

`mobile/` y `backend/` leen el **mismo** archivo `.env` en la raíz del repo (nunca se commitea — está en `.gitignore`).

```bash
cp .env.example .env
```

Completa `.env` con:

| Variable | Usado por | Descripción |
|---|---|---|
| `DATABASE_URL` | backend | Cadena de conexión a tu PostgreSQL local |
| `JWT_SECRET` | backend | Secreto para firmar el JWT HabitQ (cualquier string largo aleatorio) |
| `GOOGLE_CLIENT_ID` | backend + mobile | **Web** Client ID de Google Cloud (ver sección "Credenciales de Google" abajo) |
| `API_BASE_URL` | mobile | URL del backend. `http://10.0.2.2:8000` apunta al `localhost` de tu PC desde el emulador Android |
| `GEMINI_API_KEY` | backend | API key de Gemini (`google-genai`). **Obligatoria**: el backend no arranca sin ella. El modelo está fijo en `gemini-3.5-flash-lite` (D-26); que la clave sea gratuita o de pago es un asunto de facturación del proyecto de Google, no de la app |
| `ADMIN_EMAILS` | backend | Correos de Google (separados por coma) con acceso a `/admin`. Vacía = nadie es admin |
| `EMBEDDING_MODEL_NAME` | backend | Opcional. Modelo de embeddings (por defecto `intfloat/multilingual-e5-small`). Si lo cambias, hay que [reindexar](#4-migraciones) |
| `RETRIEVAL_MIN_SCORE` | backend | Opcional. Similitud mínima para usar un fragmento como evidencia; vacía = sin umbral (ver D-19) |

## Backend (FastAPI)

### 1. Prerrequisitos

- Python 3.11+ instalado.
- PostgreSQL corriendo localmente (ya lo tienes).

### 2. Crear la base de datos

La migración de Alembic crea las tablas, pero **no crea la base de datos `habitq` en sí**. Créala una vez:

```bash
# Con psql (ajusta el usuario si no es "postgres"):
"C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -h localhost -c "CREATE DATABASE habitq;"
```

O desde pgAdmin: clic derecho en "Databases" → "Create" → "Database..." → nombre `habitq`.

### 3. Entorno virtual y dependencias

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Si tu máquina también intercepta TLS (ver nota abajo), usa en su lugar:

```bash
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt
```

> Si `pip install` falla con `CERTIFICATE_VERIFY_FAILED` / "self-signed certificate in certificate chain": Kaspersky (u otro antivirus/red corporativa) está inspeccionando TLS con su propio certificado raíz, que Python no confía (aunque `curl`/el navegador sí, porque usan el almacén de Windows). En esta máquina se resolvió instalando con:
> ```bash
> pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt
> ```
> Esto desactiva la verificación de certificado solo para esos dos hosts de pip (decisión consciente: Kaspersky ya intercepta ese tráfico de todas formas). Si prefieres no depender de `--trusted-host` cada vez, la alternativa más limpia es excluir `python.exe`/pip de la inspección de conexiones cifradas en la configuración de Kaspersky.
>
> El mismo bloqueo aparece al descargar el modelo de embeddings desde Hugging Face (`CERTIFICATE_VERIFY_FAILED` en consultas opcionales). No impide la descarga, que termina tras reintentos, y una vez descargado el backend carga el modelo desde disco sin tocar la red.

### 4. Migraciones

```bash
alembic upgrade head
```

Crea las 11 tablas (migraciones `0001`–`0009`).

> **Si ya tenías documentos indexados con una versión anterior** (modelo `all-MiniLM-L6-v2`), reindéxalos después de actualizar. Los vectores de modelos distintos no son comparables: sin este paso el chat **no da error**, pero recupera fragmentos equivocados.
> ```bash
> python ../ingestion/scripts/reindex.py --dry-run   # lista lo que se reindexaría, sin cambiar nada
> python ../ingestion/scripts/reindex.py             # reindexa (un documento por transacción)
> ```

### 5. Ejecutar

```bash
uvicorn app.main:app --reload
```

Verifica: `GET http://localhost:8000/health` → `{"status": "ok"}`.

### 6. Tests

```bash
pytest
```

Los tests no requieren `.env` ni una base de datos real: `tests/conftest.py` define valores de `DATABASE_URL`/`GOOGLE_CLIENT_ID`/`JWT_SECRET`/`GEMINI_API_KEY` dummy para que `Settings` se instancie sin tocar Postgres ni la API real de Gemini. Verificado: 206 pasan en limpio.

### 7. Panel de administración (opcional)

Sirve para ampliar la base de conocimiento sin tocar archivos a mano.

**Camino rápido**

1. En `.env` define `ADMIN_EMAILS=tu.correo@gmail.com` (la cuenta de Google con la que iniciarás sesión) y **reinicia el backend**: `--reload` vigila archivos `.py`, no el `.env`.
2. En Google Cloud → *Credenciales* → tu cliente **Web**, agrega `http://localhost` y `http://localhost:8000` en *Orígenes autorizados de JavaScript* (ver [Credenciales de Google](#credenciales-de-google)).
3. Abre `http://localhost:8000/admin` (no `127.0.0.1`) e inicia sesión con Google.
4. Elige los dominios → **Buscar 30 documentos** → abre el artículo, el PDF o el DOI de cada candidato → **Aprobar** o **Rechazar** → **Indexar aprobados**.
5. Pregunta en el chat sobre ese tema: la respuesta trae las referencias.
6. En «3. Historial de documentos» ves todo lo indexado (también lo cargado por línea de comandos) y puedes **Eliminar** un documento (pide confirmación).

| Detalle | Comportamiento |
|---|---|
| Fuente | Europe PMC: solo acceso abierto, revisiones/metaanálisis/guías desde 2015, en inglés o español |
| Qué se descarga | Solo lo aprobado. Los rechazados y los ya vistos no se vuelven a proponer |
| Indexación | En segundo plano; el panel se actualiza solo (Indexando… → Indexado o Falló) |
| Si el servidor se cae a mitad | El candidato aparece como **Bloqueado** tras 15 min sin avance; **Indexar aprobados** lo reintenta y no duplica el documento (D-21) |
| Eliminar un documento | Borra el documento y sus chunks en una transacción y marca su candidato como rechazado para que no se vuelva a proponer. El PDF queda en disco. Los mensajes de chat pasados conservan el texto de la referencia (D-22) |
| PDFs descargados | Quedan en `ingestion/data/scientific_documents/`; no los commitees |
| Acceso | Sin sesión, 401; con un correo fuera de `ADMIN_EMAILS`, 403 |
| Sin configurar el origen de Google | El panel acepta un JWT pegado a mano (sección «Alternativa» del login) |

Los documentos institucionales (OMS, CDC) siguen cargándose con `ingestion/scripts/ingest.py` ([`ingestion/README.md`](./ingestion/README.md)).

## Mobile (Flutter)

### 1. Instalar Flutter SDK

Ya instalado en esta máquina (`C:\src\flutter`, Flutter 3.47.2). En una máquina nueva (ej. la de tu compañero/a):

1. Descarga el SDK desde https://docs.flutter.dev/get-started/install/windows y descomprímelo (ej. en `C:\src\flutter`).
2. Agrega `C:\src\flutter\bin` a tu variable de entorno `PATH`.
3. Verifica: `flutter doctor` (debería reconocer el Android SDK ya instalado).

### 2. Completar el scaffolding nativo del proyecto

Ya existen `mobile/pubspec.yaml` y `mobile/lib/` (Login, Consentimiento, Onboarding, Home, Mis Hábitos, Perfil, Chat e Historial). Faltan las carpetas nativas (`android/`, `ios/`, etc.) en una máquina nueva, que solo `flutter create` puede generar correctamente:

```bash
cd mobile
flutter create --org com.habitq --project-name mobile .
```

Esto **no debería sobrescribir** `pubspec.yaml` ni `lib/` existentes (Flutter detecta el proyecto y solo agrega lo que falta). Si `flutter pub get` falla después porque `pubspec.yaml` fue reemplazado, vuelve a agregar las dependencias:

```bash
flutter pub add google_sign_in http flutter_secure_storage url_launcher
```

Ya ejecutado en esta máquina: `flutter analyze` no reporta issues y `flutter test` pasa (116 tests).

### 2.1 Build de Android

`flutter build apk --debug` funciona en esta máquina y genera `mobile/build/app/outputs/flutter-apk/app-debug.apk` (~158 MB). Si en otra máquina aparece un error al descargar el NDK (versión `28.2.13676358`) vía `sdkmanager.bat` (crash `NTSTATUS 0xC0000409`, incompatibilidad entre ese binario deprecado y JDK 25):

- **Opción recomendada**: abre Android Studio → *More Actions → SDK Manager → SDK Tools* → marca "NDK (Side by side)" en la versión `28.2.13676358` → Apply. Esto usa el instalador gráfico en vez del `sdkmanager.bat`, que puede fallar con versiones recientes de JDK.
- Alternativa: instala una versión de NDK ya presente vía Android Studio y fija esa versión explícitamente en `mobile/android/app/build.gradle.kts` (`ndkVersion = "<versión instalada>"`) en vez de `flutter.ndkVersion`.

Ninguna dependencia del proyecto (`google_sign_in`, `flutter_secure_storage`, `url_launcher`) usa código nativo — el NDK solo lo exige la validación de Android Gradle Plugin, no una necesidad real de esta app.

### 3. Ejecutar

El `API_BASE_URL` y `GOOGLE_CLIENT_ID` se inyectan desde el `.env` de la raíz (no se empaquetan como asset):

```bash
cd mobile
flutter pub get
flutter run --dart-define-from-file=../.env
```

## Credenciales de Google

El login con Google ya está configurado y verificado de extremo a extremo en esta máquina. Application ID del proyecto Android: **`com.habitq.mobile`**.

Cada máquina de desarrollo necesita su propio registro OAuth porque el SHA-1 del keystore de debug es distinto por máquina — si es la primera vez que configuras esto (ej. en la máquina de tu compañero/a), seguí los pasos de abajo.

### SHA-1 del keystore de debug

**SHA-1 de esta máquina: `5D:C7:5C:B6:10:51:DE:80:CD:25:12:37:DE:77:B9:88:E7:26:14:70`**

(Del debug keystore estándar de Android en `%USERPROFILE%\.android\debug.keystore` — alias `androiddebugkey`, password `android`, generado automáticamente por Gradle en el primer build de Android en esta máquina.)

En la máquina de tu compañero(a) (o si se regenera el keystore), extrae el suyo con:

```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copia el valor de `SHA1:` (formato `AA:BB:CC:...`).

### Pasos en Google Cloud Console

1. Ve a https://console.cloud.google.com/ y crea un proyecto nuevo (ej. "HabitQ").
2. **APIs & Services → OAuth consent screen**: tipo "External", completa nombre de la app y correo de soporte. En modo "Testing" agrega tu cuenta de Google (y la de tu compañero(a)) como "Test users".
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**:
   - **Tipo "Android"**: Package name `com.habitq.mobile`, SHA-1 obtenido arriba. Esto habilita el Sign-In desde la app, pero **no genera un Client ID que uses en código**.
   - **Tipo "Web application"**: no necesita URIs de redirect para este flujo. Para el login del **panel de administración** (navegador) agrega además `http://localhost` y `http://localhost:8000` en *Authorized JavaScript origins* de este mismo cliente (Google pide ambos para pruebas locales; tras guardar, el cambio puede tardar unos minutos en aplicarse). El Client ID generado aquí es el que va en `.env` como `GOOGLE_CLIENT_ID` — el backend lo usa para validar el `aud` del ID token, y Flutter lo pasa como `serverClientId` a `GoogleSignIn` para que el token generado tenga esa audiencia.
4. Pega el Client ID **Web** (no el de Android) en `GOOGLE_CLIENT_ID` dentro de `.env`.

Repite el registro del Android OAuth client (con su propio SHA-1) en la máquina de tu compañero(a) cuando genere su propio debug keystore — cada máquina de desarrollo tiene un SHA-1 de debug distinto.
