# Secuencias de autenticación

## Login con Google (implementado)

```mermaid
sequenceDiagram
    participant U as Usuario
    participant M as Flutter (LoginScreen)
    participant G as Google Sign-In
    participant B as FastAPI (/auth/google)
    participant DB as PostgreSQL

    U->>M: Toca "Continúa con Google"
    M->>G: signIn()
    G-->>U: Selector de cuenta
    U->>G: Elige cuenta
    G-->>M: ID token (Google)
    M->>B: POST /auth/google { id_token }
    B->>G: Valida el ID token (audiencia = GOOGLE_CLIENT_ID)
    G-->>B: Claims (sub, email, name)
    B->>DB: SELECT user WHERE google_id = sub
    alt usuario no existe
        B->>DB: INSERT INTO users
    end
    B->>B: create_access_token(user.id) — JWT HabitQ, 24h
    B-->>M: { access_token, user }
    M->>M: Guarda access_token en secure storage
    M->>M: ¿consentimiento local aceptado?
    alt no
        M->>U: Muestra ConsentScreen
    else sí
        M->>U: Navega a Onboarding u Home según onboarding_completed
    end
```

## Llamada autenticada típica (ej. GET /habits)

```mermaid
sequenceDiagram
    participant M as Flutter (ApiClient)
    participant B as FastAPI
    participant DB as PostgreSQL

    M->>M: Lee el JWT de secure storage
    M->>B: GET /habits\nAuthorization: Bearer <jwt>
    B->>B: decode_access_token(jwt) — valida firma y expiración
    alt token inválido o expirado
        B-->>M: 401 Unauthorized
    else token válido
        B->>DB: SELECT user WHERE id = jwt.sub
        alt usuario no existe
            B-->>M: 401 Unauthorized
        else usuario existe
            B->>DB: SELECT habit_records WHERE user_id = user.id
            B-->>M: 200 OK [ ...habit_records ]
        end
    end
```

Este segundo diagrama es el flujo que sigue **todo** endpoint privado (`get_current_user` en `backend/app/api/deps.py`) — nunca se confía en un `user_id` enviado por el cliente (plan, sección 10).
