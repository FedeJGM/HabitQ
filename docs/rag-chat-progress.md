# Fase 3 (RAG/IA) — progreso

Rama `feature/rag-chat`, creada desde `feature/google-login` tras una sesión de scoping (`/grill-me`) para no romper el núcleo ya estable. Este documento se escribe para llevar el estado del trabajo sin perder contexto entre sesiones.

## Actualización (2026-09-02)

Los 4 pasos listados como "Pendiente" en la sección de abajo (estado al pausar 2026-09-01) ya están **completos**:

1. Modelo + migración Alembic → commit `e46b6d3`.
2. Servicio de ingesta (TDD) → commit `c9cbf85`.
3. Script standalone `ingestion/scripts/ingest.py` → commit `8b7754b`.
4. Verificación E2E manual → confirmada por el usuario: los 2 PDFs corridos contra Postgres real, `document_chunks` con `embedding` poblado, suite completa en verde.

Lo que seguía en ese momento (ver "Explícitamente fuera de este bloque" abajo) también se completó después, en la misma sesión: retrieval real, integración Gemini, `POST /chat`, tablas `conversations`/`messages`, Chat UI, historial de conversaciones, personalización con perfil/hábitos, y reintento de errores de Gemini. Ver la sección "Actualización (2026-09-02) — Fase 3 completa" más abajo para el detalle.

El resto de este documento (secciones "Hecho en este bloque", "Pendiente" y "Cómo retomar") describe el estado tal como quedó al pausar el 2026-09-01 — se conserva como registro histórico, no como la lista de tareas activa.

## Actualización (2026-09-02) — Fase 3 completa

Con esto, **toda la Fase 3 del plan (RAG) y su extensión de Fase 4 relacionada con el chat quedan cerradas**. Además de los 4 pasos de ingesta ya marcados arriba como completos, en la misma sesión se implementó y verificó (unit tests + llamadas reales contra Postgres y la API de Gemini):

- Migración `0005` (`conversations`/`messages`) → commit `34b1eee`.
- Servicio de retrieval (similitud coseno, sin pgvector) → commit `a3406d5`.
- Servicio de Gemini (`llm_service.py`) → commit `9ee1188`.
- `POST /chat` (retrieval + Gemini + persistencia atómica) → commit `6842b45`.
- `GET/DELETE` de conversaciones → commit `8c785ea`.
- Chat UI en mobile → commit `0a41630`.
- Historial de conversaciones en mobile → commit `55f3912`.
- Personalización con perfil/hábitos → commit `aee8ec2`.
- Reintento de errores de Gemini → commit `294df18`.

No queda ningún ítem de la Fase 3 del plan sin implementar. El detalle completo de cada decisión de diseño está en `docs/decisions.md` (D-12 a D-16).

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

*(histórico — ver "Actualización" arriba; los 3 pasos de abajo ya están hechos, se conservan por contexto)*

1. `git checkout feature/rag-chat`
2. Confirmar que `backend/.venv` tiene `pymupdf` y `sentence-transformers` instalados (`pip list`, o reinstalar desde `requirements.txt` si es una máquina distinta).
3. Continuar con el paso 1 de "Pendiente" arriba.
