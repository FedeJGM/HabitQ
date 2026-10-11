from typing import Callable

# E5 models are trained with these markers and retrieve noticeably worse
# without them: questions are "query: ...", document text is "passage: ...".
_E5_QUERY_PREFIX = "query: "
_E5_PASSAGE_PREFIX = "passage: "


def prefixes_for(model_name: str) -> tuple[str, str]:
    """(query prefix, passage prefix) the model expects."""
    if "e5" in model_name.lower():
        return _E5_QUERY_PREFIX, _E5_PASSAGE_PREFIX
    return "", ""


class EmbeddingModel:
    """A SentenceTransformer plus the prefixes its family requires, with one
    method for text being indexed (`encode`) and one for the user's question
    (`encode_query`), so callers never deal with prefixes."""

    def __init__(self, model, *, query_prefix: str = "", passage_prefix: str = "") -> None:
        self._model = model
        self._query_prefix = query_prefix
        self._passage_prefix = passage_prefix

    @property
    def tokenizer(self):
        return self._model.tokenizer

    @property
    def max_seq_length(self) -> int:
        """Tokens available for chunk text: the prefix is part of the input
        the model sees, so it eats into the limit."""
        limit = self._model.max_seq_length
        if not self._passage_prefix:
            return limit
        return limit - len(self._model.tokenizer.encode(self._passage_prefix, add_special_tokens=False))

    def encode(self, texts: list[str]):
        """Embeds passages (document text)."""
        return self._model.encode([self._passage_prefix + text for text in texts])

    def encode_query(self, text: str):
        """Embeds a user question."""
        return self._model.encode([self._query_prefix + text])[0]


def load_embedding_model(name: str, *, factory: Callable | None = None) -> EmbeddingModel:
    if factory is None:
        from sentence_transformers import SentenceTransformer  # heavy import, only when needed

        factory = SentenceTransformer

    try:
        # Already downloaded: load it without touching the network. A normal
        # load still sends update-check requests to the Hub, and when those
        # fail (flaky network, TLS-intercepting proxy) the app crashed with a
        # 500 even though every file was on disk.
        model = factory(name, local_files_only=True)
    except OSError:
        model = factory(name)  # first run on this machine: download it

    query_prefix, passage_prefix = prefixes_for(name)
    return EmbeddingModel(model, query_prefix=query_prefix, passage_prefix=passage_prefix)
