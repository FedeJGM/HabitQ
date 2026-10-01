# Diagrama de contexto (C4 — Nivel 1)

Vista de alto nivel: quién usa HabitQ y con qué sistemas externos interactúa. Renderiza directamente en GitHub (Mermaid).

> Usamos un flowchart estándar (no la sintaxis `C4Context` de Mermaid) para máxima compatibilidad de renderizado entre GitHub, VS Code y otros visores.

```mermaid
graph TD
    user["👤 Usuario<br/>Persona que quiere mejorar<br/>sus hábitos de salud"]
    mobile["📱 HabitQ Mobile<br/>Flutter — Android<br/>Login, onboarding, hábitos, perfil"]
    backend["⚙️ HabitQ Backend<br/>FastAPI<br/>Auth, perfil, hábitos"]
    google["🔐 Google Sign-In<br/>OAuth 2.0"]
    postgres[("🗄️ PostgreSQL<br/>embeddings como ARRAY(FLOAT)")]
    gemini["🤖 Gemini API<br/>gemini-flash-latest"]

    user -->|usa| mobile
    mobile -->|autentica| google
    mobile -->|HTTPS/REST + JWT| backend
    backend -->|valida ID token| google
    backend -->|SQL| postgres
    backend -->|genera respuestas RAG| gemini
```

## Estado de cada relación

| Relación | Estado |
|---|---|
| Usuario → Mobile | ✅ Implementado |
| Mobile → Google (OAuth) | ✅ Implementado |
| Mobile → Backend (REST + JWT) | ✅ Implementado (auth, perfil, hábitos, chat, historial) |
| Backend → Google (validar ID token) | ✅ Implementado |
| Backend → PostgreSQL | ✅ Implementado (`users`, `profiles`, `habit_records`, `scientific_documents`, `document_chunks`, `conversations`, `messages` — 7 tablas, migraciones `0001`–`0005`) |
| Backend → Gemini | ✅ Implementado (`POST /chat`, retry configurado — ver `docs/decisions.md` D-14/D-16) |
| pgvector (embeddings) | ❌ No usado — no disponible en el entorno de desarrollo; los embeddings se guardan como `ARRAY(FLOAT)` con similitud coseno en Python (ver `docs/decisions.md` D-12) |
