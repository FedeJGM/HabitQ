from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.core.security import create_access_token
from app.schemas.auth import GoogleAuthRequest, TokenResponse, UserOut
from app.services.auth_service import get_or_create_user
from app.services.google_auth import InvalidGoogleTokenError, verify_google_id_token

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/google", response_model=TokenResponse)
def login_with_google(payload: GoogleAuthRequest, db: Session = Depends(get_db)) -> TokenResponse:
    try:
        claims = verify_google_id_token(payload.id_token)
    except InvalidGoogleTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    user = get_or_create_user(
        db,
        google_id=claims["sub"],
        email=claims["email"],
        name=claims.get("name", claims["email"]),
    )

    access_token = create_access_token(user.id)
    return TokenResponse(access_token=access_token, user=UserOut.model_validate(user))
