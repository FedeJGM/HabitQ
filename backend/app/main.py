from fastapi import FastAPI

from app.api.routes import auth

app = FastAPI(title="HabitQ API")

app.include_router(auth.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
