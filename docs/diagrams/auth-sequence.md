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

## Login en el panel de administración (navegador)

Reutiliza el mismo `POST /auth/google` y el mismo JWT que la app móvil. Lo único nuevo es quién obtiene el ID token (Google Identity Services en el navegador) y la comprobación `require_admin`.

```mermaid
sequenceDiagram
    participant A as Administrador
    participant P as Panel (/admin, navegador)
    participant G as Google Identity Services
    participant B as FastAPI
    participant DB as PostgreSQL

    A->>P: Abre http://localhost:8000/admin
    P->>B: GET /admin
    B-->>P: HTML con GOOGLE_CLIENT_ID ya inyectado (página pública)
    P->>G: initialize(client_id) + botón de Google
    A->>G: Elige su cuenta
    G-->>P: ID token (credential)
    P->>B: POST /auth/google { id_token }
    B->>G: Valida el ID token (audiencia = GOOGLE_CLIENT_ID)
    B->>DB: SELECT / INSERT user (cualquier cuenta de Google queda registrada)
    B-->>P: { access_token, user }
    P->>P: Guarda el JWT en sessionStorage
    P->>B: GET /admin/candidates\nAuthorization: Bearer <jwt>
    B->>B: get_current_user(jwt) → require_admin: ¿email ∈ ADMIN_EMAILS?
    alt es admin
        B-->>P: 200 OK [ ...candidatos ]
        P->>A: Muestra «1. Buscar documentos», «2. Revisar candidatos» y «3. Historial de documentos»
    else no es admin
        B-->>P: 403 Forbidden
        P->>A: «Esta cuenta no es administradora.» (borra el JWT)
    end
```

Puntos que conviene recordar:

- **Origen autorizado:** el cliente OAuth **Web** debe tener `http://localhost` y `http://localhost:8000` en *Authorized JavaScript origins*. Hay que abrir el panel con esa dirección exacta (no `127.0.0.1`).
- **Todo correo queda registrado:** iniciar sesión con una cuenta que no es admin igualmente crea su fila en `users`; el 403 llega después, en el primer endpoint `/admin`.
- **`ADMIN_EMAILS`** se compara sin distinguir mayúsculas y se lee al arrancar el backend: tras cambiarlo hay que reiniciarlo.
- **Alternativa sin Google:** el panel acepta pegar un JWT ya emitido (sección «Alternativa» de la pantalla de login).
