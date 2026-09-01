# Diagrama de contexto (C4 — Nivel 1)

Vista de alto nivel: quién usa HabitQ y con qué sistemas externos interactúa. Renderiza directamente en GitHub (Mermaid).

> Usamos un flowchart estándar (no la sintaxis `C4Context` de Mermaid) para máxima compatibilidad de renderizado entre GitHub, VS Code y otros visores.

```mermaid
graph TD
    user["👤 Usuario<br/>Persona que quiere mejorar<br/>sus hábitos de salud"]
    mobile["📱 HabitQ Mobile<br/>Flutter — Android<br/>Login, onboarding, hábitos, perfil"]
    backend["⚙️ HabitQ Backend<br/>FastAPI<br/>Auth, perfil, hábitos"]
    google["🔐 Google Sign-In<br/>OAuth 2.0"]
    postgres[("🗄️ PostgreSQL<br/>+ pgvector (futuro)")]
    gemini["🤖 Gemini API<br/>(Futuro — Fase 3)"]

    user -->|usa| mobile
    mobile -->|autentica| google
    mobile -->|HTTPS/REST + JWT| backend
    backend -->|valida ID token| google
    backend -->|SQL| postgres
    backend -.->|futuro: genera respuestas| gemini
```

## Estado de cada relación

| Relación | Estado |
|---|---|
| Usuario → Mobile | ✅ Implementado |
| Mobile → Google (OAuth) | ✅ Implementado |
| Mobile → Backend (REST + JWT) | ✅ Implementado (auth, perfil, hábitos) |
| Backend → Google (validar ID token) | ✅ Implementado |
| Backend → PostgreSQL | ✅ Implementado (`users`, `profiles`, `habit_records`) |
| Backend → Gemini | ❌ No implementado — Fase 3 del plan |
| pgvector (embeddings) | ❌ No implementado — Fase 3 del plan |
