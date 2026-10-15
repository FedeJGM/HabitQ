"""Plain-Spanish labels for the codes the mobile app stores for the profile and
habit questionnaires (mobile/lib/features/habits/habit_questions.dart and
mobile/lib/features/profile/profile_options.dart). The LLM reads these instead
of raw codes like "5_6", which are ambiguous without the question they answer.

Keep in sync with the mobile option lists. Unknown codes are never an error:
callers fall back to the raw value."""

MAIN_GOAL_LABELS: dict[str, str] = {
    "sleep_better": "Dormir mejor",
    "eat_better": "Alimentarme mejor",
    "move_more": "Moverme más",
    "hydrate_more": "Hidratarme mejor",
    "reduce_screen_time": "Reducir el uso de pantallas",
    "manage_stress": "Manejar mejor el estrés",
}

# (domain, key) -> (what the question measures, {stored value: option label})
HABIT_LABELS: dict[tuple[str, str], tuple[str, dict[str, str]]] = {
    ("sleep", "hours"): (
        "Horas de sueño habituales",
        {"less_5": "Menos de 5", "5_6": "5–6", "7_8": "7–8", "more_8": "Más de 8"},
    ),
    ("sleep", "screen_before_bed"): (
        "Uso de pantallas en la última hora antes de dormir",
        {"never": "Nunca", "sometimes": "A veces", "often": "Frecuentemente"},
    ),
    ("nutrition", "fruits_vegetables"): (
        "Frecuencia de consumo de frutas o verduras",
        {"rarely": "Rara vez", "some_days": "Algunos días", "almost_daily": "Casi todos los días"},
    ),
    ("nutrition", "fast_food"): (
        "Frecuencia de consumo de comida rápida o ultraprocesados",
        {
            "rarely": "Rara vez",
            "weekly_1_2": "1–2 veces por semana",
            "weekly_3_plus": "3 o más veces por semana",
        },
    ),
    ("physical_activity", "days_per_week"): (
        "Días por semana con actividad física",
        {"0": "0", "1_2": "1–2", "3_4": "3–4", "5_plus": "5 o más"},
    ),
    ("physical_activity", "sedentary_hours"): (
        "Pasa varias horas seguidas sentado",
        {"yes": "Sí", "no": "No"},
    ),
    ("hydration", "daily_intake"): (
        "Consumo diario de agua",
        {"low": "Bajo", "moderate": "Moderado", "adequate": "Adecuado"},
    ),
    ("screen_time", "recreational_hours"): (
        "Tiempo recreativo frente a pantallas",
        {"less_2h": "Menos de 2 horas", "2_4h": "2–4 horas", "more_4h": "Más de 4 horas"},
    ),
    ("stress", "frequency"): (
        "Frecuencia de estrés durante la rutina",
        {"rarely": "Rara vez", "sometimes": "A veces", "often": "Frecuentemente"},
    ),
}
