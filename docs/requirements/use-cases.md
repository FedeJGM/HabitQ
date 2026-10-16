# Casos de uso — implementados

Formato: Actor, Precondición, Flujo principal, Postcondición, Endpoints involucrados. Cubre solo lo construido; para el alcance completo del MVP ver `HABITQ_DEVELOPMENT_PLAN.md`, sección 2. UC-01 a UC-10 y UC-19 a UC-22 son de la persona usuaria; UC-11 a UC-18 son de administración de la base de conocimiento (D-17, D-21). UC-19 a UC-22 son el checklist diario (D-23 a D-25).

## UC-01 — Iniciar sesión con Google

- **Actor:** Usuario (nuevo o existente).
- **Precondición:** Tiene una cuenta de Google válida.
- **Flujo principal:**
  1. El usuario toca "Continúa con Google" en la pantalla de Login.
  2. Selecciona su cuenta de Google.
  3. El backend valida el ID token, crea el usuario si no existe, y emite un JWT.
  4. El JWT se guarda localmente.
- **Postcondición:** Sesión iniciada. El usuario existe en `users` (creado si era su primera vez).
- **Endpoints:** `POST /auth/google`.

## UC-02 — Aceptar el consentimiento inicial

- **Actor:** Usuario recién autenticado, en un dispositivo donde todavía no aceptó.
- **Precondición:** UC-01 completado.
- **Flujo principal:**
  1. El sistema verifica localmente si el consentimiento ya fue aceptado en este dispositivo.
  2. Si no, muestra el texto de consentimiento (descargo de responsabilidad médica, uso de datos).
  3. El usuario toca "Acepto y continúo".
- **Postcondición:** Flag de consentimiento guardado localmente (no en el backend — ver `../decisions.md`). El usuario continúa a Onboarding o Home.
- **Endpoints:** Ninguno — decisión local en el dispositivo.

## UC-03 — Completar el onboarding (perfil básico)

- **Actor:** Usuario con `onboarding_completed = false`.
- **Precondición:** UC-01 y UC-02 completados.
- **Flujo principal:**
  1. El usuario selecciona su rango de edad y su objetivo principal.
  2. El sistema guarda el perfil.
- **Postcondición:** Existe una fila en `profiles` para el usuario. Continúa al cuestionario de hábitos (UC-04).
- **Endpoints:** `PUT /profile`.

## UC-04 — Responder el cuestionario de hábitos

- **Actor:** Usuario que acaba de completar UC-03.
- **Precondición:** UC-03 completado en esta sesión de onboarding.
- **Flujo principal:**
  1. El usuario responde las 9 preguntas (6 dominios: sueño, alimentación, actividad física, hidratación, pantallas, estrés).
  2. Al finalizar, el sistema crea un `habit_record` por cada respuesta.
  3. El sistema marca `onboarding_completed = true`.
- **Postcondición:** 9 filas nuevas en `habit_records`. `users.onboarding_completed = true`. El usuario llega a Home.
- **Endpoints:** `POST /habits` (×9), `POST /auth/onboarding-complete`.

## UC-05 — Ver y editar los hábitos registrados

- **Actor:** Usuario con onboarding completo.
- **Precondición:** UC-04 completado alguna vez.
- **Flujo principal:**
  1. Desde Home, el usuario entra a "Mis hábitos".
  2. El sistema muestra el valor actual de cada pregunta respondida.
  3. El usuario toca una opción distinta para una pregunta.
  4. El sistema actualiza ese registro específico (autosave).
- **Postcondición:** El `habit_record` correspondiente queda actualizado. Una pregunta sin registro previo se muestra como "Sin responder" y no es editable desde aquí.
- **Endpoints:** `GET /habits`, `PUT /habits/{habit_id}`.

## UC-06 — Ver y editar el perfil

- **Actor:** Usuario con onboarding completo.
- **Precondición:** UC-03 completado alguna vez.
- **Flujo principal:**
  1. Desde Home, el usuario entra a "Perfil".
  2. El sistema muestra el rango de edad y el objetivo principal actuales.
  3. El usuario cambia uno de los dos.
  4. El sistema guarda ambos valores juntos (autosave).
- **Postcondición:** `profiles` actualizado para ese usuario.
- **Endpoints:** `GET /profile`, `PUT /profile`.

## UC-07 — Cerrar sesión

- **Actor:** Usuario autenticado.
- **Precondición:** Sesión iniciada (UC-01).
- **Flujo principal:**
  1. El usuario toca el ícono de cerrar sesión en Home.
  2. El sistema intenta notificar al backend (best-effort).
  3. El sistema borra el JWT guardado localmente.
- **Postcondición:** El usuario vuelve a la pantalla de Login. El JWT anterior sigue siendo técnicamente válido hasta su expiración natural (ver limitación en `../architecture/overview.md`).
- **Endpoints:** `POST /auth/logout` (best-effort, no bloqueante).

## UC-08 — Conversar con HabitQ (RAG)

- **Actor:** Usuario autenticado.
- **Precondición:** Ninguna especial — no requiere onboarding completo.
- **Flujo principal:**
  1. El usuario abre el chat desde Home: con el botón único «Chat con HabitQ» si aún no tiene conversaciones, o con «Continuar conversación» (abre la más reciente) o «Nuevo chat con HabitQ» (chat vacío) si ya tiene alguna.
  2. Escribe una pregunta y la envía (se muestra de inmediato, envío optimista).
  3. El sistema recupera los fragmentos de evidencia más relevantes de `document_chunks` (similitud coseno, sin pgvector — ver `../decisions.md` D-12; embeddings multilingües, D-20), arma un prompt con esa evidencia y, si es relevante, el perfil/hábitos del usuario (D-15), y llama a Gemini.
  4. El sistema guarda la pregunta y la respuesta como mensajes de la conversación (nueva o existente).
  5. La app muestra la respuesta junto con un bloque «Referencias»: por cada documento usado, autores, año, título, revista, páginas y un enlace DOI tocable (o la URL de origen).
- **Postcondición:** Si era la primera pregunta, nueva fila en `conversations`; siempre, 2 filas nuevas en `messages`. El mensaje del asistente guarda una copia de sus referencias (`messages.sources`, D-18). Si Gemini falla, no se persiste nada (ni siquiera una conversación vacía — flujo atómico).
- **Endpoints:** `POST /chat`.

## UC-09 — Consultar el historial de conversaciones

- **Actor:** Usuario autenticado con al menos una conversación previa (UC-08).
- **Precondición:** UC-08 completado alguna vez.
- **Flujo principal:**
  1. Desde el Chat, el usuario toca el ícono de historial.
  2. El sistema lista sus conversaciones, más reciente primero.
  3. El usuario toca una para reabrirla: se precargan sus mensajes —cada respuesta con las referencias que tenía— y puede seguir chateando en ella (mismo `conversation_id`).
- **Postcondición:** Ninguna nueva si solo se consulta; si continúa la conversación, aplica UC-08 sobre la misma conversación.
- **Endpoints:** `GET /chat/conversations`, `GET /chat/conversations/{id}/messages`.

## UC-10 — Borrar una conversación

- **Actor:** Usuario autenticado, desde el historial (UC-09).
- **Precondición:** La conversación existe y pertenece al usuario.
- **Flujo principal:**
  1. El usuario toca borrar en un ítem del historial.
  2. El sistema borra la conversación y todos sus mensajes.
  3. La app quita el ítem de la lista sin recargarla entera.
- **Postcondición:** La conversación y sus mensajes ya no existen en la base.
- **Endpoints:** `DELETE /chat/conversations/{id}` (404 si no existe o es de otro usuario, mismo criterio que UC-05/D-03).

---

# Administración de la base de conocimiento

Estos casos los ejecuta una persona administradora (`ADMIN_EMAILS`) desde el panel `/admin`, salvo UC-16 que es de línea de comandos.

## UC-11 — Iniciar sesión en el panel de administración

- **Actor:** Administrador.
- **Precondición:** Su correo de Google está en `ADMIN_EMAILS` y el cliente OAuth Web tiene `http://localhost` y `http://localhost:8000` como orígenes de JavaScript autorizados.
- **Flujo principal:**
  1. Abre `http://localhost:8000/admin`.
  2. Inicia sesión con Google (el panel usa el mismo `POST /auth/google` que la app).
  3. El panel consulta `GET /admin/candidates`; si el backend responde 200, muestra «Buscar documentos», «Revisar candidatos» y «Historial de documentos».
- **Postcondición:** JWT guardado en `sessionStorage`. Con un correo que no está en la lista el backend responde 403 y el panel dice «Esta cuenta no es administradora».
- **Endpoints:** `GET /admin` (público), `POST /auth/google`, `GET /admin/candidates`.

## UC-12 — Buscar documentos candidatos

- **Actor:** Administrador.
- **Precondición:** UC-11 completado.
- **Flujo principal:**
  1. Elige los dominios a cubrir (sueño, alimentación, actividad física, hidratación, pantallas, estrés, consumo de sustancias; los 7 por defecto).
  2. Pulsa «Buscar 30 documentos».
  3. El sistema consulta Europe PMC por dominio (solo acceso abierto, revisiones/metaanálisis/guías desde 2015, inglés o español), reparte los 30 cupos entre los dominios elegidos, descarta lo ya visto (por PMCID o DOI, incluidos los rechazados) y guarda el resto como `pending`.
- **Postcondición:** Una fila en `discovery_runs` y hasta 30 en `document_candidates` (pueden ser menos si hay poca literatura abierta). Si Europe PMC no responde, 502 y no se guarda nada.
- **Endpoints:** `POST /admin/discovery`.

## UC-13 — Revisar, aprobar o rechazar candidatos

- **Actor:** Administrador.
- **Precondición:** Hay candidatos `pending` (UC-12).
- **Flujo principal:**
  1. Lee el resumen y abre el artículo, el PDF o el DOI de cada candidato.
  2. Pulsa «Aprobar» o «Rechazar». Puede filtrar la lista por estado.
- **Postcondición:** El candidato queda `approved` o `rejected` con `reviewed_at`. Un rechazado no se vuelve a proponer; uno aprobado o rechazado puede cambiarse mientras no haya empezado su indexación (después, 409).
- **Endpoints:** `GET /admin/candidates`, `POST /admin/candidates/{id}/approve`, `POST /admin/candidates/{id}/reject`.

## UC-14 — Indexar los documentos aprobados

- **Actor:** Administrador.
- **Precondición:** Hay candidatos `approved` (UC-13).
- **Flujo principal:**
  1. Pulsa «Indexar aprobados»; el sistema responde de inmediato (202) con cuántos puso en cola.
  2. En segundo plano, por cada aprobado: descarga el PDF, extrae el texto, lo parte en chunks, calcula los embeddings y guarda todo.
  3. El panel se actualiza solo: «Indexando…» pasa a «Indexado» o «Falló» (con el motivo).
- **Postcondición:** Por cada indexado, una fila en `scientific_documents` (con DOI, dominio, URL de origen, autores, año y revista) y sus `document_chunks`. Desde ese momento el chat puede citarlo (UC-08). Un fallo no detiene al resto del lote; aprobar de nuevo un `failed` lo reintenta.
- **Endpoints:** `POST /admin/ingest`, `GET /admin/candidates`.

## UC-15 — Recuperar una indexación interrumpida

- **Actor:** Administrador.
- **Precondición:** El servidor se reinició o cayó durante UC-14 y hay candidatos «Bloqueado» (en `ingesting` sin avance desde hace más de 15 minutos).
- **Flujo principal:**
  1. Pulsa «Indexar aprobados».
  2. El sistema devuelve los bloqueados a `approved` y los incluye en el lote.
  3. Si alguno ya había quedado indexado antes de la caída (mismo DOI), solo se marca `ingested`, sin descargar de nuevo.
- **Postcondición:** Ningún documento duplicado. La respuesta indica cuántos se recuperaron (`recovered`).
- **Endpoints:** `POST /admin/ingest`.

## UC-16 — Reindexar tras cambiar el modelo de embeddings

- **Actor:** Operador, por línea de comandos (no hay endpoint).
- **Precondición:** Cambió `EMBEDDING_MODEL_NAME` o se actualizó desde una versión que usaba otro modelo (`all-MiniLM-L6-v2`).
- **Flujo principal:**
  1. Ejecuta `ingestion/scripts/reindex.py --dry-run` para ver qué documentos se tocarán.
  2. Ejecuta `ingestion/scripts/reindex.py`.
  3. Por cada documento, reconstruye los chunks desde su PDF (o re-vectoriza el texto guardado si el PDF ya no está), todo en una transacción.
- **Postcondición:** Todos los chunks tienen vectores del modelo activo. Sin este paso el chat no falla pero recupera fragmentos equivocados, porque compara vectores de modelos distintos. Si un documento falla conserva sus chunks anteriores y el script se puede repetir.
- **Endpoints:** Ninguno — `ingestion/scripts/reindex.py`.

## UC-17 — Consultar el historial de documentos indexados

- **Actor:** Administrador.
- **Precondición:** UC-11 completado.
- **Flujo principal:**
  1. Abre la sección «3. Historial de documentos» del panel.
  2. El panel consulta `GET /admin/documents` (opcionalmente filtrado por dominio) y muestra una tarjeta por documento, del más nuevo al más antiguo, con su número de chunks.
- **Postcondición:** Solo lectura. La lista incluye los documentos indexados desde el panel y los cargados por línea de comandos (`ingest.py`).
- **Endpoints:** `GET /admin/documents`.

## UC-18 — Eliminar un documento indexado

- **Actor:** Administrador.
- **Precondición:** El documento aparece en el historial (UC-17).
- **Flujo principal:**
  1. Pulsa «Eliminar» en la tarjeta y confirma.
  2. El sistema borra los chunks del documento y el documento en una sola transacción.
  3. Si hay un candidato `ingested` con el mismo DOI (sin distinguir mayúsculas), lo marca `rejected`.
- **Postcondición:** El chat deja de recuperar ese documento y el descubrimiento no lo vuelve a proponer. El PDF permanece en disco. Los mensajes de chat anteriores conservan el texto de la referencia (`messages.sources` no es una FK). Documento inexistente: 404; éxito: 204.
- **Endpoints:** `DELETE /admin/documents/{id}`.

## UC-19 — Elegir las tareas diarias de mi objetivo

- **Actor:** Usuario con perfil (objetivo principal definido en UC-03 o UC-06).
- **Precondición:** Tiene un `main_goal` guardado; sin perfil no hay tareas disponibles.
- **Flujo principal:**
  1. El usuario abre la pestaña «Actividad» y toca el lápiz «Elegir tareas».
  2. El sistema muestra las 4 tareas del catálogo de su objetivo, con un interruptor por tarea (las activas, encendidas).
  3. El usuario enciende una tarea: el sistema la activa con la meta del catálogo (casilla, o contador con su unidad). O apaga una activa: el sistema la archiva.
- **Postcondición:** Fila nueva en `daily_tasks` (o `archived_at` asignado). Activar una tarea que ya está activa responde 409; una tarea de otro objetivo o inexistente, 422. Quitar una tarea conserva su historial (D-24).
- **Endpoints:** `GET /tasks/catalog`, `POST /tasks`, `DELETE /tasks/{id}`.

## UC-20 — Marcar el avance de las tareas del día

- **Actor:** Usuario con tareas activas (UC-19).
- **Precondición:** Está viendo el día de hoy en la pestaña «Actividad».
- **Flujo principal:**
  1. El sistema carga las tareas de hoy, con el progreso de ese día.
  2. El usuario marca la casilla de una tarea simple, o suma y resta en un contador (cada toque mueve un paso, nunca por debajo de 0 ni por encima de la meta).
  3. El sistema guarda el progreso de ese día y marca la tarea como cumplida al llegar a la meta.
- **Postcondición:** Una fila por tarea y día en `task_progress`. La lista parte en cero a la medianoche local de la persona: la app envía su fecha local y el servidor solo acepta fechas a ±1 día de su fecha UTC (D-24). La pantalla se recarga al volver a abrir la app en una fecha nueva.
- **Endpoints:** `GET /tasks?day=YYYY-MM-DD`, `PUT /tasks/{id}/progress`.

## UC-21 — Consultar días anteriores

- **Actor:** Usuario con tareas activas.
- **Precondición:** UC-20 usado en días anteriores.
- **Flujo principal:**
  1. En la franja semanal de «Actividad» toca un día anterior de la semana actual.
  2. El sistema muestra las tareas y el progreso de ese día en solo lectura, con el aviso «Solo lectura».
- **Postcondición:** Solo lectura: no se puede marcar, sumar, cambiar recordatorios ni elegir tareas, y los días futuros no se abren. Una tarea que la persona quitó se ve ahí únicamente si tuvo progreso ese día (D-24).
- **Endpoints:** `GET /tasks?day=YYYY-MM-DD`.

## UC-22 — Recibir un recordatorio de una tarea

- **Actor:** Usuario con una tarea activa.
- **Precondición:** Está en «Actividad», viendo hoy.
- **Flujo principal:**
  1. El usuario toca el reloj de una tarea y elige una hora (se muestra con AM/PM).
  2. El sistema guarda la hora y, en Android 13+, pide el permiso de notificaciones.
  3. El teléfono programa un aviso para cada uno de los próximos 7 días a esa hora y lo muestra como notificación local «HabitQ — Recordatorio: …».
  4. Si la tarea ya está cumplida hoy, no avisa hoy; sí los días siguientes. Quitar la hora cancela los avisos.
- **Postcondición:** `daily_tasks.reminder_time` guardado. Si el permiso se rechaza, la hora queda guardada y la tarea funciona sin aviso. Cerrar sesión cancela todos los recordatorios del teléfono. Son notificaciones locales a la hora fijada por la persona, sin servidor (D-25).
- **Endpoints:** `PUT /tasks/{id}` (hora o `null`); la programación de avisos es local al dispositivo.
