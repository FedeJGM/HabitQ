# Modelo entidad-relación

## Implementado (migraciones `0001`–`0003`)

```mermaid
erDiagram
    USERS ||--o| PROFILES : "tiene"
    USERS ||--o{ HABIT_RECORDS : "registra"

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
```

**Notas de diseño (decisiones reales, ver [`../decisions.md`](../decisions.md)):**
- `profiles.user_id` es `UNIQUE` — decisión propia (no explícita en el plan) de que solo existe **una** fila de perfil por usuario, actualizada por `PUT /profile` (upsert).
- `habit_records` es un **log append-only**: `POST /habits` siempre crea una fila nueva; `PUT /habits/{id}` solo edita una fila existente. Por eso tiene `recorded_at` (cuándo se registró originalmente) *y* `updated_at` (última edición) por separado.
- `domain` está validado en el backend contra un enum cerrado de 6 valores (los dominios del plan, sección 2), aunque la columna en sí sea `VARCHAR` — la validación vive en `app/schemas/habit_record.py`, no en un `CHECK` de PostgreSQL.

## Planeado, no implementado (Fase 3 del plan — RAG)

```mermaid
erDiagram
    USERS ||--o{ CONVERSATIONS : "inicia"
    CONVERSATIONS ||--o{ MESSAGES : "contiene"
    SCIENTIFIC_DOCUMENTS ||--o{ DOCUMENT_CHUNKS : "se divide en"

    CONVERSATIONS {
        uuid id PK
        uuid user_id FK
        varchar title
        timestamp created_at
        timestamp updated_at
    }

    MESSAGES {
        uuid id PK
        uuid conversation_id FK
        varchar role "user | assistant"
        text content
        timestamp created_at
    }

    SCIENTIFIC_DOCUMENTS {
        uuid id PK
        varchar title
        varchar authors
        varchar organization
        integer year
        varchar language
        varchar source_url
        varchar file_path
        timestamp created_at
    }

    DOCUMENT_CHUNKS {
        uuid id PK
        uuid document_id FK
        text content
        integer page_number
        integer chunk_index
        vector embedding "pgvector"
    }
```

Definición completa en `HABITQ_DEVELOPMENT_PLAN.md`, sección 8. Ninguna de estas 4 tablas tiene migración todavía.
