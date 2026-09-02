# Ingestion

Fuentes científicas usadas por el RAG de HabitQ (ver plan sección 12-13) y el
script que las carga a Postgres.

## Estructura

```text
ingestion/
├── data/
│   └── scientific_documents/
│       ├── manifest.json      # metadata de cada PDF (título, idioma, organización, ...)
│       └── *.pdf
├── scripts/
│   └── ingest.py               # dispara la ingesta
└── README.md
```

## Agregar un PDF nuevo

1. Copiá el PDF a `data/scientific_documents/`.
2. Agregá una entrada al `manifest.json` con al menos `file`, `title` y
   `language`. Campos opcionales: `authors`, `organization`, `year`,
   `source_url` (usá `null` si no lo sabés con certeza — no inventes datos).

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
