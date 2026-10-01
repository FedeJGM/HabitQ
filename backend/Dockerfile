# Backend HabitQ (FastAPI + SQLAlchemy + Alembic)
# Build context: ./backend (ver docker-compose.yml en la raíz del repo)

FROM python:3.11-slim

WORKDIR /app

# libgomp1: requerido en runtime por torch (dependencia transitiva de
# sentence-transformers, usada en app/api/deps.py:get_embedding_model).
# python:3.11-slim no lo trae por defecto y torch falla con
# "libgomp.so.1: cannot open shared object file" sin él.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-descarga el modelo de embeddings en tiempo de build (no en el primer
# request de chat): evita latencia y dependencia de red saliente la primera
# vez que alguien usa POST /chat contra el contenedor.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

COPY . .

EXPOSE 8000

# Aplica las migraciones antes de levantar la API en cada arranque del
# contenedor (idempotente: alembic no reaplica migraciones ya corridas).
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
