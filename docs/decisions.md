# Decisiones de arquitectura y producto

Registro de decisiones tomadas durante la implementación que **no** estaban explícitamente definidas en `HABITQ_DEVELOPMENT_PLAN.md`, o que resuelven una ambigüedad/conflicto del plan. Formato corto: contexto → decisión → alternativas → consecuencias. Todas fechadas 2026-09-01 salvo que se indique lo contrario.

---

## D-01 — Autenticación de endpoints vía `get_current_user`

**Contexto:** el plan exige que ningún endpoint confíe en un `user_id` enviado por el cliente (sección 10), pero no detalla el mecanismo.

**Decisión:** dependency de FastAPI (`get_current_user` en `app/api/deps.py`) que decodifica el JWT con `HTTPBearer`, castea el claim `sub` a UUID, y busca el usuario en base. 401 si el token es inválido/expirado o el usuario no existe.

**Consecuencias:** todo endpoint privado nuevo reutiliza esta única dependency — no hay lógica de auth duplicada.

---

## D-02 — `profiles`: una fila por usuario, `PUT` hace upsert

**Contexto:** el plan define `GET/PUT /profile` (sección 9) sin `POST`, pero no aclara si puede haber múltiples perfiles por usuario.

**Decisión:** `profiles.user_id` es `UNIQUE`. `PUT /profile` crea la fila si no existe o actualiza la existente.

**Alternativas consideradas:** exigir `POST` primero y `PUT` solo para editar — descartada porque el plan no expone `POST /profile`.

---

## D-03 — `habit_records`: log append-only, no upsert

**Contexto:** el modelo tiene `recorded_at` *y* `updated_at` por separado (plan, sección 8), y la API expone `POST /habits` + `PUT /habits/{id}` por separado (a diferencia de `profiles`).

**Decisión:** `POST /habits` **siempre** crea una fila nueva (nunca actualiza una existente con la misma `domain`/`key`). `PUT /habits/{id}` solo edita una fila ya existente, identificada por su `id`.

**Consecuencias:** un usuario puede, en teoría, tener múltiples registros históricos para la misma pregunta si se llamara `POST /habits` más de una vez con la misma `key` — no ocurre en el flujo actual (el onboarding solo llama `POST` una vez por pregunta), pero cualquier futura feature que reutilice `POST /habits` debe tenerlo presente.

**Validación de propiedad:** `PUT /habits/{id}` devuelve 404 (no 403) si el registro no existe o pertenece a otro usuario, para no filtrar la existencia de registros ajenos.

---

## D-04 — `domain` de hábitos: enum cerrado a 6 valores

**Contexto:** el plan define 6 dominios de hábitos (sección 2) pero el campo `domain` en el modelo de datos es `VARCHAR` libre.

**Decisión:** `app/schemas/habit_record.py` define `HabitDomain` (Enum: `sleep`, `nutrition`, `physical_activity`, `hydration`, `screen_time`, `stress`). Pydantic rechaza cualquier otro valor con 422. La columna en la base sigue siendo `VARCHAR` (validación en la capa de aplicación, no un `CHECK` de PostgreSQL).

**Consecuencias:** mobile y backend deben usar exactamente estos 6 códigos en inglés — están espejados en `mobile/lib/features/habits/habit_questions.dart`.

---

## D-05 — Convención de `key`/`value` para respuestas de hábitos

**Contexto:** `key` y `value` son `VARCHAR` libres; el plan no define códigos para las 9 preguntas del cuestionario.

**Decisión:** `key` en snake_case en inglés (`hours`, `screen_before_bed`, `fruits_vegetables`, `fast_food`, `days_per_week`, `sedentary_hours`, `daily_intake`, `recreational_hours`, `frequency`). `value` como código corto (`less_5`, `5_6`, `7_8`, `more_8`, `never`/`sometimes`/`often`, etc.) en vez del texto en español mostrado en pantalla — consistente con que `domain` también son códigos en inglés.

**Fuente única de verdad:** `mobile/lib/features/habits/habit_questions.dart` (compartido entre `OnboardingHabitsScreen` y `HabitsScreen` para que no diverjan).

---

## D-06 — Rangos de edad y objetivos de perfil: opciones fijas

**Contexto:** `age_range` y `main_goal` son `VARCHAR` libres; el plan no define opciones.

**Decisión:** 5 rangos de edad fijos (`18-24` … `55+`) y 6 objetivos fijos, mapeados 1:1 a los dominios de hábitos (`sleep_better`, `eat_better`, `move_more`, `hydrate_more`, `reduce_screen_time`, `manage_stress`).

**Fuente única de verdad:** `mobile/lib/features/profile/profile_options.dart` (compartido entre `OnboardingScreen` y `ProfileScreen`).

**Pendiente:** si existe un mockup de Figma con una taxonomía distinta, esta decisión debería revisarse.

---

## D-07 — Home sigue el plan escrito, no el mockup con gamificación

**Contexto:** `Diseño/Inicio.png` incluye una tarjeta de logro/racha ("Felicitaciones! Te has levantado antes de las 8:30 tres días seguidos"), un badge "+100AC" y un tab "Actividad" — pero el plan (sección 2, "Fuera del MVP") excluye explícitamente Gamificación, Puntos, Logros, Retos, Rankings, Dashboards y Gráficos de progreso. El mockup también nombra al asistente "Carmelo" en vez de "HabitQ".

**Decisión (confirmada explícitamente por el usuario, no asumida):** la pantalla Home implementada sigue el plan escrito. Sin logros, sin racha, sin tab de estadísticas.

**Consecuencias:** cualquier otro mockup en `Diseño/` debe revisarse con el mismo criterio antes de implementarlo — puede reflejar una exploración visual anterior al recorte de alcance del MVP.

**Actualización (2026-10-15):** la pestaña «Actividad» del mockup se implementó después, limitada a un checklist diario y sin gamificación ni estadísticas (D-23). Lo demás de esta decisión sigue vigente.

---

## D-08 — Consentimiento inicial: persistencia local, no en backend

**Contexto:** el plan lista "Consentimiento inicial" como incluido en el MVP (sección 2) sin especificar diseño ni persistencia.

**Decisión (confirmada explícitamente por el usuario):** el flag de aceptación se guarda solo en el dispositivo (secure storage), no en el backend. No se agregó columna a `users` ni migración.

**Alternativas consideradas:** persistir `consent_accepted_at` en `users` — descartada por el usuario para mantener el alcance mínimo.

**Consecuencias:** un usuario que reinstale la app o cambie de dispositivo vuelve a ver la pantalla de consentimiento aunque su cuenta ya la haya aceptado antes. Aceptable para el MVP.

**Pendiente:** el texto del consentimiento (`mobile/lib/features/consent/consent_screen.dart`) fue redactado por Claude como borrador — el usuario debe revisarlo/ajustarlo antes de la entrega final.

---

## D-09 — `/auth/refresh` sin tabla de refresh tokens separada

**Contexto:** el plan lista `POST /auth/refresh` en la API mínima (sección 9), pero el modelo de datos (sección 8) no incluye ninguna tabla de sesiones/refresh tokens.

**Decisión:** `/auth/refresh` reemite un JWT nuevo a partir de uno todavía válido (mismo mecanismo que cualquier endpoint protegido: `get_current_user` + `create_access_token`). No es un refresh token clásico de larga duración — es, en la práctica, "renovar mientras la sesión actual siga viva".

**Justificación:** consistente con la regla del plan "no comenzar con arquitectura compleja" (sección 20).

---

## D-10 — `/auth/logout` no invalida el JWT server-side

**Contexto:** mismo problema que D-09 — no hay tabla de sesiones/blacklist.

**Decisión:** `/auth/logout` exige un JWT válido (protegido) y devuelve 204, pero no tiene ningún efecto sobre la validez del token — el backend no tiene forma de revocarlo. La limitación está documentada como comentario en el código (`backend/app/api/routes/auth.py`).

**Mitigación real:** el cliente (`AuthService.signOut()`) llama a este endpoint best-effort y luego borra el JWT localmente — la sesión termina ahí, no porque el backend lo haya invalidado.

---

## D-11 — Código dependiente de `FlutterSecureStorage` no se testea directamente

**Contexto:** se necesitaba decidir el nivel de testing para `AuthService.signOut()`, `TokenStorage`, `ConsentStorage`.

**Decisión, con evidencia empírica:** se probó que una llamada real a `FlutterSecureStorage` sin mock, ejecutada dentro de un `testWidgets()`, **cuelga el test indefinidamente** (no lanza excepción). Por eso ninguno de estos tres componentes tiene un test unitario que ejercite su cuerpo real — se verifican indirectamente a través de los fakes que las pantallas que los consumen inyectan por constructor.

**Consecuencias para el equipo:** cualquier código nuevo que use `FlutterSecureStorage` directamente debe seguir el mismo patrón de inyección (parámetro opcional en el constructor con fallback a la instancia real) para permanecer testeable — nunca ejercitar la ruta real dentro de un test.

---

## D-12 — Chunking usa el tokenizer real del modelo de embeddings, no una aproximación

**Contexto:** el plan (sección 12) define los límites de chunking en tokens (800-1200, overlap 100-150), pero no especifica cómo contar "tokens" — la opción más simple habría sido aproximar por palabras, o agregar una librería de tokenización nueva (ej. `tiktoken`, pensada para modelos OpenAI).

**Decisión:** `chunk_text` (`backend/app/services/ingestion_service.py`) recibe un `tokenize: Callable[[str], list]` inyectado. En producción, `ingest_document` le pasa `model.tokenizer.encode` — el tokenizer real de `sentence-transformers` (`all-MiniLM-L6-v2`), que ya está disponible sin instalar nada adicional. *(Actualización: desde D-20 el modelo activo es `multilingual-e5-small`; el criterio —contar con el tokenizer del modelo en uso— no cambia.)*

**Justificación:** los límites de chunk deben corresponder al tokenizer que realmente va a procesar ese texto al generar el embedding — una aproximación por palabras o un tokenizer de otro modelo (`tiktoken`/OpenAI) puede desviarse significativamente del conteo real, sub- o sobre-llenando chunks respecto al límite de contexto del modelo.

**Cómo se cuenta sin decodificar:** en vez de tokenizar el texto completo y decodificar cada ventana de vuelta a texto (lo cual con un tokenizer WordPiece no reconstruye el texto original de forma confiable), se tokeniza cada palabra por separado una sola vez y se usa la suma acumulada de esos conteos para decidir los límites de cada chunk sobre el texto partido por palabras (`text.split()`). El chunk resultante se reconstruye con `" ".join(...)`, siempre exacto. Es una aproximación (ignora que un tokenizer subword puede fusionar tokens en los bordes entre palabras), aceptable para un límite de tamaño de chunk, no para un conteo exacto.

**Testing:** los tests de `chunk_text` inyectan un fake (`str.split` aplicado por palabra) en vez de cargar el modelo real — evita lentitud y dependencia de red en la suite.

---

## D-13 — Refresco de JWT proactivo en mobile, no reactivo

**Contexto:** el gap pendiente de "interceptor de refresh token" (mobile no llama a `POST /auth/refresh` en ningún momento) se planteó inicialmente como un interceptor reactivo clásico (reintentar la request tras un 401). Eso no funciona con este backend: según D-09, `/auth/refresh` reemite un JWT nuevo a partir de uno **todavía válido** — usa el mismo mecanismo (`get_current_user`) que cualquier endpoint protegido. Si el JWT ya expiró y una request cualquiera devuelve 401, llamar a `/auth/refresh` con ese mismo token expirado también devuelve 401.

**Decisión:** refresco proactivo, no reactivo. `AuthService.refreshTokenIfNeeded()` (`mobile/lib/features/auth/auth_service.dart`) decodifica el `exp` del JWT guardado (`mobile/lib/core/utils/jwt.dart`, decode manual sin dependencia nueva — no verifica firma, solo lee el payload) y, si falta menos de 60 minutos para que expire (o ya expiró), llama a `/auth/refresh` y guarda el token nuevo. Se dispara en `mobile/lib/main.dart`: una vez al arrancar (`initState`, en la práctica casi siempre no-op) y cada vez que la app vuelve a primer plano (`AppLifecycleState.resumed`, vía `WidgetsBindingObserver`) — el caso real es la app backgroundeada durante horas con una sesión ya iniciada.

**Si el refresh también falla** (token ya vencido hace rato): se borra el token guardado (`TokenStorage.delete()`) en vez de dejarlo indefinidamente. No hay pantalla de auto-login que redirigir — la app hoy siempre arranca en `LoginScreen` (`initialRoute` fijo en `main.dart`), así que no hace falta navegar desde acá; la siguiente pantalla que llame a la API va a fallar igual, pero al menos no queda un JWT muerto en storage.

**Limpieza en el camino:** `AuthService` tenía su propia instancia de `FlutterSecureStorage` y una constante `_tokenKey` duplicada con `TokenStorage.key` (el comentario en `token_storage.dart` ya advertía "must stay in sync"). Se unificó: `AuthService` ahora recibe un `TokenStorage` inyectable (mismo patrón de D-11) y usa sus métodos `read()`/`write()`/`delete()` en vez de tocar `FlutterSecureStorage` directamente.

**Testing:** siguiendo D-11, ningún test ejercita `FlutterSecureStorage` real. Los fakes (`_FakeTokenStorage implements TokenStorage`, mismo patrón que `_FakeApiClient implements ApiClient`) solo necesitan implementar `read()`/`write()`/`delete()` — los miembros privados de `TokenStorage` no forman parte de la interfaz que Dart exige implementar. Se confirmó empíricamente que la llamada fire-and-forget a `refreshTokenIfNeeded()` en `initState()` de `HabitQApp`, incluso con el `AuthService()` real por default, no cuelga el widget test existente (`widget_test.dart`) — a diferencia del caso descrito en D-11, acá nunca se espera (`await`) esa llamada desde el widget.

---

## D-14 — Nombre de modelo Gemini: usar el alias `gemini-flash-latest`, no una versión fija

**Contexto:** al integrar `google-genai` (2026-09-02) para el servicio de LLM (`backend/app/services/llm_service.py`), el nombre de modelo que aparecía en ejemplos/documentación al momento de escribir el código (`gemini-2.0-flash`) ya no existe — la API devuelve 404 y sugiere migrar a un modelo más nuevo. Probar `gemini-2.5-flash` tampoco funcionó: 404, "no longer available to new users" (la API key de este proyecto es nueva). Los modelos de Google evolucionan más rápido de lo que cualquier nombre fijo escrito en código puede seguir.

**Decisión:** usar el alias `gemini-flash-latest` (no una versión numerada como `gemini-3.6-flash` o similar) como `_MODEL` en `llm_service.py`. Google mantiene este alias apuntando siempre al modelo flash estable más reciente disponible para la cuenta — evita que el código se rompa cada vez que Google retira una versión.

**Nota sobre errores 503 ("high demand"):** son transitorios y esperables en el tier gratuito — no indican un problema de código, config o de la API key. Se confirmó reintentando: la misma llamada que falló 3 veces seguidas funcionó al reintentar. `generate_answer` (P2-3) no implementa retry/backoff todavía — es un ítem separado y explícito del roadmap ("manejo errores Gemini", Fase 4), no de este paso.

**Cómo verificar el modelo correcto en el futuro** (si `gemini-flash-latest` alguna vez deja de existir): `client.models.list()` filtrando por `'generateContent' in m.supported_actions` devuelve los modelos realmente disponibles para esa API key — más confiable que cualquier nombre hardcodeado en documentación o en este archivo.

**Actualización (2026-10-15): reemplazada por D-26.** El código ya no usa el alias: `_MODEL` quedó fijo en `gemini-3.5-flash-lite`. Lo de arriba se conserva como historia y el método de verificación con `client.models.list()` sigue siendo válido.

---

## D-15 — Personalización con perfil/hábitos: el LLM decide la relevancia, no se clasifica programáticamente

**Contexto:** el plan (sección 14) pide "personalizar solo cuando el perfil sea relevante", sin especificar cómo decidir esa relevancia. La alternativa habría sido clasificar la pregunta del usuario para decidir si aplica personalización antes de llamar a Gemini (otro paso de NLP, otra fuente de error).

**Decisión:** mismo criterio ya usado con el contexto de RAG (ver D-14 y `llm_service._SYSTEM_INSTRUCTIONS`): `chat_service.send_message` siempre arma el `user_context` (perfil + hábitos del usuario, si existen — `build_user_context`) y se lo pasa a `generate_answer`, pero la instrucción explícita al modelo es usarlo *solo si es relevante para la pregunta* y no mencionarlo si no viene al caso. No hay clasificación previa de relevancia en el backend.

**Formato del contexto:** texto simple, sin humanizar los códigos de `habit_records` (`domain`/`key`/`value`, ej. `sleep.hours: 5_6`) — esa tabla de humanización (a texto legible en español) solo existe en `mobile/lib/features/habits/habit_questions.dart`, no se replicó en el backend para evitar duplicar la fuente de verdad. **Actualización (2026-10-15): reemplazado por D-26:** desde entonces el backend sí traduce los códigos a español (`user_context_labels.py`), aceptando la duplicación.

**Verificado con una llamada real:** con un usuario real (perfil `18-24`/`sleep_better`, 9 hábitos cargados) y la pregunta "¿Qué puedo hacer para dormir mejor?", Gemini referenció correctamente el hábito `sleep.hours=5_6` en la respuesta ("tus registros indican que estás durmiendo entre 5 y 6 horas"), mientras seguía admitiendo honestamente que el contexto RAG recuperado (un documento de la OMS sobre actividad física, no de sueño) no tenía evidencia específica — mismo comportamiento de no inventar ya validado en D-14.

---

## D-16 — Reintento de errores de Gemini: usar `HttpRetryOptions` del SDK, no un loop propio

**Contexto:** el roadmap (Fase 4) pide manejo de errores de Gemini con reintento — hasta ahora `generate_answer` dejaba que un 503 "high demand" (D-14) se propagara directo a un 502 en `POST /chat`, sin reintentar. La opción obvia habría sido envolver la llamada en un loop manual con backoff.

**Decisión:** `google-genai` ya expone `types.HttpOptions(retry_options=types.HttpRetryOptions(...))`, con reintento automático sobre 408/429/5xx, backoff exponencial y jitter — por defecto `attempts=5`, `max_delay=60.0`. `get_gemini_client()` (`backend/app/services/llm_service.py`) configura `attempts=3, initial_delay=1.0, max_delay=8.0`: los defaults del SDK están pensados para un job en background, no para una request HTTP síncrona donde el usuario espera con `POST /chat` abierto — 5 intentos con hasta 60s de espera cada uno podría dejar la request colgada más de un minuto.

**Por qué no un loop propio:** usar el mecanismo ya provisto por el SDK evita reimplementar backoff/jitter/clasificación de qué códigos ameritan reintento (una fuente de bugs sutiles), y mantiene `generate_answer`/`build_prompt` sin cambios — el reintento vive enteramente en la configuración del cliente.

**Testing:** un test verifica que `get_gemini_client()` arma el cliente con `retry_options.attempts == 3` y `max_delay == 8.0` (inspeccionando `client._api_client._http_options`, un atributo interno del SDK — aceptado como trade-off, no hay una API pública para leerlo de vuelta). Verificado además con una llamada real exitosa después de configurar el retry.

---

## D-17 — Descubrimiento de documentos con aprobación del administrador

**Contexto:** el corpus del RAG eran 2 PDFs cargados a mano, con `source_url`, `year` y `authors` vacíos, así que las referencias del chat eran pobres. Se quiere ampliarlo bajo demanda, sin que ningún documento entre al índice sin revisión humana.

**Decisión (2026-10-10):** pipeline de dos pasos. (1) `POST /admin/discovery` busca en Europe PMC (solo open access, revisiones/metaanálisis/guías, desde 2015, inglés o español) un total de 30 candidatos repartidos entre 7 dominios (sueño, alimentación, actividad física, hidratación, pantallas, estrés, consumo de sustancias) y los guarda como `pending` en `document_candidates`. (2) El administrador abre cada enlace desde el panel `/admin`, aprueba o rechaza, y solo `POST /admin/ingest` descarga, extrae metadatos e indexa los aprobados (en segundo plano).

**Quién es admin:** lista `ADMIN_EMAILS` en el `.env`, comparada contra el correo del usuario autenticado. Sin columna `role` ni migración (mismo criterio de alcance mínimo que D-08/D-09).

**Detalles que importan:**
- Los candidatos rechazados o ya vistos no se vuelven a proponer (deduplicación por PMCID y DOI).
- `consumo de sustancias` existe solo como tema de búsqueda; `HabitDomain` (D-04) y el cuestionario móvil no cambian.
- El PDF se baja de `https://europepmc.org/api/getPdf?pmcid=...`, **no** de la URL `...?pdf=render` que lista Europe PMC: esa está detrás de Cloudflare y responde 403 a clientes que no son navegador (verificado en vivo; ningún User-Agent lo arregla).
- `ingest_document` pasó a ser atómico (documento y chunks en un solo commit): un fallo al generar embeddings ya no deja un documento huérfano sin chunks.

**Consecuencias:** si el servidor se cae a mitad de una indexación, los candidatos quedaban en `ingesting` sin salida (resuelto en D-21). En Docker, los PDFs descargados quedan en una ruta efímera del contenedor.

---

## D-18 — Referencias del chat guardadas como snapshot en `messages.sources`

**Contexto:** `POST /chat` devolvía las fuentes pero no se guardaban: al reabrir una conversación desde el historial las referencias desaparecían.

**Decisión (2026-10-10):** columna `messages.sources` (JSONB, nullable, migración `0007`) con una copia de las referencias mostradas en cada respuesta del asistente (título, organización, URL, autores, año, DOI y páginas recuperadas). `GET /chat/conversations/{id}/messages` las devuelve; `NULL` se expone como lista vacía.

**Alternativa descartada:** tabla normalizada `message_sources`. Habría obligado a tocar `delete_conversation` (no hay cascada ni `relationship()`) y a unir tablas en cada lectura.

**Consecuencias:** la cita queda tal como se mostró; si luego se corrigen los metadatos de un documento, las respuestas viejas conservan los antiguos. Los mensajes anteriores a `0007` no tienen referencias.

---

## D-19 — Chunks acotados por `max_seq_length` y umbral mínimo de relevancia configurable

**Contexto:** medido con la base real, `all-MiniLM-L6-v2` tiene `max_seq_length = 256` y 24 de 39 chunks lo superaban: el texto sobrante se guardaba y se citaba pero no participaba en la búsqueda (en promedio se perdía el 18% de cada chunk, hasta el 47%).

**Decisión (2026-10-10):** `chunk_budget(model)` limita el tamaño del chunk a `max_seq_length - 2` tokens (con overlap proporcional) cuando el modelo expone ese límite; si no, se mantienen los valores del plan (1000 / 125). Además, `retrieve_top_chunks` acepta `min_score` y la configuración `RETRIEVAL_MIN_SCORE` (vacía = sin umbral) lo aplica en el chat: si ningún chunk lo alcanza, el prompt dice que no hay evidencia y no se muestran referencias.

**Por qué el umbral queda desactivado:** los puntajes dependen del modelo y del idioma. Con MiniLM, las preguntas válidas en español puntúan 0.11–0.36 y las absurdas 0.04–0.10, así que ningún valor las separa; el umbral solo tiene sentido después de resolver la recuperación entre idiomas.

**Consecuencias:** los chunks ya indexados conservan su tamaño anterior hasta reindexarlos.

---

## D-20 — Modelo de embeddings multilingüe (`multilingual-e5-small`)

**Contexto:** las preguntas llegan en español y los documentos están en inglés. Medido con la base real, `all-MiniLM-L6-v2` puntuaba 0.11–0.36 con preguntas en español (0.50–0.73 en inglés) y las de sueño recuperaban el documento de actividad física: sus puntajes se confundían con los de preguntas sin sentido (0.04–0.10).

**Decisión (2026-10-10, aprobada por el usuario):** el modelo pasa a ser `intfloat/multilingual-e5-small` (384 dimensiones, 512 tokens), configurable con `EMBEDDING_MODEL_NAME`. Los modelos E5 exigen prefijos: `EmbeddingModel` (`app/services/embedding_service.py`) antepone `query: ` a las preguntas y `passage: ` al texto indexado; el resto del código solo llama `encode` / `encode_query`. El Dockerfile descarga el modelo configurado en el build.

**Reindexado:** los vectores de modelos distintos no son comparables, así que cambiar el modelo obliga a recalcular todo: `ingestion/scripts/reindex.py` reconstruye los chunks de cada documento desde su PDF (o re-vectoriza el texto guardado si el PDF ya no está), un documento por transacción para no perder los chunks viejos si algo falla. Aplicado a la base local: 2 documentos, 39 → 33 chunks.

**Corrección en el camino:** `chunk_text` contaba los tokens palabra por palabra con `tokenizer.encode(palabra)`, lo que suma los marcadores `[CLS]`/`[SEP]` a cada palabra e inflaba el conteo ~2.5x (los chunks salían más cortos de lo previsto). Ahora se cuenta con `add_special_tokens=False`. Esto matiza D-12: el conteo por palabra sigue siendo una aproximación, pero ya no está sesgado.

**Resultado medido (6 preguntas válidas en español, 4 fuera de tema):** las 6 válidas recuperan el documento correcto con puntajes 0.81–0.86; las 4 fuera de tema quedan en 0.72–0.77.

**Umbral de relevancia (D-19) sigue desactivado:** los puntajes de E5 están comprimidos y el margen entre válidas y absurdas es de ~0.04 con solo 2 documentos. Conviene calibrarlo cuando el corpus tenga los ~30 documentos, con unas 20 preguntas etiquetadas.

---

## D-21 — Recuperación de candidatos bloqueados en `ingesting`

**Contexto:** la indexación corre en un `BackgroundTask` dentro del proceso del servidor. Si el proceso muere (reinicio, caída, cierre del contenedor), los candidatos reclamados quedan en `ingesting`: el estado está bloqueado para la revisión (`_LOCKED_STATUSES`) y `ingest_approved` solo toma `approved`, así que no había forma de reintentarlos desde el panel.

**Decisión (2026-10-10):** `document_candidates.heartbeat_at` (migración `0008`). El lote lo escribe al reclamar y lo refresca después de cada documento para los que siguen en cola (un lote de 30 puede durar más que el umbral); se borra al terminar. Un candidato `ingesting` sin latido en 15 minutos (`STALE_AFTER`), o sin latido alguno (filas anteriores a `0008`), se considera bloqueado (`is_stuck`). `POST /admin/ingest` ejecuta `recover_stuck_candidates` antes de contar: los devuelve a `approved` y entran en el mismo lote. Responde `{"queued", "recovered"}`; `GET /admin/candidates` expone `stuck` y el panel los marca como "Bloqueado" con la instrucción de pulsar "Indexar aprobados".

**Reintento idempotente:** si el servidor muere después de indexar pero antes de guardar el estado, el reintento no debe duplicar el documento. `ingest_candidate` comprueba por DOI si ya existe un `scientific_documents` antes de descargar y, de ser así, solo marca el candidato como `ingested`. Un candidato sin DOI no tiene esa protección (ventana de milisegundos entre dos commits).

**Alternativas descartadas:** (a) resetear todos los `ingesting` al arrancar la app: asume un único proceso y pisaría el trabajo de otro worker; (b) un botón de reintento por candidato: con el umbral de latido, "Indexar aprobados" ya cubre el caso sin otro endpoint.

**Verificado:** en la base real se simuló un candidato dejado en `ingesting` hace una hora: se detectó, se recuperó, se indexó con el modelo real y un segundo reintento no creó un documento duplicado.

---

## D-22 — Historial y eliminación de documentos indexados desde el panel

**Contexto:** el panel solo mostraba candidatos; no había forma de ver qué estaba indexado (incluido lo cargado por CLI) ni de retirar un documento malo sin tocar la base a mano.

**Decisión (2026-10-12):** `GET /admin/documents` (filtro opcional `domain`) lista `scientific_documents` del más nuevo al más antiguo con `chunk_count`; `DELETE /admin/documents/{id}` (204; 404 si no existe) lo elimina. Ambos son solo para admin y viven en `document_history_service.py`. El panel suma la sección «3. Historial de documentos» con un botón «Eliminar» con confirmación por tarjeta.

**Eliminación:** `document_chunks` no tiene `ON DELETE CASCADE`, así que se borran primero los chunks y luego el documento, todo en una transacción. El candidato `ingested` con el mismo DOI (sin distinguir mayúsculas) pasa a `rejected`, de modo que el descubrimiento no lo proponga de nuevo (D-17). El PDF se conserva en disco. No se agregó migración.

**Limitación conocida:** `messages.sources` guarda un snapshot de texto, no una FK (D-18), por lo que los mensajes de chat anteriores siguen mostrando la referencia de un documento ya eliminado.


---

## D-23 — Excepción al alcance y al freeze: checklist diario por objetivo

**Contexto:** el plan dejaba fuera "Tareas diarias automáticas" y fijaba el 11 de octubre como cierre de funcionalidades. El diseño Figma incluye una pantalla **Actividad** (`Diseño/Actividad.png`: franja semanal, tareas con casilla, contadores como «Tomar agua 2/8» y recordatorios) que el rediseño de la app descartó porque el backend no tenía tareas. `Diseño/Inicio.png` no contiene ninguna lista de tareas.

**Decisión (2026-10-15):** se reabre el alcance, con aprobación explícita de la persona responsable del proyecto, para un checklist diario ligado al objetivo principal del perfil:
- Nueva pestaña **Actividad** (barra: Inicio / Actividad / Chat / Perfil).
- La persona elige, de un catálogo fijo por cada uno de los 6 objetivos (D-06), qué tareas activar. Sin texto libre.
- Cada tarea tiene una meta (1 = casilla; N = contador) y progreso por día.
- La lista de hoy parte en cero a la medianoche del propio usuario; la franja semanal permite ver días pasados en solo lectura (D-24).
- Recordatorio local opcional por tarea (D-25).

**Sigue fuera del MVP:** tareas generadas automáticamente, notificaciones inteligentes (push o decididas por el servidor), gamificación, logros y puntos, seguimiento por GPS (la caminata se mide en minutos con un contador manual) y cualquier diagnóstico o tratamiento. Las tareas son hábitos de comportamiento, no indicaciones médicas.

**Alternativas descartadas:** (a) dejarlo como mejora posterior al MVP: la persona responsable prefirió incluirlo; (b) mostrar la lista dentro de Inicio: se eligió la pestaña Actividad por fidelidad al Figma; (c) tareas libres escritas por la persona usuaria: abre texto libre y validación de contenido.

**Riesgo asumido:** la regla 5 de la sección 20 y la nota del 11 de octubre quedan con esta excepción documentada. Si el calendario se aprieta, el orden de recorte es: recordatorios, franja semanal, contadores.

---

## D-24 — Modelo de tareas, catálogo servido por la API y día por fecha local

**Contexto:** el backend guarda todas las marcas de tiempo en UTC y no tiene fechas ni zona horaria por usuario. El reinicio «después de medianoche» debe ocurrir en la medianoche de cada persona.

**Decisión (2026-10-15):**
- **Catálogo en código** (`backend/app/services/task_catalog.py`), no en tabla: por objetivo, 4 tareas con `{key, label, target, unit, step}`. `step` es lo que suma un toque en un contador (p. ej. «Caminar» suma de 5 en 5 hasta 30 min). Lo sirve `GET /tasks/catalog` según `profile.main_goal`, de modo que la app no duplica los textos. Solo se puede activar una tarea del catálogo del objetivo del perfil (422 si no; sin perfil no hay catálogo).
- **Dos tablas** (migración `0009`): `daily_tasks` (tareas activadas por la persona: `task_key`, `target`, `reminder_time`, `archived_at`) y `task_progress` (`task_id`, `day DATE`, `progress`, único por `(task_id, day)`). Una tarea queda completada cuando `progress >= target`.
- **Día por fecha local:** la app envía `day=YYYY-MM-DD` con la fecha de su celular y el servidor guarda por esa fecha. No se agrega zona horaria al perfil.
- **Acotación en el servidor:** `day` solo se acepta dentro de ±1 día de la fecha UTC del servidor, lo que cubre cualquier huso horario sin que el servidor lo conozca.
- **Días pasados:** se consultan, pero solo «hoy» es editable; lo hace cumplir la app.
- **Quitar una tarea** la archiva (`archived_at`) y conserva su historial. Una tarea archivada solo se lista en los días en que tiene progreso real (mayor que 0): un 0 es una tarea marcada y desmarcada, no historia. La respuesta lleva `archived: true` en esos casos; la app no la muestra hoy y la muestra en solo lectura en días pasados. (Corrige un defecto hallado en pruebas: una tarea archivada con un 0 seguía visible hoy y al tocarla daba 404.)

**Alternativas descartadas:** (a) campo de zona horaria en el perfil: más piezas y más datos personales para el mismo resultado; (b) catálogo en tabla con panel de administración: sin necesidad en el MVP, un cambio de catálogo es un cambio de código revisado.

**Limitación conocida:** un celular con la hora mal configurada escribe en otro día, dentro del margen de ±1 día. No se detecta ni corrige.

---

## D-25 — Recordatorios locales de tareas

**Contexto:** el plan excluye «Notificaciones inteligentes». El diseño de Actividad muestra un reloj de recordatorio por tarea y la persona responsable pidió incluirlo.

**Decisión (2026-10-15, ajustada tras probar en dispositivo):** el recordatorio es una **notificación local** programada en el celular a la hora que la persona elige (`daily_tasks.reminder_time`). No hay servidor de notificaciones, ni envío push, ni lógica que decida cuándo avisar. El texto es neutro y solo nombra la tarea. Detalles:
- **Una notificación por día, no una repetida:** se programan los próximos 7 días uno por uno y se refrescan cada vez que se abre la pestaña Actividad (`GET /tasks`). Así, si la tarea ya está hecha hoy, solo se omite el aviso de hoy; los de los días siguientes siguen. Marcar o desmarcar una tarea reprograma.
- **Alarmas exactas:** se declara `USE_EXACT_ALARM` (Android 13+, se concede al instalar) y `SCHEDULE_EXACT_ALARM` hasta Android 12L. Si el permiso falta, ese aviso se programa como inexacto en vez de perderse.
- **Ids estables** por tarea y día, derivados del id de la tarea, y la sincronización solo cancela las pendientes: no borra notificaciones ya mostradas ni una nueva reemplaza a otra.
- **Permiso de notificaciones:** en Android 13+ se solicita al fijar un recordatorio. Si se rechaza, la hora se guarda y la tarea funciona sin aviso.
- **Cerrar sesión** cancela todos los recordatorios del teléfono.

**Por qué no contradice la exclusión:** lo excluido son las notificaciones *inteligentes* (decididas por el sistema). Aquí la persona fija la hora y el aviso es fijo.

**Alternativas descartadas:** (a) push desde el servidor: requiere servicio externo y credenciales, fuera del alcance; (b) alarmas inexactas: la primera versión las usó y en el dispositivo (Android 16) una notificación programada a las 23:52 llegó unos 4 minutos tarde, y los avisos de días siguientes tienen una ventana de hasta 1 hora; (c) `SCHEDULE_EXACT_ALARM` en Android 14+: viene denegado y obliga a la persona a activarlo a mano en Ajustes.

**Limitaciones conocidas:**
- `USE_EXACT_ALARM` está pensado para apps de alarmas y calendario y Google Play lo restringe: sirve para la distribución por APK de este proyecto, pero habría que revisarlo (o cambiar a `SCHEDULE_EXACT_ALARM`) si algún día se publica en Play Store.
- Los recordatorios se refrescan al abrir Actividad: si la persona no abre la app en más de 7 días, dejan de llegar hasta que la abra.
- Un aviso que Android alcanzara a retrasar y que aún no se hubiera mostrado se cancelaría si la sincronización corre justo entonces.
- No hay recordatorios en un día pasado ni se programa nada para tareas sin hora.


---

## D-26 — Modelo de chat fijado a `gemini-3.5-flash-lite` y contexto del usuario en español

**Contexto:** el chat pasó del tier gratuito de Gemini a pago por uso. La app solo lee `GEMINI_API_KEY` (`backend/app/core/config.py`): que sea gratuita o de pago es un asunto de facturación del proyecto de Google (se activa en Google AI Studio), sin cambio de código. El alias `gemini-flash-latest` (D-14) puede apuntar a otro modelo, con otro precio, sin avisar. Además el contexto del usuario llegaba al modelo con códigos crudos (`sleep.hours: 5_6`), ambiguos sin la pregunta que respondían (D-15).

**Decisión (2026-10-15):**
- `llm_service._MODEL = "gemini-3.5-flash-lite"`, fijo. Reemplaza el alias de D-14.
- `backend/app/services/user_context_labels.py` traduce a español claro el objetivo principal y cada respuesta del cuestionario de hábitos antes de enviarlas al modelo (`chat_service.build_user_context`). Un código desconocido nunca es un error: se usa el valor crudo.
- Esto reemplaza lo que decía D-15 sobre no humanizar los códigos: las etiquetas se duplican a propósito del móvil (`habit_questions.dart`, `profile_options.dart`) a cambio de que el modelo lea texto sin ambigüedad. **Hay que mantener ambas listas sincronizadas a mano**; el módulo lo avisa en su encabezado.

**Alternativas descartadas:** (a) seguir con el alias: cambios de modelo y de costo sin aviso; (b) que el móvil envíe los textos ya traducidos: el backend arma el contexto desde sus propios datos y no confía en lo que mande el cliente (D-01).

**Verificado:** las pruebas del backend pasaron al hacer el cambio y el chat respondió en el celular tras reconstruir el backend. **Pendiente:** confirmar en Google AI Studio que el uso aparece bajo `gemini-3.5-flash-lite`.

**Limitaciones conocidas:**
- El chat **no envía el historial** de la conversación al modelo: cada pregunta se arma con la pregunta, los fragmentos recuperados y el contexto del usuario (`llm_service.build_prompt`). El historial solo se guarda y se muestra en la app.
- Si el nombre del modelo dejara de existir (404), se revierte el cambio (`ee122b2`) o se elige otro con `client.models.list()` (D-14).
