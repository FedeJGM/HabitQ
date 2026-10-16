# Modelo entidad-relación

## Implementado (migraciones `0001`–`0009`)

11 tablas. Las siete primeras (`0001`–`0005`) son el modelo de datos del plan (sección 8). `discovery_runs` y `document_candidates` (`0006`) son un agregado posterior para el panel de administración (D-17); `0007` agrega `messages.sources` (D-18) y `0008` agrega `document_candidates.heartbeat_at` (D-21). `daily_tasks` y `task_progress` (`0009`) son el checklist diario (D-23, D-24).

```mermaid
erDiagram
    USERS ||--o| PROFILES : "tiene"
    USERS ||--o{ HABIT_RECORDS : "registra"
    SCIENTIFIC_DOCUMENTS ||--o{ DOCUMENT_CHUNKS : "se divide en"
    USERS ||--o{ CONVERSATIONS : "inicia"
    CONVERSATIONS ||--o{ MESSAGES : "contiene"
    USERS ||--o{ DISCOVERY_RUNS : "lanza (admin)"
    DISCOVERY_RUNS ||--o{ DOCUMENT_CANDIDATES : "propone"
    USERS ||--o{ DAILY_TASKS : "activa"
    DAILY_TASKS ||--o{ TASK_PROGRESS : "registra por día"

    USERS {
        uuid id PK
        varchar google_id UK
        varchar email UK
        varchar name
        timestamp created_at
        boolean onboarding_completed
    }

    PROFILES {
        uuid id PK
        uuid user_id FK "UNIQUE — una fila por usuario"
        varchar age_range
        varchar main_goal
        timestamp created_at
        timestamp updated_at
    }

    HABIT_RECORDS {
        uuid id PK
        uuid user_id FK
        varchar domain "enum: sleep, nutrition, physical_activity, hydration, screen_time, stress"
        varchar key
        varchar value
        timestamp recorded_at
        timestamp updated_at
    }

    SCIENTIFIC_DOCUMENTS {
        uuid id PK
        varchar title
        varchar authors
        varchar organization "revista cuando viene del panel"
        integer year
        varchar language
        varchar source_url
        varchar doi "0006 — nullable"
        varchar domain "0006 — dominio de búsqueda, nullable"
        varchar file_path
        timestamp created_at
    }

    DOCUMENT_CHUNKS {
        uuid id PK
        uuid document_id FK
        text content
        integer page_number
        integer chunk_index
        float[] embedding "ARRAY(FLOAT), no pgvector — ver D-12"
    }

    CONVERSATIONS {
        uuid id PK
        uuid user_id FK
        varchar title "siempre NULL hoy — no hay auto-generación de título"
        timestamp created_at
        timestamp updated_at
    }

    MESSAGES {
        uuid id PK
        uuid conversation_id FK
        varchar role "user | assistant"
        text content
        jsonb sources "0007 — referencias mostradas con la respuesta; NULL en mensajes del usuario y anteriores a 0007"
        timestamp created_at
    }

    DISCOVERY_RUNS {
        uuid id PK
        uuid created_by FK "usuario admin que lanzó la búsqueda"
        varchar domains "códigos separados por coma, ej. sleep,hydration"
        timestamp created_at
    }

    DOCUMENT_CANDIDATES {
        uuid id PK
        uuid run_id FK
        varchar domain
        varchar external_id "PMCID de Europe PMC — UNIQUE junto con run_id"
        varchar doi
        varchar title
        varchar authors
        varchar journal
        integer year
        text abstract
        varchar language
        varchar license
        varchar landing_url
        varchar pdf_url
        varchar status "pending, approved, rejected, ingesting, ingested, failed"
        text error
        timestamp reviewed_at
        timestamp heartbeat_at "0008 — último latido del lote que lo indexa"
    }

    DAILY_TASKS {
        uuid id PK
        uuid user_id FK
        varchar task_key "clave del catálogo en código (task_catalog.py), no una FK"
        integer target "1 = casilla; mayor que 1 = contador"
        time reminder_time "0009 — hora local del recordatorio, nullable"
        timestamp created_at
        timestamp archived_at "NULL = activa; asignado = quitada, conserva historial"
    }

    TASK_PROGRESS {
        uuid id PK
        uuid task_id FK
        date day "fecha local de la persona, UNIQUE junto con task_id"
        integer progress "de 0 a target"
        timestamp updated_at
    }
```

**Notas de diseño (decisiones reales, ver [`../decisions.md`](../decisions.md)):**
- `profiles.user_id` es `UNIQUE` — decisión propia (no explícita en el plan) de que solo existe **una** fila de perfil por usuario, actualizada por `PUT /profile` (upsert).
- `habit_records` es un **log append-only**: `POST /habits` siempre crea una fila nueva; `PUT /habits/{id}` solo edita una fila existente. Por eso tiene `recorded_at` (cuándo se registró originalmente) *y* `updated_at` (última edición) por separado.
- `domain` de `habit_records` está validado en el backend contra un enum cerrado de 6 valores (los dominios del plan, sección 2), aunque la columna en sí sea `VARCHAR` — la validación vive en `app/schemas/habit_record.py`, no en un `CHECK` de PostgreSQL. El `domain` de `document_candidates` / `scientific_documents` es otro catálogo, de 7 valores (agrega `substance_use`), usado solo para buscar documentos (D-17).
- `document_chunks.embedding` es `ARRAY(FLOAT)`, no `vector` de pgvector — pgvector no está disponible en el entorno de desarrollo (ver D-12 en `docs/decisions.md`). Su dimensión depende del modelo de embeddings activo (384 con `multilingual-e5-small`); al cambiar de modelo hay que reindexar (D-20).
- `messages.conversation_id` no tiene `ondelete=CASCADE` — borrar una conversación borra primero sus mensajes explícitamente (`chat_service.delete_conversation`, con un `db.flush()` intermedio, necesario porque este proyecto no usa `relationship()` de SQLAlchemy y el unit-of-work no infiere el orden de los DELETE por sí solo).
- `messages.sources` es una **copia** (JSONB) de las referencias, no una relación con `scientific_documents`: la cita queda tal como se mostró aunque después se corrijan los metadatos del documento (D-18).
- `daily_tasks.task_key` apunta al catálogo, que vive en código (`backend/app/services/task_catalog.py`), no en una tabla: cambiar el catálogo es un cambio de código revisado (D-24). El `target` se copia del catálogo al activar la tarea.
- `daily_tasks` tiene un índice único **parcial** `(user_id, task_key) WHERE archived_at IS NULL`: una persona no puede tener la misma tarea activa dos veces, pero sí volver a activar una que archivó. `task_progress` es único por `(task_id, day)`.
- `task_progress.day` es la **fecha local** que envía la app, no un instante UTC; el servidor solo acepta fechas a ±1 día de la suya. No hay zona horaria en `profiles` (D-24).
- `document_candidates` **no** tiene FK hacia `scientific_documents`: el vínculo entre un candidato indexado y su documento es el `doi`, que también evita indexar dos veces el mismo artículo (D-21). `UNIQUE (run_id, external_id)` impide repetir un artículo dentro de una misma búsqueda; entre búsquedas la deduplicación la hace `candidate_service.known_identifiers`.
