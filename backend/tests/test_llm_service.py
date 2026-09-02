from app.services.llm_service import build_prompt, generate_answer


class _FakeResponse:
    def __init__(self, text: str) -> None:
        self.text = text


class _FakeModels:
    def __init__(self, response_text: str) -> None:
        self._response_text = response_text
        self.calls: list[dict] = []

    def generate_content(self, model: str, contents: str) -> _FakeResponse:
        self.calls.append({"model": model, "contents": contents})
        return _FakeResponse(self._response_text)


class _FakeClient:
    def __init__(self, response_text: str = "respuesta") -> None:
        self.models = _FakeModels(response_text)


# --- build_prompt ---


def test_build_prompt_includes_the_question() -> None:
    prompt = build_prompt("¿Cuánto debo dormir?", ["chunk uno"])
    assert "¿Cuánto debo dormir?" in prompt


def test_build_prompt_includes_every_context_chunk() -> None:
    prompt = build_prompt("q", ["chunk uno", "chunk dos"])
    assert "chunk uno" in prompt
    assert "chunk dos" in prompt


def test_build_prompt_includes_spanish_and_evidence_only_instructions() -> None:
    prompt = build_prompt("q", ["chunk"])
    assert "español" in prompt.lower()
    assert "evidencia" in prompt.lower()


def test_build_prompt_with_empty_context_signals_no_evidence_available() -> None:
    empty_prompt = build_prompt("q", [])
    with_context_prompt = build_prompt("q", ["chunk"])

    assert empty_prompt != with_context_prompt
    assert "no hay" in empty_prompt.lower() or "sin evidencia" in empty_prompt.lower()


# --- generate_answer ---


def test_generate_answer_returns_the_client_response_text() -> None:
    client = _FakeClient(response_text="Dormí 7 a 8 horas.")

    result = generate_answer("¿Cuánto debo dormir?", ["chunk relevante"], client)

    assert result == "Dormí 7 a 8 horas."


def test_generate_answer_sends_the_built_prompt_to_the_configured_model() -> None:
    client = _FakeClient()

    generate_answer("¿Cuánto debo dormir?", ["chunk relevante"], client)

    assert len(client.models.calls) == 1
    call = client.models.calls[0]
    assert call["model"] == "gemini-flash-latest"
    assert "¿Cuánto debo dormir?" in call["contents"]
    assert "chunk relevante" in call["contents"]
