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
