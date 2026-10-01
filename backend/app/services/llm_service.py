from google import genai
from google.genai import types

from app.core.config import settings

_MODEL = "gemini-flash-latest"

# The SDK already retries 408/429/5xx with exponential backoff + jitter by
# default (attempts=5, up to 60s max delay) — good defaults for a batch job,
# too long for a user waiting on POST /chat. Tighten the window instead of
# writing a retry loop by hand: covers the transient 503 "high demand"
# errors seen on the free tier (D-14) without keeping the request open for
# a minute-plus.
_RETRY_OPTIONS = types.HttpRetryOptions(attempts=3, initial_delay=1.0, max_delay=8.0)

_SYSTEM_INSTRUCTIONS = """Sos HabitQ, un asistente que orienta a personas hacia hábitos saludables \
basándose en evidencia científica.

Reglas que tenés que seguir siempre:
- Respondé en español, con lenguaje sencillo.
- Usá exclusivamente la evidencia del contexto que te paso abajo. No respondas basándote solo \
en tu conocimiento interno cuando la pregunta requiera evidencia científica.
- No inventes fuentes ni resultados científicos. No cites referencias vos mismo: la respuesta \
va a mostrarse junto con las fuentes reales por separado, así que no las menciones en el texto.
- No diagnostiques ni prescribas medicamentos. No presentes afirmaciones médicas como certezas \
absolutas. Recomendá atención profesional cuando corresponda.
- Si te paso contexto del usuario (perfil/hábitos), personalizá la respuesta con eso SOLO cuando \
sea relevante para la pregunta — no lo menciones ni lo fuerces si no viene al caso.
"""


def build_prompt(
    question: str, context_chunks: list[str], user_context: str | None = None
) -> str:
    if context_chunks:
        context_section = "\n\n".join(
            f"[Fragmento {i + 1}]\n{chunk}" for i, chunk in enumerate(context_chunks)
        )
    else:
        context_section = (
            "No hay evidencia disponible en la base de conocimiento para esta pregunta. "
            "Decile al usuario, en español, que no tenés evidencia suficiente para responder "
            "con confianza en vez de inventar una respuesta."
        )

    prompt = f"{_SYSTEM_INSTRUCTIONS}\nContexto recuperado:\n{context_section}\n\n"

    if user_context:
        prompt += (
            "Contexto del usuario (usar SOLO si es relevante para la pregunta):\n"
            f"{user_context}\n\n"
        )

    prompt += f"Pregunta del usuario: {question}\n"
    return prompt


def generate_answer(
    question: str,
    context_chunks: list[str],
    client,
    user_context: str | None = None,
) -> str:
    prompt = build_prompt(question, context_chunks, user_context=user_context)
    response = client.models.generate_content(model=_MODEL, contents=prompt)
    return response.text


def get_gemini_client() -> genai.Client:
    return genai.Client(
        api_key=settings.gemini_api_key,
        http_options=types.HttpOptions(retry_options=_RETRY_OPTIONS),
    )
