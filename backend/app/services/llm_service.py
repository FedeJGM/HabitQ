from google import genai

from app.core.config import settings

_MODEL = "gemini-flash-latest"

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
"""


def build_prompt(question: str, context_chunks: list[str]) -> str:
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

    return (
        f"{_SYSTEM_INSTRUCTIONS}\n"
        f"Contexto recuperado:\n{context_section}\n\n"
        f"Pregunta del usuario: {question}\n"
    )


def generate_answer(question: str, context_chunks: list[str], client) -> str:
    prompt = build_prompt(question, context_chunks)
    response = client.models.generate_content(model=_MODEL, contents=prompt)
    return response.text


def get_gemini_client() -> genai.Client:
    return genai.Client(api_key=settings.gemini_api_key)
