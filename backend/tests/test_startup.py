from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app


def test_embedding_model_is_loaded_at_startup() -> None:
    with patch("app.main.get_embedding_model") as load_model:
        with TestClient(app):
            load_model.assert_called_once()


def test_app_without_lifespan_does_not_load_the_embedding_model() -> None:
    with patch("app.main.get_embedding_model") as load_model:
        TestClient(app).get("/health")
        load_model.assert_not_called()
