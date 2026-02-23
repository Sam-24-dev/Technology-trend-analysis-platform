from config.data_product_contract import (
    build_dataset_manifest,
    build_run_manifest,
    get_data_product_contract_version,
    is_valid_iso_utc,
    is_valid_semver,
    validate_dataset_manifest,
    validate_run_manifest,
)


VALID_HASH = "a" * 64
VALID_RUN_ID = "run-2026-03-01T08:00:00Z"
VALID_GENERATED_AT = "2026-03-01T08:00:00Z"
VALID_WINDOW_START = "2026-02-22T00:00:00Z"
VALID_WINDOW_END = "2026-03-01T00:00:00Z"


def _build_valid_manifest():
    dataset = build_dataset_manifest(
        dataset_logical_name="trend_score",
        version_semver="1.0.0",
        source_run_id=VALID_RUN_ID,
        schema_hash=VALID_HASH,
        row_count=25,
        quality_status="pass",
        latest_path="datos/latest/trend_score.csv",
        history_path="datos/history/trend_score/year=2026/month=03/day=01/part-0000.parquet",
        generated_at_utc=VALID_GENERATED_AT,
    )
    return build_run_manifest(
        run_id=VALID_RUN_ID,
        git_sha="d8d7c8133c60fc11d8ccd104198e1e317903b565",
        branch="feat/backend",
        source_window_start_utc=VALID_WINDOW_START,
        source_window_end_utc=VALID_WINDOW_END,
        quality_gate_status="pass",
        datasets=[dataset],
        generated_at_utc=VALID_GENERATED_AT,
    )


def test_contract_version_is_defined():
    version = get_data_product_contract_version()
    assert isinstance(version, str)
    assert version.strip()


def test_validate_run_manifest_valid_case():
    run_manifest = _build_valid_manifest()
    ok, errors = validate_run_manifest(run_manifest)
    assert ok is True
    assert errors == []


def test_validate_run_manifest_invalid_quality_gate_status():
    run_manifest = _build_valid_manifest()
    run_manifest["quality_gate_status"] = "unknown-status"
    ok, errors = validate_run_manifest(run_manifest)
    assert ok is False
    assert any("quality_gate_status" in err for err in errors)


def test_validate_run_manifest_requires_datasets():
    run_manifest = _build_valid_manifest()
    run_manifest["datasets"] = []
    ok, errors = validate_run_manifest(run_manifest)
    assert ok is False
    assert any("'datasets' no puede estar vacio" in err for err in errors)


def test_validate_dataset_manifest_detects_source_run_id_mismatch():
    dataset_manifest = _build_valid_manifest()["datasets"][0]
    errors = validate_dataset_manifest(dataset_manifest, expected_run_id="another-run")
    assert errors
    assert any("source_run_id" in err for err in errors)


def test_validate_dataset_manifest_rejects_invalid_semver():
    dataset_manifest = _build_valid_manifest()["datasets"][0]
    dataset_manifest["version_semver"] = "1.0"
    errors = validate_dataset_manifest(dataset_manifest)
    assert errors
    assert any("SemVer" in err for err in errors)


def test_validate_dataset_manifest_allows_null_history_path_when_failed_quality():
    dataset_manifest = _build_valid_manifest()["datasets"][0]
    dataset_manifest["quality_status"] = "fail"
    dataset_manifest["history_path"] = None
    errors = validate_dataset_manifest(dataset_manifest)
    assert errors == []


def test_validate_dataset_manifest_requires_valid_schema_hash():
    dataset_manifest = _build_valid_manifest()["datasets"][0]
    dataset_manifest["schema_hash"] = "abc123"
    errors = validate_dataset_manifest(dataset_manifest)
    assert errors
    assert any("schema_hash" in err for err in errors)


def test_semver_and_iso_helpers():
    assert is_valid_semver("1.0.0") is True
    assert is_valid_semver("1.0") is False
    assert is_valid_iso_utc("2026-03-01T08:00:00Z") is True
    assert is_valid_iso_utc("2026/03/01 08:00:00") is False

