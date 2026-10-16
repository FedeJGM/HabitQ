"""Fixed catalog of daily tasks offered for each profile goal.

The user picks which of their goal's tasks to activate; there is no free text.
Tasks are everyday behaviors, never medical advice. `target` is 1 for a
checkbox or N for a counter; `step` is how much one tap on the counter adds.

Goal codes are the same as MAIN_GOAL_LABELS (user_context_labels.py) and the
mobile profile options. Task keys are unique across the whole catalog."""

from dataclasses import dataclass


@dataclass(frozen=True)
class CatalogTask:
    key: str
    label: str
    target: int = 1
    unit: str = ""
    step: int = 1


TASK_CATALOG: dict[str, list[CatalogTask]] = {
    "sleep_better": [
        CatalogTask("sleep_screens_off", "Apagar las pantallas 1 hora antes de dormir"),
        CatalogTask("sleep_same_time", "Acostarme a la misma hora"),
        CatalogTask("sleep_wind_down", "Hacer una rutina tranquila antes de dormir"),
        CatalogTask("sleep_phone_away", "Dejar el celular lejos de la cama"),
    ],
    "eat_better": [
        CatalogTask("eat_fruit_veg", "Comer frutas o verduras", target=5, unit="porciones"),
        CatalogTask("eat_breakfast", "Desayunar"),
        CatalogTask("eat_home_meal", "Preparar una comida en casa"),
        CatalogTask("eat_slowly", "Comer sin prisa y sin distracciones"),
    ],
    "move_more": [
        CatalogTask("move_walk", "Caminar", target=30, unit="min", step=5),
        CatalogTask("move_active_breaks", "Hacer una pausa activa", target=3, unit="pausas"),
        CatalogTask("move_stairs", "Usar las escaleras"),
        CatalogTask("move_exercise", "Hacer ejercicio", target=30, unit="min", step=5),
    ],
    "hydrate_more": [
        CatalogTask("hydrate_water", "Tomar agua", target=8, unit="vasos"),
        CatalogTask("hydrate_morning", "Tomar un vaso de agua al despertar"),
        CatalogTask("hydrate_bottle", "Llevar una botella de agua conmigo"),
        CatalogTask("hydrate_meals", "Tomar agua con cada comida", target=3, unit="comidas"),
    ],
    "reduce_screen_time": [
        CatalogTask("screen_eye_breaks", "Descansar la vista de la pantalla", target=4, unit="pausas"),
        CatalogTask("screen_social_limit", "Limitar el tiempo en redes sociales"),
        CatalogTask("screen_free_meal", "Hacer una comida sin pantallas"),
        CatalogTask("screen_outdoors", "Pasar un rato al aire libre sin el celular"),
    ],
    "manage_stress": [
        CatalogTask("stress_breathing", "Ejercicio de respiración", target=3, unit="veces"),
        CatalogTask("stress_pause", "Tomar una pausa de 5 minutos", target=2, unit="pausas"),
        CatalogTask("stress_fresh_air", "Salir a tomar aire"),
        CatalogTask("stress_positive_note", "Anotar algo bueno del día"),
    ],
}


def tasks_for_goal(goal: str) -> list[CatalogTask]:
    """Tasks offered for a goal code; an unknown code yields an empty list."""
    return TASK_CATALOG.get(goal, [])


def find_task(key: str) -> CatalogTask | None:
    for tasks in TASK_CATALOG.values():
        for task in tasks:
            if task.key == key:
                return task
    return None
