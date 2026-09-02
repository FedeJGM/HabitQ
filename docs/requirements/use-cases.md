# Casos de uso — implementados

Formato: Actor, Precondición, Flujo principal, Postcondición, Endpoints involucrados. Cubre solo lo construido; para el alcance completo del MVP ver `HABITQ_DEVELOPMENT_PLAN.md`, sección 2.

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
  1. El usuario abre "Chat con HabitQ" desde Home.
  2. Escribe una pregunta y la envía (se muestra de inmediato, envío optimista).
  3. El sistema recupera los fragmentos de evidencia más relevantes de `document_chunks` (similitud coseno, sin pgvector — ver `../decisions.md` D-12), arma un prompt con esa evidencia y, si es relevante, el perfil/hábitos del usuario (D-15), y llama a Gemini.
  4. El sistema guarda la pregunta y la respuesta como mensajes de la conversación (nueva o existente).
  5. La app muestra la respuesta junto con las fuentes usadas (título, organización).
- **Postcondición:** Si era la primera pregunta, nueva fila en `conversations`; siempre, 2 filas nuevas en `messages`. Si Gemini falla, no se persiste nada (ni siquiera una conversación vacía — flujo atómico).
- **Endpoints:** `POST /chat`.

## UC-09 — Consultar el historial de conversaciones

- **Actor:** Usuario autenticado con al menos una conversación previa (UC-08).
- **Precondición:** UC-08 completado alguna vez.
- **Flujo principal:**
  1. Desde el Chat, el usuario toca el ícono de historial.
  2. El sistema lista sus conversaciones, más reciente primero.
  3. El usuario toca una para reabrirla: se precargan sus mensajes y puede seguir chateando en ella (mismo `conversation_id`).
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
