# Guía Docker — HabitQ (backend + PostgreSQL)

Guía paso a paso para levantar el **backend (FastAPI)** y **PostgreSQL** de
HabitQ con Docker, sin instalar Python ni Postgres localmente. Basada en
`backend/Dockerfile`, `docker-compose.yml` y `backend/app/core/config.py`
del repositorio (commit `889d498`).

> La app **móvil (Flutter)** no corre dentro de Docker — ver la sección
> [Limitaciones y pasos manuales](#limitaciones-y-pasos-manuales-fuera-de-docker)
> al final de esta guía.

---

## 0. Prerrequisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado y corriendo (incluye Docker Compose v2).
- Git instalado.
- Una API key de Gemini y un Client ID de Google (ver [paso 3](#3-completar-las-variables-de-entorno)).

Verificar que Docker está activo:

```bash
docker --version
docker compose version
```

---

## 1. Clonar el repositorio

```bash
git clone https://github.com/FedeJGM/HabitQ.git
cd HabitQ
```

---

## 2. Ubicar los archivos de Docker

Estos archivos ya están en el repositorio, no hay que crearlos:

```text
HabitQ/
├── docker-compose.yml       # orquesta backend + Postgres
└── backend/
    ├── Dockerfile            # imagen del backend FastAPI
    └── .dockerignore
```

---

## 3. Completar las variables de entorno

`docker-compose.yml` lee un archivo `.env` en la **raíz** del repositorio
(no se commitea, está en `.gitignore`). Ese archivo aún no existe en el
repo (`.env.example` tampoco), así que hay que crearlo a mano.

Crear `HabitQ/.env` con este contenido, completando los campos vacíos:

```env
# --- Postgres (los usa el servicio "db" del docker-compose) ---
POSTGRES_USER=habitq
POSTGRES_PASSWORD=habitq
POSTGRES_DB=habitq

# --- Backend ---
# Dentro de Docker, docker-compose.yml IGNORA esta línea y arma la URL real
# apuntando al servicio "db" con las variables POSTGRES_* de arriba. Se deja
# igual para que el mismo .env sirva si alguna vez se corre el backend sin
# Docker (ver README.md).
DATABASE_URL=postgresql+psycopg://habitq:habitq@localhost:5432/habitq

# String largo y aleatorio para firmar el JWT propio de HabitQ (32+ bytes).
JWT_SECRET=

# Client ID **Web** de Google Cloud (no el de Android). Ver paso 7 de esta
# guía o README.md, sección "Credenciales de Google".
GOOGLE_CLIENT_ID=

# API key de Gemini (google-genai). Requerida por
# backend/app/core/config.py — el backend no arranca sin ella.
GEMINI_API_KEY=

# --- Mobile (no lo usa Docker, pero conviene dejarlo ya en el .env) ---
API_BASE_URL=http://10.0.2.2:8000
```

Pedile a quien tenga las credenciales (`JWT_SECRET`, `GOOGLE_CLIENT_ID`,
`GEMINI_API_KEY`) que te las pase, o generá tu propio `JWT_SECRET` con:

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

> `GOOGLE_CLIENT_ID` puede ser el mismo que ya usa el resto del equipo
> (es el Client ID **Web**, compartido). Lo que sí es único por máquina es
> el registro OAuth de tipo **Android** — ver el paso 7 (manual, fuera de
> Docker).

> **Importante — acción del dueño del proyecto de Google Cloud (vos, no tu
> compañero):** mientras el OAuth consent screen esté en modo "Testing",
> **solo pueden iniciar sesión las cuentas agregadas como "Test user"**.
> Antes de que tu compañero pruebe el login, agregá su Gmail en Google
> Cloud Console → **APIs & Services → OAuth consent screen → Test users**.
> Sin este paso, su login falla con `access_denied` aunque haya registrado
> correctamente su propio OAuth Android (paso 8) con su SHA-1.

---

## 4. Levantar backend + Postgres

Desde la raíz del repositorio (`HabitQ/`, donde está `docker-compose.yml`):

```bash
docker compose up --build
```

Qué hace esto (para que sepas qué esperar en la terminal):

1. Descarga la imagen `postgres:16-alpine` y levanta el servicio `db`.
2. Espera a que Postgres esté listo (`healthcheck` con `pg_isready`) antes
   de arrancar el backend.
3. Construye la imagen del backend (`backend/Dockerfile`):
   - Instala `libgomp1` (lo necesita `torch`, dependencia de
     `sentence-transformers`).
   - Instala las dependencias de `backend/requirements.txt`.
   - Descarga el modelo de embeddings `all-MiniLM-L6-v2` en tiempo de
     build (para que el primer `POST /chat` no tenga que descargarlo).
   - **Este paso necesita internet** y puede tardar varios minutos la
     primera vez (imagen pesada por `torch`/`sentence-transformers`).
4. Al arrancar el contenedor del backend, corre `alembic upgrade head`
   (crea las tablas) y después levanta `uvicorn` en el puerto 8000.

Para correrlo en segundo plano en vez de bloquear la terminal:

```bash
docker compose up --build -d
```

---

## 5. Verificar que quedó funcionando

```bash
curl http://localhost:8000/health
```

Debería devolver:

```json
{"status": "ok"}
```

También podés abrir `http://localhost:8000/docs` en el navegador para ver
la documentación interactiva (Swagger) de la API.

Ver logs en vivo (si corriste con `-d`):

```bash
docker compose logs -f backend
```

---

## 6. Comandos útiles del día a día

| Acción | Comando |
|---|---|
| Levantar todo | `docker compose up -d` |
| Ver logs del backend | `docker compose logs -f backend` |
| Parar todo (conserva los datos de Postgres) | `docker compose down` |
| Parar y **borrar** los datos de Postgres | `docker compose down -v` |
| Reconstruir la imagen tras cambiar código/dependencias | `docker compose up --build` |
| Ejecutar los tests dentro del contenedor | `docker compose exec backend pytest` |
| Abrir una shell en el contenedor del backend | `docker compose exec backend bash` |
| Conectarse a Postgres desde el host (psql) | `psql -h localhost -U habitq -d habitq` (pide `POSTGRES_PASSWORD` del `.env`) |

### Ingesta de documentos científicos (opcional)

`ingestion/scripts/ingest.py` no es un servicio del `docker-compose`
(es una tarea puntual, no un proceso de larga duración). Para cargar los
PDFs de `ingestion/data/scientific_documents/` a la base que corre en
Docker:

```bash
docker compose exec backend python ingestion/scripts/ingest.py
```

> Esto solo funciona si la carpeta `ingestion/` quedó copiada dentro de la
> imagen del backend junto con `app/` (verificar con
> `docker compose exec backend ls ingestion/scripts` si da error de
> "No such file or directory").

> **Sin este paso, el chat no tiene nada que recuperar.** La base de datos
> en Docker arranca vacía (sin filas en `scientific_documents` ni
> `document_chunks`). `POST /chat` va a seguir respondiendo (Gemini
> contesta igual), pero **sin fuentes citadas** en la respuesta, porque no
> hay documentos indexados sobre los que buscar. Para probar el
> comportamiento real del RAG (con fuentes), correr la ingesta antes de
> probar el chat.

---

## Limitaciones y pasos manuales (fuera de Docker)

Docker resuelve el backend y Postgres, pero **no reemplaza** estos pasos —
tu compañero los sigue necesitando para probar la app completa en su PC:

### 7. App móvil (Flutter) — instalación 100% manual

Un contenedor no tiene acceso al SDK gráfico/USB de Android ni puede
generar un APK que corra en un emulador o celular físico. Esto se instala
igual que sin Docker:

1. Instalar Flutter SDK (`https://docs.flutter.dev/get-started/install/windows`),
   agregarlo al `PATH`, verificar con `flutter doctor`.
2. Generar el scaffolding nativo (no versionado en Git):
   ```bash
   cd mobile
   flutter create --org com.habitq --project-name mobile .
   flutter pub get
   ```
   Si `pubspec.yaml` se sobrescribe, volver a agregar las dependencias:
   ```bash
   flutter pub add google_sign_in http flutter_secure_storage
   ```
3. Correr la app apuntando al backend de Docker (mismo puerto 8000
   publicado por `docker-compose.yml`):
   ```bash
   flutter run --dart-define-from-file=../.env
   ```
   - Emulador Android: `API_BASE_URL=http://10.0.2.2:8000` (ya está en el
     `.env` del paso 3) apunta automáticamente al backend en Docker.
   - Dispositivo físico por USB: reemplazar por la IP de la PC en la red
     local, ej. `API_BASE_URL=http://192.168.x.x:8000`.

### 8. Registro OAuth de Google — único por máquina

El SHA-1 del keystore de debug de Android es distinto en cada PC, así que
cada compañero necesita registrar su propio OAuth client de tipo
**Android**, aunque el backend corra en Docker:

```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Copiar el `SHA1:` resultante y, en Google Cloud Console → **APIs & Services
→ Credentials → Create Credentials → OAuth client ID → Android**, registrar
`com.habitq.mobile` con ese SHA-1. El `GOOGLE_CLIENT_ID` que va en el
`.env` sigue siendo el del client **Web** compartido (no cambia).

### 9. Build de Android — posible problema de NDK

Si `flutter build apk --debug` falla al descargar el NDK
(`28.2.13676358`) con un crash `NTSTATUS 0xC0000409`: instalar el NDK
desde Android Studio (**More Actions → SDK Manager → SDK Tools →
"NDK (Side by side)"**) en vez de dejar que `sdkmanager.bat` lo descargue
solo.

### 10. Internet saliente para el build de Docker

El primer `docker compose up --build` necesita salida a internet para
`pip install` (PyPI) y para descargar el modelo de embeddings (Hugging
Face Hub). Si hay un antivirus/red corporativa interceptando TLS (el
README documenta el caso de Kaspersky), puede haber que ajustar el
`Dockerfile` con `--trusted-host pypi.org --trusted-host
files.pythonhosted.org` si el build falla con
`CERTIFICATE_VERIFY_FAILED`.

---

## Resumen del flujo completo

```mermaid
flowchart TD
    A[Clonar el repo] --> B[Crear .env en la raiz]
    B --> C[docker compose up --build]
    C --> D[Verificar GET /health]
    D --> E[Instalar Flutter SDK - manual]
    E --> F[flutter create + flutter pub get - manual]
    F --> G[Registrar OAuth Android con SHA-1 propio - manual]
    G --> H[flutter run --dart-define-from-file=../.env]
    H --> I[App conectada al backend en Docker]
```
