import os

os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://test:test@localhost/test_habitq")
os.environ.setdefault("GOOGLE_CLIENT_ID", "test-client-id.apps.googleusercontent.com")
os.environ.setdefault("JWT_SECRET", "test-secret-key-for-pytest-only-32b+")
os.environ.setdefault("GEMINI_API_KEY", "test-gemini-key-for-pytest-only")
