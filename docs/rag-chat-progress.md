# Fase 3 (RAG/IA) — estado al pausar (2026-09-01)

Rama `feature/rag-chat`, creada desde `feature/google-login` tras una sesión de scoping (`/grill-me`) para no romper el núcleo ya estable. Este documento se escribe al pausar el trabajo, para retomarlo sin perder contexto — sea en esta sesión o en una futura.

## Hecho en este bloque

**Entorno verificado, no solo asumido:**
- PostgreSQL 17: validado tras una reinstalación accidental del instalador — servicio activo, base `habitq` intacta (1 usuario, 1 perfil, 9 `habit_records`), migración en `0003`. Sin daños.
- `pgvector`: confirmado **ausente** (ni en Stack Builder/Spatial Extensions, ni reinstalando el instalador específico de PostgreSQL). Decisión: **fallback sin pgvector** — embeddings como `ARRAY(FLOAT)` + similitud coseno calculada en Python. Corpus chico (20-40 documentos según el plan) lo hace viable sin necesitar una extensión de base de datos.
- `sentence-transformers`: instalado y probado con éxito. Modelo `all-MiniLM-L6-v2`, embedding real de 384 dimensiones generado en 0.12s (tras ~7.5 min de descarga inicial del modelo, la primera vez).

**Cambios sin commitear hasta este punto:**
- `backend/requirements.txt`: `+pymupdf +sentence-transformers`.
- `ingestion/data/scientific_documents/` (nuevo, para probar la pipeline de ingesta):
  - `who-physical-activity-at-a-glance.pdf` — OMS, actividad física, 1.4MB.
  - `cdc-healthy-sleep-healthy-brain.pdf` — CDC, sueño, 0.7MB.
- `docs/incidents/2026-09-01-claude-proxy-interruption.md` — investigación de una interrupción percibida por el usuario (ver nota abajo), escrita por otra sesión en paralelo, verificada como exacta.

**Verificación:** suite completa de tests backend en verde (28/28) después de instalar las dependencias nuevas — no rompió nada del núcleo ya implementado (auth, profile, habits).

## Pendiente — próxima sesión de implementación

Retomar desde el paso 6 del plan aprobado en la sesión de `/grill-me` (ver `docs/decisions.md` para las decisiones de arquitectura ya tomadas):

1. Modelo + migración Alembic (`down_revision` → `0003`): tablas `scientific_documents` y `document_chunks`. La columna `embedding` va como `ARRAY(FLOAT)`, **no** `Vector` — por la decisión de fallback de arriba.
2. Servicio de ingesta (TDD, mismo patrón de fakes usado en el resto del backend): extracción de texto (PyMuPDF) → limpieza → chunking (800-1200 tokens, overlap 100-150, plan sección 12) → embedding (sentence-transformers) → guardado en base.
3. Punto de entrada para disparar la ingesta de un PDF — script standalone en `ingestion/scripts/` (decisión ya tomada, no bloqueante).
4. Verificación end-to-end manual: ingerir los 2 PDFs ya descargados, confirmar que quedan chunks + embeddings en la base.

**Explícitamente fuera de este bloque (no empezado):** retrieval real sobre una pregunta, integración con Gemini (pospuesta por decisión explícita), `POST /chat`, tablas `conversations`/`messages`, Chat UI en mobile, historial de conversaciones. Detalle completo en el plan de la sesión de `/grill-me`.

## Nota sobre la interrupción reportada (~16:20 COT)

El usuario percibió un mensaje relacionado con un proxy mientras esta sesión esperaba una tarea en segundo plano (descarga del modelo de embeddings, ~7.5 minutos). Validado con evidencia directa: esta sesión **no se cayó** — el trabajo en curso no se perdió, ningún archivo quedó corrupto, y los resultados se entregaron normalmente al terminar la tarea. El estado público de Anthropic no mostraba incidentes coincidentes con ese horario. Detalle completo de la investigación (hecha por otra sesión en paralelo, verificada por esta) en [`incidents/2026-09-01-claude-proxy-interruption.md`](./incidents/2026-09-01-claude-proxy-interruption.md).

## Cómo retomar

1. `git checkout feature/rag-chat`
2. Confirmar que `backend/.venv` tiene `pymupdf` y `sentence-transformers` instalados (`pip list`, o reinstalar desde `requirements.txt` si es una máquina distinta).
3. Continuar con el paso 1 de "Pendiente" arriba.
