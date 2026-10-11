from app.services.embedding_service import EmbeddingModel, load_embedding_model, prefixes_for


class _Tokenizer:
    def encode(self, text: str, add_special_tokens: bool = True) -> list[str]:
        tokens = text.split()
        return ["<s>", *tokens, "</s>"] if add_special_tokens else tokens


class _RawModel:
    tokenizer = _Tokenizer()
    max_seq_length = 512

    def __init__(self) -> None:
        self.encoded: list[list[str]] = []

    def encode(self, texts: list[str]) -> list[list[float]]:
        self.encoded.append(list(texts))
        return [[float(len(text))] for text in texts]


def test_encode_adds_the_passage_prefix_to_every_text() -> None:
    raw = _RawModel()
    model = EmbeddingModel(raw, query_prefix="query: ", passage_prefix="passage: ")

    vectors = model.encode(["abc", "de"])

    assert raw.encoded == [["passage: abc", "passage: de"]]
    assert vectors == [[float(len("passage: abc"))], [float(len("passage: de"))]]


def test_encode_query_adds_the_query_prefix_and_returns_one_vector() -> None:
    raw = _RawModel()
    model = EmbeddingModel(raw, query_prefix="query: ", passage_prefix="passage: ")

    vector = model.encode_query("hola")

    assert raw.encoded == [["query: hola"]]
    assert vector == [float(len("query: hola"))]


def test_without_prefixes_texts_go_through_unchanged() -> None:
    raw = _RawModel()
    model = EmbeddingModel(raw)

    model.encode(["abc"])
    model.encode_query("q")

    assert raw.encoded == [["abc"], ["q"]]


def test_max_seq_length_reserves_room_for_the_passage_prefix() -> None:
    # "passage: " is one token for the fake tokenizer: that much of the limit
    # is already taken before any chunk text.
    model = EmbeddingModel(_RawModel(), passage_prefix="passage: ")

    assert model.max_seq_length == 511


def test_max_seq_length_is_untouched_without_a_prefix() -> None:
    assert EmbeddingModel(_RawModel()).max_seq_length == 512


def test_tokenizer_is_the_underlying_one() -> None:
    raw = _RawModel()

    assert EmbeddingModel(raw).tokenizer is raw.tokenizer


def test_e5_models_need_query_and_passage_prefixes() -> None:
    assert prefixes_for("intfloat/multilingual-e5-small") == ("query: ", "passage: ")
    assert prefixes_for("Intfloat/Multilingual-E5-Base") == ("query: ", "passage: ")


def test_other_models_get_no_prefixes() -> None:
    assert prefixes_for("all-MiniLM-L6-v2") == ("", "")


def test_load_embedding_model_builds_the_model_with_the_right_prefixes() -> None:
    requested: list[str] = []

    def factory(name: str) -> _RawModel:
        requested.append(name)
        return _RawModel()

    model = load_embedding_model("intfloat/multilingual-e5-small", factory=factory)
    model.encode_query("hola")

    assert requested == ["intfloat/multilingual-e5-small"]
    assert model._model.encoded == [["query: hola"]]
