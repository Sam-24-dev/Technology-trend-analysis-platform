from pathlib import Path

from scripts.check_frontend_assets import ASSET_ALLOWLIST, run_policy_check


def _write_frontend_reference_file(frontend_lib_dir: Path, asset_names: set[str]) -> None:
    frontend_lib_dir.mkdir(parents=True, exist_ok=True)
    lines = [f"final _a{i} = 'assets/data/{name}';" for i, name in enumerate(sorted(asset_names), start=1)]
    (frontend_lib_dir / "asset_refs.dart").write_text("\n".join(lines), encoding="utf-8")


def test_assets_policy_warning_mode_does_not_fail(tmp_path):
    root = tmp_path
    assets_dir = root / "frontend" / "assets" / "data"
    lib_dir = root / "frontend" / "lib"

    assets_dir.mkdir(parents=True, exist_ok=True)
    (assets_dir / "trend_score.csv").write_text("score\n1\n", encoding="utf-8")
    _write_frontend_reference_file(lib_dir, {"trend_score.csv"})

    result = run_policy_check(
        root=root,
        mode="warning",
        max_file_kb=150,
        max_total_kb=600,
        max_critical_kb=250,
    )

    assert result == 0


def test_assets_policy_strict_mode_fails_on_missing_required(tmp_path):
    root = tmp_path
    assets_dir = root / "frontend" / "assets" / "data"
    lib_dir = root / "frontend" / "lib"

    assets_dir.mkdir(parents=True, exist_ok=True)
    (assets_dir / "trend_score.csv").write_text("score\n1\n", encoding="utf-8")
    _write_frontend_reference_file(lib_dir, {"trend_score.csv"})

    result = run_policy_check(
        root=root,
        mode="strict",
        max_file_kb=150,
        max_total_kb=600,
        max_critical_kb=250,
    )

    assert result == 1


def test_assets_policy_strict_mode_passes_when_contract_is_met(tmp_path):
    root = tmp_path
    assets_dir = root / "frontend" / "assets" / "data"
    lib_dir = root / "frontend" / "lib"

    assets_dir.mkdir(parents=True, exist_ok=True)
    for asset_name in ASSET_ALLOWLIST:
        (assets_dir / asset_name).write_text("ok\n", encoding="utf-8")

    _write_frontend_reference_file(lib_dir, ASSET_ALLOWLIST)

    result = run_policy_check(
        root=root,
        mode="strict",
        max_file_kb=150,
        max_total_kb=600,
        max_critical_kb=250,
    )

    assert result == 0
