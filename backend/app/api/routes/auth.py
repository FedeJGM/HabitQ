from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.security import create_access_token
from app.models.user import User
from app.schemas.auth import GoogleAuthRequest, TokenResponse, UserOut
from app.services.auth_service import get_or_create_user, mark_onboarding_completed
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


@router.get("/me", response_model=UserOut)
def read_current_user(current_user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(current_user)


@router.post("/onboarding-complete", response_model=UserOut)
def complete_onboarding(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> UserOut:
    user = mark_onboarding_completed(db, current_user)
    return UserOut.model_validate(user)
