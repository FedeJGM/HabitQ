from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.deps import get_embedding_model
from app.api.routes import admin, auth, chat, habits, profile, tasks


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Load the embedding model once at startup so the first POST /chat does
    # not pay the load time (it can exceed the mobile app's 60s timeout).
    # TestClient only runs this when used as a context manager.
    get_embedding_model()
    yield


app = FastAPI(title="HabitQ API", lifespan=lifespan)

app.include_router(admin.router)
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(habits.router)
app.include_router(tasks.router)
app.include_router(chat.router)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
