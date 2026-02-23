import pytest

from quality.degradation_policy import (
    DEFAULT_SOURCE_WEIGHTS,
    evaluate_degradation_policy,
)


@pytest.mark.parametrize(
    ("source_status", "expected_publish", "expected_quality", "expected_mode", "expected_count"),
    [
        ({"github": True, "stackoverflow": True, "reddit": True}, True, "pass", "default", 3),
        ({"github": True, "stackoverflow": True, "reddit": False}, True, "pass_with_warnings", "renormalized", 2),
        ({"github": True, "stackoverflow": False, "reddit": False}, False, "fail", "unavailable", 1),
        ({"github": False, "stackoverflow": False, "reddit": False}, False, "fail", "unavailable", 0),
    ],
)
def test_degradation_matrix(source_status, expected_publish, expected_quality, expected_mode, expected_count):
    decision = evaluate_degradation_policy(source_status)
    assert decision["publish_allowed"] is expected_publish
    assert decision["quality_gate_status"] == expected_quality
    assert decision["weights_mode"] == expected_mode
    assert decision["available_count"] == expected_count


def test_degradation_policy_renormalizes_weights_when_one_source_is_missing():
    decision = evaluate_degradation_policy({"github": True, "stackoverflow": False, "reddit": True})
    assert decision["publish_allowed"] is True
    assert decision["weights_mode"] == "renormalized"

    effective = decision["effective_weights"]
    assert set(effective.keys()) == {"github", "reddit"}
    assert round(sum(effective.values()), 6) == 1.0
    assert effective["github"] > effective["reddit"]


def test_degradation_policy_handles_missing_keys_as_unavailable():
    decision = evaluate_degradation_policy({"github": True})
    assert decision["available_count"] == 1
    assert decision["publish_allowed"] is False
    assert decision["effective_weights"] == {}


def test_degradation_policy_preserves_default_weights_with_all_sources():
    decision = evaluate_degradation_policy(
        {"github": True, "stackoverflow": True, "reddit": True},
        default_weights=DEFAULT_SOURCE_WEIGHTS,
    )
    assert decision["weights_mode"] == "default"
    assert decision["effective_weights"] == DEFAULT_SOURCE_WEIGHTS
