# HabitQ

Aplicación móvil de proyecto de grado — orientación personalizada de hábitos saludables mediante un asistente conversacional respaldado por evidencia científica (RAG). Ver [`HABITQ_DEVELOPMENT_PLAN.md`](./HABITQ_DEVELOPMENT_PLAN.md) para el plan funcional y técnico completo.

## Alcance actual

Ver también [`docs/architecture/overview.md`](./docs/architecture/overview.md) (arquitectura y tabla de endpoints), [`docs/requirements/use-cases.md`](./docs/requirements/use-cases.md) (casos de uso) y [`docs/decisions.md`](./docs/decisions.md) (decisiones no explícitas en el plan).

**Backend (FastAPI)** — `POST /auth/google`, `GET /auth/me`, `POST /auth/onboarding-complete`, `POST /auth/refresh`, `POST /auth/logout`, `GET/PUT /profile`, `GET/POST /habits`, `PUT /habits/{id}`. Todos los endpoints privados exigen JWT válido (`get_current_user`).

**Mobile (Flutter)**
- Login con Google + consentimiento inicial (una vez por dispositivo, guardado localmente).
- Onboarding: perfil básico (edad + objetivo principal) + cuestionario de 9 preguntas por los 6 dominios de hábitos.
- Home: saludo, cerrar sesión, navegación a Mis Hábitos y Perfil.
- Mis Hábitos: ver y editar los hábitos ya registrados (autosave).
- Perfil: ver y editar edad y objetivo principal (autosave).
- Chat con HabitQ: conversación con IA respaldada por RAG, con fuentes mostradas por cada respuesta y personalización según perfil/hábitos cuando es relevante.
- Historial: lista de conversaciones pasadas, reabrir para continuar chateando, o borrarlas.

**RAG completo (Fase 3 del plan)** — ingesta (PDF → texto → limpieza → chunking → embeddings → Postgres), retrieval (similitud coseno en Python, sin pgvector — no está disponible en el entorno de desarrollo, ver `docs/decisions.md` D-12), integración con Gemini (`POST /chat`), y persistencia de conversaciones. Verificado extremo a extremo contra Postgres y la API real de Gemini (ver [`ingestion/README.md`](./ingestion/README.md), [`docs/rag-chat-progress.md`](./docs/rag-chat-progress.md) y `docs/decisions.md` D-12 a D-15).

**Pendiente** (ver `HABITQ_DEVELOPMENT_PLAN.md` para el detalle completo): hardening de seguridad general.

> **Nota de alcance (Login):** el boceto de Figma (`Diseño/Inicio de sesión.png`) incluye un formulario de correo/contraseña. El plan (secciones 2, 3, 10, 20) excluye explícitamente el login tradicional del MVP — solo Google Sign-In. La pantalla implementada usa **solo Google**, adaptando el boceto (sin campos de correo/contraseña ni link de registro).
>
> **Nota de alcance (Home):** el boceto `Diseño/Inicio.png` incluye gamificación (logros, racha, badge de puntos) y un tab de estadísticas ("Actividad"), que el plan (sección 2, "Fuera del MVP") excluye explícitamente. La pantalla Home implementada sigue el plan escrito, no el boceto.

## Estructura

```text
habitq/
├── mobile/     # Flutter (Persona 1)
├── backend/    # FastAPI (Persona 2)
├── ingestion/  # PDFs de fuentes científicas + script de ingesta RAG (ver ingestion/README.md)
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

### 4. Migraciones

```bash
alembic upgrade head
```

### 5. Ejecutar

```bash
uvicorn app.main:app --reload
```

Verifica: `GET http://localhost:8000/health` → `{"status": "ok"}`.

### 6. Tests

```bash
pytest
```

Los tests no requieren `.env` ni una base de datos real: `tests/conftest.py` define valores de `DATABASE_URL`/`GOOGLE_CLIENT_ID`/`JWT_SECRET`/`GEMINI_API_KEY` dummy para que `Settings` se instancie sin tocar Postgres ni la API real de Gemini. Verificado: 89/89 pasan en limpio.

## Mobile (Flutter)

### 1. Instalar Flutter SDK

Ya instalado en esta máquina (`C:\src\flutter`, Flutter 3.47.2). En una máquina nueva (ej. la de tu compañero/a):

1. Descarga el SDK desde https://docs.flutter.dev/get-started/install/windows y descomprímelo (ej. en `C:\src\flutter`).
2. Agrega `C:\src\flutter\bin` a tu variable de entorno `PATH`.
3. Verifica: `flutter doctor` (debería reconocer el Android SDK ya instalado).

### 2. Completar el scaffolding nativo del proyecto

Ya existen `mobile/pubspec.yaml` y `mobile/lib/` (Login, Onboarding, Home, Mis Hábitos, Perfil). Faltan las carpetas nativas (`android/`, `ios/`, etc.) en una máquina nueva, que solo `flutter create` puede generar correctamente:

```bash
cd mobile
flutter create --org com.habitq --project-name mobile .
```

Esto **no debería sobrescribir** `pubspec.yaml` ni `lib/` existentes (Flutter detecta el proyecto y solo agrega lo que falta). Si `flutter pub get` falla después porque `pubspec.yaml` fue reemplazado, vuelve a agregar las dependencias:

```bash
flutter pub add google_sign_in http flutter_secure_storage
```

Ya ejecutado en esta máquina: `flutter analyze` no reporta issues y `flutter test` pasa (83 tests).

### 2.1 Build de Android

`flutter build apk --debug` funciona en esta máquina y genera `mobile/build/app/outputs/flutter-apk/app-debug.apk` (~158 MB). Si en otra máquina aparece un error al descargar el NDK (versión `28.2.13676358`) vía `sdkmanager.bat` (crash `NTSTATUS 0xC0000409`, incompatibilidad entre ese binario deprecado y JDK 25):

- **Opción recomendada**: abre Android Studio → *More Actions → SDK Manager → SDK Tools* → marca "NDK (Side by side)" en la versión `28.2.13676358` → Apply. Esto usa el instalador gráfico en vez del `sdkmanager.bat`, que puede fallar con versiones recientes de JDK.
- Alternativa: instala una versión de NDK ya presente vía Android Studio y fija esa versión explícitamente en `mobile/android/app/build.gradle.kts` (`ndkVersion = "<versión instalada>"`) en vez de `flutter.ndkVersion`.

Ninguna dependencia del proyecto (`google_sign_in`, `flutter_secure_storage`) usa código nativo — el NDK solo lo exige la validación de Android Gradle Plugin, no una necesidad real de esta app.

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
   - **Tipo "Web application"**: no necesita URIs de redirect para este flujo. El Client ID generado aquí es el que va en `.env` como `GOOGLE_CLIENT_ID` — el backend lo usa para validar el `aud` del ID token, y Flutter lo pasa como `serverClientId` a `GoogleSignIn` para que el token generado tenga esa audiencia.
4. Pega el Client ID **Web** (no el de Android) en `GOOGLE_CLIENT_ID` dentro de `.env`.

Repite el registro del Android OAuth client (con su propio SHA-1) en la máquina de tu compañero(a) cuando genere su propio debug keystore — cada máquina de desarrollo tiene un SHA-1 de debug distinto.
