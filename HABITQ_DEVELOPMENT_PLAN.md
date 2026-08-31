# HABITQ — DEVELOPMENT PLAN

**Proyecto:** HabitQ  
**Tipo:** Aplicación móvil de proyecto de grado  
**Plataforma objetivo:** Android  
**Equipo:** 2 personas  
**Fecha de inicio:** 31 de agosto de 2026  
**Fecha objetivo de finalización funcional:** 5 de noviembre de 2026  
**Disponibilidad:** 2–4 horas diarias por persona  
**Presupuesto:** $0 — solo herramientas y planes gratuitos  

---

# 1. Objetivo del MVP

Desarrollar una aplicación móvil que proporcione orientación personalizada para mejorar hábitos saludables mediante un asistente conversacional respaldado por evidencia científica.

El MVP debe demostrar el siguiente flujo completo:

```text
Usuario
  ↓
Google Login
  ↓
Onboarding
  ↓
Perfil de hábitos
  ↓
Pregunta en lenguaje natural
  ↓
FastAPI
  ↓
RAG
  ↓
PostgreSQL + pgvector
  ↓
Evidencia científica
  ↓
LLM
  ↓
Respuesta personalizada
  ↓
Fuentes verificables
```

---

# 2. Alcance definitivo del MVP

## Incluido

- Inicio de sesión con Google.
- Cierre de sesión.
- Consentimiento inicial.
- Onboarding.
- Perfil básico.
- Registro y actualización de hábitos.
- Seis dominios de hábitos:
  - Sueño.
  - Alimentación.
  - Actividad física.
  - Hidratación.
  - Uso de pantallas.
  - Manejo del estrés.
- Chat con HabitQ.
- Historial de conversaciones.
- Recuperación de evidencia mediante RAG.
- Recomendaciones personalizadas.
- Visualización de fuentes utilizadas.
- Respuesta controlada cuando no exista evidencia suficiente.
- APK Android instalable.

## Fuera del MVP

- Índice HabitQ.
- Dashboards.
- Gráficos de progreso.
- Estadísticas avanzadas.
- Gamificación.
- Puntos.
- Logros.
- Retos.
- Rankings.
- Recuperación de contraseña propia.
- Registro con usuario/contraseña tradicional.
- Notificaciones inteligentes.
- Informes semanales.
- Objetivos automáticos.
- Tareas diarias automáticas.
- Google Fit.
- Apple Health.
- Wearables.
- Panel administrativo.
- Fine-tuning.
- Entrenamiento de modelos.
- Microservicios.
- Kubernetes.
- Consumo de sustancias.
- Diagnósticos.
- Tratamientos.
- Prescripción de medicamentos.

**Regla:** después del 11 de octubre no se agregan nuevas funcionalidades.

---

# 3. Stack tecnológico

| Capa | Tecnología |
|---|---|
| Mobile | Flutter + Dart |
| Android | Android SDK / Android Studio |
| Backend | FastAPI + Python |
| Base de datos | PostgreSQL |
| Búsqueda vectorial | pgvector |
| ORM | SQLAlchemy |
| Migraciones | Alembic |
| Autenticación | Google Sign-In + JWT HabitQ |
| Validación backend | Pydantic |
| PDFs | PyMuPDF |
| Embeddings | sentence-transformers |
| LLM principal | Gemini API Free Tier |
| Control de versiones | Git + GitHub |
| Gestión del trabajo | GitHub Projects |
| Mockups | Figma Free o Penpot |
| Pruebas backend | Pytest |
| Pruebas Flutter | flutter_test |
| API testing | Postman |
| Exposición demo | Cloudflare Tunnel |
| Contenedores | Docker Compose, principalmente para integración/demo |

## Decisiones

1. No usar Supabase.
2. No usar Spring Boot.
3. No usar Firebase como backend principal.
4. No usar una base vectorial adicional.
5. PostgreSQL + pgvector será la única base de datos.
6. Gemini será el LLM principal por las limitaciones de hardware.
7. Ollama no será requisito del MVP.
8. Los embeddings se generan localmente.
9. Los PDFs se almacenan localmente.
10. Flutter nunca se conecta directamente a PostgreSQL.

---

# 4. Arquitectura

```text
┌─────────────────┐
│ Android / Flutter│
└────────┬────────┘
         │ HTTPS / REST
         ▼
┌─────────────────┐
│     FastAPI     │
└───────┬─────────┘
        │
   ┌────┼───────────────┐
   │    │               │
   ▼    ▼               ▼
 Auth PostgreSQL       RAG Service
       + pgvector       │
                        ├── PyMuPDF
                        ├── sentence-transformers
                        └── Gemini
```

---

# 5. Distribución del equipo

## Persona 1 — Mobile / UX

Responsable principal de:

- Flutter.
- Dart.
- Android.
- Figma.
- Navegación.
- Login UI.
- Onboarding UI.
- Perfil.
- Hábitos.
- Chat UI.
- Historial.
- Consumo de API REST.
- Manejo visual de errores.
- Build APK.
- Pruebas Flutter.

## Persona 2 — Backend / Datos / IA

Responsable principal de:

- Python.
- FastAPI.
- PostgreSQL.
- pgvector.
- SQLAlchemy.
- Alembic.
- Google token validation.
- JWT.
- Modelo de datos.
- APIs.
- Ingesta PDF.
- Embeddings.
- RAG.
- Gemini.
- Seguridad backend.
- Pytest.
- Cloudflare Tunnel.

## Ambos

- Git/GitHub.
- Requisitos.
- Arquitectura.
- Modelo ER.
- Casos de uso.
- Integraciones.
- QA.
- Documentación.
- Demo.
- Presentación.

---

# 6. Flujo Git

## Ramas

```text
main
develop
feature/*
fix/*
docs/*
```

Ejemplos:

```text
feature/google-login
feature/onboarding
feature/habits-api
feature/rag-retrieval
feature/chat-ui
fix/expired-token
docs/update-architecture
```

## Commits

```text
feat: add Google login
feat: create onboarding flow
fix: validate expired JWT
docs: update ER model
test: add profile API tests
refactor: simplify chat service
```

## Regla

- No commits directos a `main`.
- Cada funcionalidad entra por Pull Request.
- `develop` integra el trabajo diario.
- `main` representa versiones estables.

---

# 7. Estructura del repositorio

```text
habitq/
├── mobile/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/
│   │   │   ├── networking/
│   │   │   ├── theme/
│   │   │   └── utils/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── onboarding/
│   │   │   ├── home/
│   │   │   ├── habits/
│   │   │   ├── chat/
│   │   │   └── profile/
│   │   └── main.dart
│   └── test/
│
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── db/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── main.py
│   ├── tests/
│   ├── alembic/
│   ├── requirements.txt
│   └── .env.example
│
├── ingestion/
│   ├── data/
│   │   └── scientific_documents/
│   ├── scripts/
│   └── README.md
│
├── docs/
│   ├── architecture/
│   ├── diagrams/
│   ├── requirements/
│   └── decisions.md
│
├── scripts/
├── docker-compose.yml
├── .gitignore
└── README.md
```

---

# 8. Modelo de datos MVP

## users

```text
id UUID PK
google_id VARCHAR UNIQUE
email VARCHAR UNIQUE
name VARCHAR
created_at TIMESTAMP
onboarding_completed BOOLEAN
```

## profiles

```text
id UUID PK
user_id UUID FK users.id
age_range VARCHAR
main_goal VARCHAR
created_at TIMESTAMP
updated_at TIMESTAMP
```

## habit_records

```text
id UUID PK
user_id UUID FK users.id
domain VARCHAR
key VARCHAR
value VARCHAR
recorded_at TIMESTAMP
updated_at TIMESTAMP
```

## conversations

```text
id UUID PK
user_id UUID FK users.id
title VARCHAR NULL
created_at TIMESTAMP
updated_at TIMESTAMP
```

## messages

```text
id UUID PK
conversation_id UUID FK conversations.id
role VARCHAR
content TEXT
created_at TIMESTAMP
```

## scientific_documents

```text
id UUID PK
title VARCHAR
authors VARCHAR NULL
organization VARCHAR NULL
year INTEGER NULL
language VARCHAR
source_url VARCHAR NULL
file_path VARCHAR
created_at TIMESTAMP
```

## document_chunks

```text
id UUID PK
document_id UUID FK scientific_documents.id
content TEXT
page_number INTEGER NULL
chunk_index INTEGER
embedding VECTOR
```

---

# 9. API mínima

## Sistema

```http
GET /health
```

## Autenticación

```http
POST /auth/google
POST /auth/refresh
POST /auth/logout
```

## Perfil

```http
GET /profile
PUT /profile
```

## Hábitos

```http
GET /habits
POST /habits
PUT /habits/{id}
```

## Chat

```http
POST /chat
GET /conversations
GET /conversations/{id}/messages
DELETE /conversations/{id}
```

---

# 10. Autenticación

```text
Flutter
  ↓
Google Sign-In
  ↓
Google ID Token
  ↓
FastAPI
  ↓
Validar token con Google
  ↓
Buscar/crear usuario
  ↓
Generar JWT HabitQ
  ↓
Flutter
```

Las operaciones privadas usan:

```http
Authorization: Bearer <jwt_habitq>
```

## Reglas

- No confiar en un `user_id` enviado por Flutter.
- El backend obtiene el usuario desde el JWT.
- Claves privadas solo en backend.
- No guardar contraseñas.
- No implementar recuperación de contraseña.

---

# 11. Onboarding

## Perfil básico

- Nombre obtenido de Google.
- Correo obtenido de Google.
- Rango de edad.
- Objetivo principal.

## Preguntas iniciales sugeridas

### Sueño

- ¿Cuántas horas duermes normalmente?
  - Menos de 5.
  - 5–6.
  - 7–8.
  - Más de 8.

- ¿Usas pantallas durante la última hora antes de dormir?
  - Nunca.
  - A veces.
  - Frecuentemente.

### Alimentación

- ¿Con qué frecuencia consumes frutas o verduras?
  - Rara vez.
  - Algunos días.
  - Casi todos los días.

- ¿Con qué frecuencia consumes comida rápida o ultraprocesados?
  - Rara vez.
  - 1–2 veces por semana.
  - 3 o más veces por semana.

### Actividad física

- ¿Cuántos días por semana realizas actividad física?
  - 0.
  - 1–2.
  - 3–4.
  - 5 o más.

- ¿Pasas varias horas seguidas sentado?
  - Sí.
  - No.

### Hidratación

- ¿Cómo describirías tu consumo diario de agua?
  - Bajo.
  - Moderado.
  - Adecuado.

### Uso de pantallas

- ¿Cuánto tiempo recreativo pasas frente a pantallas?
  - Menos de 2 horas.
  - 2–4 horas.
  - Más de 4 horas.

### Estrés

- ¿Con qué frecuencia sientes estrés durante tu rutina?
  - Rara vez.
  - A veces.
  - Frecuentemente.

**Nota:** el cuestionario debe validarse académicamente antes de presentarlo como instrumento científico.

---

# 12. RAG

## Ingesta

```text
PDF
 ↓
PyMuPDF
 ↓
Extracción de texto
 ↓
Limpieza
 ↓
Chunking
 ↓
Embeddings
 ↓
pgvector
```

## Consulta

```text
Pregunta
 ↓
Embedding
 ↓
Similarity Search
 ↓
Top 5 chunks
 ↓
Perfil relevante
 ↓
Prompt
 ↓
Gemini
 ↓
Respuesta + fuentes
```

## Parámetros iniciales

```text
Chunk size: 800–1200 tokens
Overlap: 100–150 tokens
Top K: 5
```

Estos valores se ajustan mediante pruebas.

---

# 13. Fuentes científicas

Meta inicial:

```text
20–40 documentos
```

Idiomas:

```text
Español + Inglés
```

Prioridad:

1. OMS.
2. CDC.
3. NIH.
4. Guías oficiales.
5. Revisiones sistemáticas.
6. Meta-análisis.
7. Revistas indexadas.

## Distribución inicial sugerida

```text
Sueño: 4–6
Alimentación: 4–6
Actividad física: 4–6
Hidratación: 3–5
Pantallas: 3–5
Estrés: 4–6
```

No necesitan cientos de PDFs.

---

# 14. Reglas del asistente

HabitQ debe:

- Hablar en español.
- Utilizar lenguaje sencillo.
- Utilizar evidencia recuperada.
- Personalizar solo cuando el perfil sea relevante.
- Mostrar las fuentes.
- Admitir cuando no existe evidencia suficiente.
- No diagnosticar.
- No prescribir medicamentos.
- No presentar afirmaciones médicas como certeza.
- Recomendar atención profesional cuando corresponda.

HabitQ no debe:

- Inventar fuentes.
- Inventar resultados científicos.
- Modificar automáticamente el perfil.
- Responder basándose únicamente en conocimiento interno cuando la consulta requiera evidencia del RAG.

---

# 15. Seguridad mínima

- HTTPS para demo externa.
- JWT para endpoints privados.
- Validación del token Google.
- Variables de entorno.
- `.env` fuera de Git.
- Sanitización y validación con Pydantic.
- SQLAlchemy en lugar de concatenar SQL manual.
- Control de acceso por usuario.
- CORS restringido.
- No guardar información innecesaria.
- No almacenar información médica sensible real durante desarrollo.
- Utilizar datos ficticios en pruebas.

---

# 16. Definition of Done

Una tarea puede marcarse `Done` solamente si:

- Código terminado.
- Compila.
- Funciona localmente.
- Sin error bloqueante.
- Maneja errores básicos.
- Tiene validaciones.
- Está subida a GitHub.
- Tiene Pull Request.
- Fue revisada por el otro integrante.
- Fue integrada en `develop`.
- Tiene prueba cuando aplique.
- Documentación actualizada cuando corresponda.

---

# 17. Roadmap ejecutivo

## Fase 1 — Base
**31 agosto – 6 septiembre**

- Alcance.
- Git.
- Mockups.
- Flutter inicial.
- FastAPI inicial.
- PostgreSQL.
- Modelo ER.

## Fase 2 — Core
**7 – 20 septiembre**

- Google Login.
- JWT.
- Onboarding.
- Perfil.
- Hábitos.
- APIs.
- Integración Flutter/FastAPI.

## Fase 3 — IA/RAG
**21 septiembre – 4 octubre**

- PDFs.
- Ingesta.
- Embeddings.
- pgvector.
- Retrieval.
- Gemini.
- Chat.

## Fase 4 — Integración
**5 – 11 octubre**

- Historial.
- Fuentes.
- Personalización.
- Manejo de errores.
- Seguridad.

## Fase 5 — Feature Freeze + QA
**12 – 25 octubre**

- Pruebas.
- RAG evaluation.
- Bugs.
- Usabilidad.
- APK preliminar.

## Fase 6 — Entrega
**26 octubre – 5 noviembre**

- Freeze.
- Correcciones críticas.
- Documentación.
- Demo.
- APK final.
- Presentación.

---

# 18. Plan diario

## Semana 1 — 31 agosto al 6 septiembre

### Lunes 31

**Ambos**
- Crear repositorio GitHub.
- Crear `main` y `develop`.
- Crear GitHub Project.
- Crear épicas.
- Copiar alcance y fuera de alcance al README.
- Configurar `.gitignore`.
- Instalar Git.

**Persona 1**
- Instalar Flutter.
- Instalar Android Studio.
- Configurar Android SDK.
- Crear emulador.
- Ejecutar `flutter doctor`.

**Persona 2**
- Instalar Python.
- Crear entorno virtual.
- Instalar PostgreSQL.
- Instalar Postman.
- Crear FastAPI mínimo.

**Entrega**
- Repositorio operativo.
- Flutter ejecutándose.
- `GET /health` funcionando.

### Martes 1 septiembre

**Ambos**
- Aprender flujo mínimo Git: clone, branch, add, commit, push, pull, PR.
- Definir casos de uso.

**Persona 1**
- Crear proyecto Figma/Penpot.
- Wireframe Login.
- Wireframe Onboarding.
- Wireframe Home.

**Persona 2**
- Crear BD `habitq`.
- Crear configuración SQLAlchemy.
- Probar FastAPI → PostgreSQL.

### Miércoles 2

**Persona 1**
- Wireframe Hábitos.
- Wireframe Chat.
- Wireframe Historial.
- Wireframe Perfil.

**Persona 2**
- Crear modelos `users`, `profiles`, `habit_records`.
- Introducción a Alembic.
- Crear migración inicial.

**Ambos**
- Revisar modelo ER.

### Jueves 3

**Persona 1**
- Crear proyecto Flutter definitivo.
- Configurar carpetas.
- Configurar navegación.
- Crear theme básico.

**Persona 2**
- Modelos `conversations`, `messages`.
- Modelos `scientific_documents`, `document_chunks`.
- Crear migraciones.

### Viernes 4

**Persona 1**
- Pantalla Login.
- Pantalla Home.
- Navegación provisional.

**Persona 2**
- Crear routers FastAPI.
- Crear esquemas Pydantic.
- Crear estructura services/repositories.

### Sábado 5

**Ambos**
- Integrar ramas.
- Resolver errores.
- Documentar arquitectura.
- Crear primer diagrama C4.
- Crear ER definitivo.

### Domingo 6

**Carga ligera**
- Repaso.
- Documentar aprendizajes.
- Preparar semana 2.
- No agregar funcionalidades.

---

## Semana 2 — 7 al 13 septiembre

### Lunes 7
P1: configurar Google Sign-In en Flutter.  
P2: configurar credenciales Google OAuth para backend.

### Martes 8
P1: obtener Google ID Token.  
P2: crear `POST /auth/google`.

### Miércoles 9
P1: almacenar JWT HabitQ de forma segura.  
P2: validar token Google y crear usuario.

### Jueves 10
P1: navegación autenticado/no autenticado.  
P2: generar/validar JWT HabitQ.

### Viernes 11
Ambos: integración Google Login completa.

### Sábado 12
Pruebas:
- usuario nuevo;
- usuario existente;
- token inválido;
- logout.

### Domingo 13
Correcciones y documentación.

**Hito:** Google Login completo.

---

## Semana 3 — 14 al 20 septiembre

### Lunes 14
P1: pantalla onboarding 1.  
P2: `GET /profile`, `PUT /profile`.

### Martes 15
P1: preguntas sueño/alimentación.  
P2: `GET /habits`.

### Miércoles 16
P1: actividad/hidratación.  
P2: `POST /habits`.

### Jueves 17
P1: pantallas/estrés.  
P2: `PUT /habits/{id}`.

### Viernes 18
P1: enviar onboarding al backend.  
P2: persistencia y validaciones.

### Sábado 19
Ambos: prueba E2E:
Login → onboarding → home.

### Domingo 20
Correcciones.

**Hito:** perfil y hábitos persistentes.

---

## Semana 4 — 21 al 27 septiembre

### Lunes 21
P1: pantalla Mis hábitos.  
P2: seguridad de endpoints por JWT.

### Martes 22
P1: editar hábitos.  
P2: pruebas Pytest perfiles/hábitos.

### Miércoles 23
P1: estados loading/error/success.  
P2: manejo global de errores.

### Jueves 24
P1: pantalla Perfil.  
P2: logs básicos.

### Viernes 25
Ambos: integración completa Flutter ↔ FastAPI ↔ PostgreSQL.

### Sábado 26
Pruebas con dos usuarios distintos.

### Domingo 27
Corregir acceso cruzado y errores.

**Hito:** núcleo sin IA terminado.

---

## Semana 5 — 28 septiembre al 4 octubre

### Lunes 28
P2: crear estructura de ingesta PDF.  
P1: diseñar Chat UI.

### Martes 29
P2: aprender PyMuPDF y extracción.  
P1: mensajes usuario/asistente.

### Miércoles 30
P2: limpieza y chunking.  
P1: loading y errores Chat.

### Jueves 1 octubre
P2: instalar sentence-transformers y generar primer embedding.  
P1: componente tarjeta de fuente.

### Viernes 2
P2: configurar pgvector.  
P1: pantalla historial.

### Sábado 3
P2: almacenar chunks + embeddings.  
P1: integración simulada con respuesta mock.

### Domingo 4
Ambos: revisar pipeline completo de ingestión.

**Hito:** primer PDF indexado.

---

## Semana 6 — 5 al 11 octubre

### Lunes 5
P2: implementar embedding de pregunta.  
P1: terminar Chat UI.

### Martes 6
P2: similarity search en pgvector.  
P1: integración inicial `POST /chat`.

### Miércoles 7
P2: retrieval Top 5.  
P1: enviar/recibir mensajes reales.

### Jueves 8
P2: integrar Gemini.  
P1: renderizar respuesta.

### Viernes 9
P2: respuesta con fuentes.  
P1: mostrar fuentes.

### Sábado 10
Ambos: primera conversación RAG extremo a extremo.

### Domingo 11
**FEATURE FREEZE PARCIAL**
No agregar módulos nuevos.

**Hito:** HabitQ conversa y cita fuentes.

---

## Semana 7 — 12 al 18 octubre

### Lunes 12
P2: conversaciones y mensajes.  
P1: historial de conversaciones.

### Martes 13
P2: personalización con perfil/hábitos.  
P1: abrir conversación histórica.

### Miércoles 14
P2: respuesta sin evidencia suficiente.  
P1: estado visual correspondiente.

### Jueves 15
P2: manejo errores Gemini.  
P1: reintentar consulta.

### Viernes 16
Ambos: pruebas E2E completas.

### Sábado 17
Hardening de seguridad.

### Domingo 18
Documentación.

**Hito:** MVP funcional completo.

---

## Semana 8 — 19 al 25 octubre

### Lunes 19
Crear dataset de 30 preguntas RAG.

### Martes 20
Evaluar sueño + alimentación.

### Miércoles 21
Evaluar actividad + hidratación.

### Jueves 22
Evaluar pantallas + estrés.

### Viernes 23
Corregir retrieval y prompts.

### Sábado 24
Pruebas de usabilidad con 3–5 personas.

### Domingo 25
Clasificar bugs P0/P1/P2/P3.

**Hito:** QA terminado.

---

## Semana 9 — 26 octubre al 1 noviembre

### Lunes 26
**FEATURE FREEZE TOTAL.**

Solo bugs.

### Martes 27
Corregir P0.

### Miércoles 28
Corregir P1.

### Jueves 29
Pruebas regresión.

### Viernes 30
Configurar Cloudflare Tunnel.

### Sábado 31
Crear APK release preliminar.

### Domingo 1 noviembre
Probar APK en dos Android.

---

## Semana final — 2 al 5 noviembre

### Lunes 2
- Actualizar README.
- Arquitectura final.
- ER final.
- Casos de uso finales.

### Martes 3
- Video demo.
- Capturas.
- Resultados de pruebas.
- Backup.

### Miércoles 4
- APK final.
- Tag `v1.0.0-mvp`.
- Ensayo de demostración.

### Jueves 5
**ENTREGA**

Checklist:
- APK.
- Backend funcional.
- PostgreSQL.
- pgvector.
- RAG.
- Google Login.
- Historial.
- Fuentes.
- GitHub.
- Documentación mínima.
- Video de respaldo.

---

# 19. Prioridad de aprendizaje

## Persona 1

Orden:

```text
Git básico
→ Dart básico
→ Flutter widgets
→ navegación
→ HTTP/REST
→ estado
→ Google Sign-In
→ testing
```

No estudiar Flutter completo antes de comenzar.

## Persona 2

Orden:

```text
Git básico
→ Python básico
→ FastAPI
→ SQL/PostgreSQL
→ SQLAlchemy
→ JWT
→ pgvector
→ RAG
→ Gemini
→ testing
```

No estudiar Python completo antes de comenzar.

---

# 20. Reglas para mantener el proyecto viable

1. Máximo 2–4 horas diarias por persona.
2. Trabajar en bloques de 60–90 minutos.
3. Una funcionalidad terminada vale más que tres iniciadas.
4. No cambiar stack después de la semana 2.
5. No agregar módulos después del 11 de octubre.
6. No refactorizar por estética durante la fase final.
7. P0/P1 tienen prioridad sobre nuevas mejoras.
8. Evitar dependencias innecesarias.
9. No comenzar con arquitectura compleja.
10. Mantener la demo funcionando al terminar cada semana.

---

# 21. Criterios mínimos para considerar HabitQ terminada

La aplicación se considera funcional si:

- [ ] APK se instala en Android.
- [ ] Usuario inicia sesión con Google.
- [ ] Usuario completa onboarding.
- [ ] Perfil se guarda.
- [ ] Hábitos se guardan y actualizan.
- [ ] Usuario abre Chat.
- [ ] Pregunta llega a FastAPI.
- [ ] RAG recupera evidencia.
- [ ] Gemini genera respuesta.
- [ ] Respuesta utiliza información recuperada.
- [ ] Se muestran fuentes.
- [ ] Conversación queda guardada.
- [ ] Usuario consulta historial.
- [ ] Un usuario no accede a información de otro.
- [ ] Errores externos no cierran la aplicación.
- [ ] Backend puede exponerse mediante Cloudflare Tunnel.

---

# 22. Riesgos principales

| Riesgo | Mitigación |
|---|---|
| Bajo conocimiento técnico | Aprendizaje justo a tiempo |
| Hardware 8 GB RAM | Evitar LLM local y minimizar contenedores |
| Cuotas Gemini | Usar prompts pequeños y cachear pruebas |
| RAG incorrecto | Dataset de evaluación |
| Google OAuth complejo | Implementarlo temprano |
| Falta de PDFs | Buscar fuentes durante semanas 3–5 |
| Retrasos | Feature freeze obligatorio |
| Integración tardía | Integrar semanalmente |
| Errores de Git | PRs pequeños y frecuentes |

---

# 23. Primer comando de trabajo

Después de crear el repositorio:

```bash
git clone <URL_REPOSITORIO>
cd habitq
git checkout -b develop
```

Persona 1:

```bash
flutter doctor
flutter create mobile
```

Persona 2:

```bash
python -m venv .venv
```

Windows CMD:

```cmd
.venv\Scripts\activate
```

Instalación inicial:

```bash
pip install fastapi uvicorn sqlalchemy psycopg[binary] alembic python-dotenv pydantic pytest
```

Crear primer servidor:

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}
```

Ejecutar:

```bash
uvicorn app.main:app --reload
```

---

# 24. Resultado esperado

Para el 5 de noviembre de 2026 HabitQ no necesita ser una aplicación comercial.

Debe ser un MVP estable capaz de demostrar técnicamente:

```text
Mobile
+
Backend
+
Autenticación
+
Base de datos
+
RAG
+
IA
+
Seguridad básica
+
Persistencia
+
Evidencia científica
```

Ese será el criterio principal de éxito del proyecto.
