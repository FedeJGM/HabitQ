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

GENDER_LABELS: dict[str, str] = {
    "female": "Femenino",
    "male": "Masculino",
    "other": "Otro",
    "prefer_not_to_say": "Prefiere no decir",
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
        "Veces al día que incluye frutas o verduras",
        {"none": "Ninguna", "1": "1 vez", "2": "2 veces", "3_plus": "3 o más veces"},
    ),
    ("nutrition", "fast_food"): (
        "Comida rápida o ultraprocesados a la semana",
        {
            "never": "Nunca",
            "weekly_1_3": "1–3 veces",
            "weekly_4_6": "4–6 veces",
            "daily": "Todos los días",
        },
    ),
    ("physical_activity", "days_per_week"): (
        "Días a la semana que hace ejercicio",
        {"0": "Ninguno", "1_2": "1–2", "3_4": "3–4", "5_plus": "5 o más"},
    ),
    ("physical_activity", "sedentary_hours"): (
        "Horas al día sentado",
        {"less_4h": "Menos de 4 h", "4_6h": "4–6 h", "7_9h": "7–9 h", "more_9h": "Más de 9 h"},
    ),
    ("hydration", "daily_intake"): (
        "Litros de agua al día",
        {"less_1l": "Menos de 1 L", "1_2l": "1–2 L", "2_3l": "2–3 L", "more_3l": "Más de 3 L"},
    ),
    ("screen_time", "recreational_hours"): (
        "Tiempo diario frente a dispositivos electrónicos",
        {"less_2h": "Menos de 2 h", "2_4h": "2–4 h", "4_6h": "4–6 h", "more_6h": "Más de 6 h"},
    ),
    ("stress", "frequency"): (
        "Días a la semana con estrés que afecta la rutina (último mes)",
        {"none": "Ninguno", "1_2": "1–2 días", "3_4": "3–4 días", "5_plus": "5 o más días"},
    ),
}
