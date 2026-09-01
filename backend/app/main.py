from fastapi import FastAPI

from app.api.routes import auth, habits, profile

app = FastAPI(title="HabitQ API")

app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(habits.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
