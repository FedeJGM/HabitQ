from fastapi import FastAPI

from app.api.routes import auth, chat, habits, profile

app = FastAPI(title="HabitQ API")

app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(habits.router)
app.include_router(chat.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
