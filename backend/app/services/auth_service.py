from sqlalchemy.orm import Session

from app.models.user import User


def get_or_create_user(db: Session, *, google_id: str, email: str, name: str) -> User:
    user = db.query(User).filter(User.google_id == google_id).first()
    if user is not None:
        return user

    user = User(google_id=google_id, email=email, name=name)
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
