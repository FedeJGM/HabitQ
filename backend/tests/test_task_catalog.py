from app.services.task_catalog import TASK_CATALOG, CatalogTask, find_task, tasks_for_goal
from app.services.user_context_labels import MAIN_GOAL_LABELS


def _all_tasks() -> list[CatalogTask]:
    return [task for tasks in TASK_CATALOG.values() for task in tasks]


def test_catalog_covers_exactly_the_profile_goals() -> None:
    assert set(TASK_CATALOG) == set(MAIN_GOAL_LABELS)


def test_every_goal_offers_between_three_and_six_tasks() -> None:
    for goal, tasks in TASK_CATALOG.items():
        assert 3 <= len(tasks) <= 6, goal


def test_task_keys_are_unique_across_the_whole_catalog() -> None:
    keys = [task.key for task in _all_tasks()]
    assert len(keys) == len(set(keys))


def test_every_task_has_a_label_and_a_sane_target_and_step() -> None:
    for task in _all_tasks():
        assert task.label.strip(), task.key
        assert task.target >= 1, task.key
        assert 1 <= task.step <= task.target, task.key


def test_checkbox_tasks_have_target_one_and_counters_name_their_unit() -> None:
    for task in _all_tasks():
        if task.target == 1:
            assert task.step == 1, task.key
        else:
            assert task.unit, task.key


def test_hydration_counter_matches_the_figma_design() -> None:
    water = find_task("hydrate_water")

    assert water is not None
    assert (water.target, water.unit) == (8, "vasos")


def test_find_task_returns_none_for_an_unknown_key() -> None:
    assert find_task("does_not_exist") is None


def test_find_task_returns_the_catalog_entry() -> None:
    task = find_task("stress_breathing")

    assert task is not None
    assert task in TASK_CATALOG["manage_stress"]


def test_tasks_for_goal_returns_that_goals_tasks() -> None:
    assert tasks_for_goal("sleep_better") == TASK_CATALOG["sleep_better"]


def test_tasks_for_an_unknown_goal_is_empty_rather_than_an_error() -> None:
    assert tasks_for_goal("not_a_goal") == []
