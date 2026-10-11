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

# PyTorch solo CPU. La rueda por defecto de Linux arrastra ~2 GB de librerías
# NVIDIA/CUDA que este contenedor (sin GPU) nunca usa y que multiplican el
# tiempo de build. Va en su propio paso y ANTES de requirements.txt: así
# sentence-transformers encuentra torch ya instalado y, si un paso posterior
# falla, esta capa queda en caché y no se vuelve a descargar.
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-descarga el modelo de embeddings en tiempo de build (no en el primer
# request de chat): evita latencia y dependencia de red saliente la primera
# vez que alguien usa POST /chat contra el contenedor.
ARG EMBEDDING_MODEL_NAME=intfloat/multilingual-e5-small
RUN python -c "import sys; from sentence_transformers import SentenceTransformer; SentenceTransformer(sys.argv[1])" "$EMBEDDING_MODEL_NAME"

COPY . .

EXPOSE 8000

# Aplica las migraciones antes de levantar la API en cada arranque del
# contenedor (idempotente: alembic no reaplica migraciones ya corridas).
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
