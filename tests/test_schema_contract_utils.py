import pytest

from config.schema_contract_utils import (
    SEMVER_MAJOR,
    SEMVER_MINOR,
    SEMVER_PATCH,
    aggregate_semver_bump,
    canonicalize_schema_columns,
    compute_schema_hash,
    recommend_semver_bump,
)


def test_compute_schema_hash_is_deterministic_for_equivalent_columns():
    schema_a = [
        {"name": "technology", "type": "string", "nullable": False},
        {"name": "trend_score", "type": "float64", "nullable": False},
        {"name": "ranking", "type": "int64", "nullable": False},
    ]
    schema_b = [
        {"name": "ranking", "type": "integer", "nullable": False},
        {"name": "trend_score", "type": "number", "nullable": False},
        {"name": "technology", "type": "str", "nullable": False},
    ]

    hash_a = compute_schema_hash(schema_a)
    hash_b = compute_schema_hash(schema_b)
    assert hash_a == hash_b
    assert len(hash_a) == 64


def test_compute_schema_hash_changes_when_semantic_schema_changes():
    baseline = [
        {"name": "technology", "type": "string", "nullable": False},
        {"name": "trend_score", "type": "number", "nullable": False},
    ]
    with_nullable_change = [
        {"name": "technology", "type": "string", "nullable": True},
        {"name": "trend_score", "type": "number", "nullable": False},
    ]
    with_type_change = [
        {"name": "technology", "type": "string", "nullable": False},
        {"name": "trend_score", "type": "integer", "nullable": False},
    ]

    baseline_hash = compute_schema_hash(baseline)
    nullable_hash = compute_schema_hash(with_nullable_change)
    type_hash = compute_schema_hash(with_type_change)

    assert baseline_hash != nullable_hash
    assert baseline_hash != type_hash


def test_canonicalize_schema_columns_drops_invalid_entries_and_sorts():
    raw_columns = [
        {"name": "", "type": "string", "nullable": False},
        {"name": "Trend_Score", "type": "double", "nullable": False},
        {"name": "technology", "type": "str", "nullable": False},
    ]
    canonical = canonicalize_schema_columns(raw_columns)
    assert canonical == [
        {"name": "technology", "type": "string", "nullable": False},
        {"name": "trend_score", "type": "number", "nullable": False},
    ]


@pytest.mark.parametrize(
    ("change_kind", "expected_bump"),
    [
        ("remove_required_column", SEMVER_MAJOR),
        ("rename_required_column", SEMVER_MAJOR),
        ("change_type_incompatible", SEMVER_MAJOR),
        ("tighten_nullability", SEMVER_MAJOR),
        ("drop_dataset", SEMVER_MAJOR),
        ("add_optional_column", SEMVER_MINOR),
        ("add_required_column_with_default", SEMVER_MINOR),
        ("add_non_breaking_quality_rule", SEMVER_MINOR),
        ("add_partition_field_backward_compatible", SEMVER_MINOR),
        ("fix_quality_rule_bug", SEMVER_PATCH),
        ("metadata_only_change", SEMVER_PATCH),
        ("backfill_without_schema_change", SEMVER_PATCH),
    ],
)
def test_recommend_semver_bump_for_representative_changes(change_kind, expected_bump):
    assert recommend_semver_bump(change_kind) == expected_bump


def test_recommend_semver_bump_rejects_unknown_changes():
    with pytest.raises(ValueError):
        recommend_semver_bump("unknown_change")


def test_aggregate_semver_bump_uses_highest_required_priority():
    assert aggregate_semver_bump(["metadata_only_change", "add_optional_column"]) == SEMVER_MINOR
    assert (
        aggregate_semver_bump(["metadata_only_change", "add_optional_column", "remove_required_column"])
        == SEMVER_MAJOR
    )
