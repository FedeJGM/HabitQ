# Ingestion

Fuentes científicas usadas por el RAG de HabitQ (ver plan sección 12-13) y los scripts que las cargan a Postgres.

## Dos formas de agregar documentos

| Vía | Úsala para | Cómo |
|---|---|---|
| **Panel `/admin`** | Artículos de acceso abierto de Europe PMC, con aprobación humana antes de descargar | [README de la raíz, sección 7](../README.md#7-panel-de-administración-opcional) |
| **`ingest.py` + `manifest.json`** | PDFs institucionales (OMS, CDC) o cualquier PDF que ya tengas | Más abajo |

Si cambias el modelo de embeddings, usa **`reindex.py`** (más abajo).

## Estructura

```text
ingestion/
├── data/
│   └── scientific_documents/
│       ├── manifest.json      # metadata de los PDFs cargados con ingest.py
│       └── *.pdf              # los del manifest y los que baja el panel (PMCxxxxxxx.pdf)
├── scripts/
│   ├── ingest.py               # carga los PDFs del manifest
│   └── reindex.py              # recalcula chunks y vectores de todos los documentos
└── README.md
```

Los PDFs que descarga el panel quedan en la misma carpeta pero **no están en el manifest** (su metadata vive en la base). No los commitees.

## Agregar un PDF a mano (manifest)

1. Copiá el PDF a `data/scientific_documents/`.
2. Agregá una entrada al `manifest.json` con al menos `file`, `title` y
   `language`. Campos opcionales: `authors`, `organization`, `year`,
   `source_url` (usá `null` si no lo sabés con certeza — no inventes datos).

> `source_url`, `authors` y `year` son los que alimentan las referencias del chat (autores, año, enlace). Con `null` la referencia sale incompleta. El manifest no tiene `doi` ni `domain`; esos dos campos solo se llenan con documentos que entran por el panel.

## Correr la ingesta

Requiere `backend/.venv` con `pymupdf` y `sentence-transformers` instalados,
y el mismo `.env` de la raíz del repo que usa el backend (misma
`DATABASE_URL` — la ingesta escribe en la base real, no en una de test).

```powershell
backend\.venv\Scripts\python.exe ingestion\scripts\ingest.py
```

Para ingerir un solo PDF del manifest:

```powershell
backend\.venv\Scripts\python.exe ingestion\scripts\ingest.py --only who-physical-activity-at-a-glance.pdf
```

Un PDF ya ingerido (mismo `file_path` ya guardado en `scientific_documents`)
se salta automáticamente — correr el script de nuevo no duplica datos.

Cada documento se guarda en una sola transacción: si falla el cálculo de embeddings no queda un documento sin chunks.

## Reindexar (después de cambiar el modelo de embeddings)

Los vectores de modelos distintos **no son comparables**. Si actualizaste desde una versión que usaba `all-MiniLM-L6-v2`, o cambiaste `EMBEDDING_MODEL_NAME`, reindexá antes de usar el chat: sin esto no hay error, pero el chat recupera fragmentos equivocados.

```powershell
backend\.venv\Scripts\python.exe ingestion\scripts\reindex.py --dry-run   # lista lo que se tocaría
backend\.venv\Scripts\python.exe ingestion\scripts\reindex.py             # reindexa
```

| Qué hace | Detalle |
|---|---|
| Fuente del texto | El PDF de `file_path` si todavía existe (así el tamaño de los chunks sigue el límite del modelo nuevo); si no, re-vectoriza el texto ya guardado |
| Seguridad | Un documento por transacción: si falla, conserva sus chunks anteriores. El script se puede repetir |
| Qué no toca | Metadata de los documentos, conversaciones ni candidatos |

## Modelo de embeddings

| Aspecto | Valor |
|---|---|
| Modelo por defecto | `intfloat/multilingual-e5-small` (384 dimensiones, 512 tokens) |
| Configuración | Variable `EMBEDDING_MODEL_NAME` en el `.env` |
| Por qué multilingüe | Las preguntas llegan en español y los documentos están en inglés (D-20) |
| Prefijos | E5 exige `query: ` en las preguntas y `passage: ` en el texto indexado; `EmbeddingModel` (`backend/app/services/embedding_service.py`) los agrega solo |
| Tamaño de chunk | Nunca supera el límite del modelo (510 tokens de texto con E5-small), para que todo el chunk sea buscable (D-19) |
| Primera vez | Descarga ~450 MB de Hugging Face; después se carga desde disco sin usar la red |
