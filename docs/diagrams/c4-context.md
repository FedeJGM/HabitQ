# Diagrama de contexto (C4 — Nivel 1)

Vista de alto nivel: quién usa HabitQ y con qué sistemas externos interactúa. Renderiza directamente en GitHub (Mermaid).

> Usamos un flowchart estándar (no la sintaxis `C4Context` de Mermaid) para máxima compatibilidad de renderizado entre GitHub, VS Code y otros visores.

```mermaid
graph TD
    user["👤 Usuario<br/>Persona que quiere mejorar<br/>sus hábitos de salud"]
    admin["🧑‍💼 Administrador<br/>Aprueba qué documentos<br/>entran a la base de conocimiento"]
    mobile["📱 HabitQ Mobile<br/>Flutter — Android<br/>Login, onboarding, hábitos, perfil, chat"]
    panel["🖥️ Panel de administración<br/>HTML servido por el backend<br/>(/admin)"]
    backend["⚙️ HabitQ Backend<br/>FastAPI<br/>Auth, perfil, hábitos, chat RAG, administración"]
    google["🔐 Google Sign-In<br/>OAuth 2.0"]
    postgres[("🗄️ PostgreSQL<br/>embeddings como ARRAY(FLOAT)")]
    gemini["🤖 Gemini API<br/>gemini-flash-latest"]
    epmc["📚 Europe PMC<br/>Búsqueda y PDFs open access"]
    hf["🤗 Hugging Face Hub<br/>Descarga única del modelo<br/>de embeddings"]

    user -->|usa| mobile
    mobile -->|autentica| google
    mobile -->|HTTPS/REST + JWT| backend
    admin -->|usa| panel
    panel -->|autentica| google
    panel -->|HTTPS/REST + JWT| backend
    backend -->|valida ID token| google
    backend -->|SQL| postgres
    backend -->|genera respuestas RAG| gemini
    backend -->|busca y descarga candidatos| epmc
    backend -->|descarga el modelo la primera vez| hf
```

## Estado de cada relación

| Relación | Estado |
|---|---|
| Usuario → Mobile | ✅ Implementado |
| Mobile → Google (OAuth) | ✅ Implementado |
| Mobile → Backend (REST + JWT) | ✅ Implementado (auth, perfil, hábitos, chat con referencias, historial) |
| Administrador → Panel → Backend | ✅ Implementado (`/admin`; requiere que el correo esté en `ADMIN_EMAILS`) |
| Panel → Google (OAuth) | ✅ Implementado (Google Identity Services en el navegador; exige registrar `http://localhost` y `http://localhost:8000` como orígenes de JavaScript del cliente Web) |
| Backend → Google (validar ID token) | ✅ Implementado |
| Backend → PostgreSQL | ✅ Implementado (9 tablas, migraciones `0001`–`0008`) |
| Backend → Gemini | ✅ Implementado (`POST /chat`, retry configurado — ver `docs/decisions.md` D-14/D-16) |
| Backend → Europe PMC | ✅ Implementado (`POST /admin/discovery` y descarga de PDFs aprobados; D-17) |
| Backend → Hugging Face Hub | ✅ Solo la primera vez en cada máquina: después el modelo se carga desde disco (D-20) |
| pgvector (embeddings) | ❌ No usado — no disponible en el entorno de desarrollo; los embeddings se guardan como `ARRAY(FLOAT)` con similitud coseno en Python (ver `docs/decisions.md` D-12) |
