import io
import zipfile

from scripts.download_valid_aggregate_artifact import (
    _ensure_safe_output_dir,
    _extract_zip,
    download_latest_valid_aggregate_artifact,
)


def _build_zip(files):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        for name, content in files.items():
            archive.writestr(name, content)
    return buffer.getvalue()


def test_download_latest_valid_aggregate_artifact_skips_invalid_latest_run(
    tmp_path,
    monkeypatch,
):
    invalid_zip = _build_zip({"marker.txt": "invalid"})
    valid_zip = _build_zip({"marker.txt": "valid"})

    def fake_api_get_json(_session, url):
        if "workflows/etl_semanal.yml/runs" in url:
            return {
                "workflow_runs": [
                    {"id": 201, "created_at": "2026-03-23T08:00:00Z"},
                    {"id": 200, "created_at": "2026-03-22T08:00:00Z"},
                ]
            }
        if "/actions/runs/201/artifacts" in url:
            return {
                "artifacts": [
                    {
                        "id": 301,
                        "name": "aggregate-data",
                        "expired": False,
                        "archive_download_url": "https://example.test/301",
                    }
                ]
            }
        if "/actions/runs/200/artifacts" in url:
            return {
                "artifacts": [
                    {
                        "id": 300,
                        "name": "aggregate-data",
                        "expired": False,
                        "archive_download_url": "https://example.test/300",
                    }
                ]
            }
        raise AssertionError(f"Unexpected URL {url}")

    def fake_download(_session, url):
        return invalid_zip if url.endswith("/301") else valid_zip

    def fake_validate(candidate_root):
        marker = (candidate_root / "marker.txt").read_text(encoding="utf-8")
        if marker == "valid":
            return True, None
        return False, "broken aggregate"

    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._api_get_json",
        fake_api_get_json,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._download_artifact_zip",
        fake_download,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._validate_candidate",
        fake_validate,
    )

    summary = download_latest_valid_aggregate_artifact(
        repo="owner/repo",
        workflow="etl_semanal.yml",
        branch="main",
        artifact_name="aggregate-data",
        output_dir=tmp_path / "out",
        token="token",
        max_runs=5,
    )

    assert summary["status"] == "ok"
    assert summary["selected_run_id"] == 200
    tested_runs = summary["tested_runs"]
    assert tested_runs[0]["valid"] is False
    assert tested_runs[1]["valid"] is True
    assert (tmp_path / "out" / "marker.txt").read_text(encoding="utf-8") == "valid"


def test_download_latest_valid_aggregate_artifact_returns_missing_when_none_validate(
    tmp_path,
    monkeypatch,
):
    invalid_zip = _build_zip({"marker.txt": "invalid"})

    def fake_api_get_json(_session, url):
        if "workflows/etl_semanal.yml/runs" in url:
            return {"workflow_runs": [{"id": 201, "created_at": "2026-03-23T08:00:00Z"}]}
        if "/actions/runs/201/artifacts" in url:
            return {
                "artifacts": [
                    {
                        "id": 301,
                        "name": "aggregate-data",
                        "expired": False,
                        "archive_download_url": "https://example.test/301",
                    }
                ]
            }
        raise AssertionError(f"Unexpected URL {url}")

    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._api_get_json",
        fake_api_get_json,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._download_artifact_zip",
        lambda _session, _url: invalid_zip,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._validate_candidate",
        lambda _candidate_root: (False, "broken aggregate"),
    )

    summary = download_latest_valid_aggregate_artifact(
        repo="owner/repo",
        workflow="etl_semanal.yml",
        branch="main",
        artifact_name="aggregate-data",
        output_dir=tmp_path / "out",
        token="token",
        max_runs=5,
    )

    assert summary["status"] == "missing"
    assert summary["selected_run_id"] is None
    assert summary["tested_runs"][0]["reason"] == "broken aggregate"


def test_download_latest_valid_aggregate_artifact_continues_after_candidate_exception(
    tmp_path,
    monkeypatch,
):
    valid_zip = _build_zip({"marker.txt": "valid"})

    def fake_api_get_json(_session, url):
        if "workflows/etl_semanal.yml/runs" in url:
            return {
                "workflow_runs": [
                    {"id": 202, "created_at": "2026-03-23T09:00:00Z"},
                    {"id": 201, "created_at": "2026-03-22T08:00:00Z"},
                ]
            }
        if "/actions/runs/202/artifacts" in url:
            return {
                "artifacts": [
                    {
                        "id": 302,
                        "name": "aggregate-data",
                        "expired": False,
                        "archive_download_url": "https://example.test/302",
                    }
                ]
            }
        if "/actions/runs/201/artifacts" in url:
            return {
                "artifacts": [
                    {
                        "id": 301,
                        "name": "aggregate-data",
                        "expired": False,
                        "archive_download_url": "https://example.test/301",
                    }
                ]
            }
        raise AssertionError(f"Unexpected URL {url}")

    def fake_download(_session, url):
        if url.endswith("/302"):
            raise RuntimeError("artifact download failed")
        return valid_zip

    def fake_validate(candidate_root):
        marker = (candidate_root / "marker.txt").read_text(encoding="utf-8")
        return (marker == "valid", None if marker == "valid" else "invalid")

    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._api_get_json",
        fake_api_get_json,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._download_artifact_zip",
        fake_download,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._validate_candidate",
        fake_validate,
    )

    summary = download_latest_valid_aggregate_artifact(
        repo="owner/repo",
        workflow="etl_semanal.yml",
        branch="main",
        artifact_name="aggregate-data",
        output_dir=tmp_path / "out",
        token="token",
        max_runs=5,
    )

    assert summary["status"] == "ok"
    assert summary["selected_run_id"] == 201
    assert summary["tested_runs"][0]["valid"] is False
    assert "artifact download failed" in summary["tested_runs"][0]["reason"]


def test_download_latest_valid_aggregate_artifact_raises_when_output_write_fails(
    tmp_path,
    monkeypatch,
):
    valid_zip = _build_zip({"marker.txt": "valid"})

    def fake_api_get_json(_session, url):
        if "workflows/etl_semanal.yml/runs" in url:
            return {"workflow_runs": [{"id": 201, "created_at": "2026-03-23T08:00:00Z"}]}
        if "/actions/runs/201/artifacts" in url:
            return {
                "artifacts": [
                    {
                        "id": 301,
                        "name": "aggregate-data",
                        "expired": False,
                        "archive_download_url": "https://example.test/301",
                    }
                ]
            }
        raise AssertionError(f"Unexpected URL {url}")

    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._api_get_json",
        fake_api_get_json,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._download_artifact_zip",
        lambda _session, _url: valid_zip,
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._validate_candidate",
        lambda _candidate_root: (True, None),
    )
    monkeypatch.setattr(
        "scripts.download_valid_aggregate_artifact._replace_output_dir",
        lambda _source_root, _output_dir: (_ for _ in ()).throw(
            OSError("copy failed")
        ),
    )

    try:
        download_latest_valid_aggregate_artifact(
            repo="owner/repo",
            workflow="etl_semanal.yml",
            branch="main",
            artifact_name="aggregate-data",
            output_dir=tmp_path / "out",
            token="token",
            max_runs=5,
        )
    except OSError as exc:
        assert "copy failed" in str(exc)
    else:
        raise AssertionError("Expected output write failure to be fatal")


def test_extract_zip_rejects_path_traversal(tmp_path):
    malicious_zip = _build_zip({"../escape.txt": "boom"})

    try:
        _extract_zip(malicious_zip, tmp_path / "out")
    except ValueError as exc:
        assert "Unsafe zip member path" in str(exc)
    else:
        raise AssertionError("Expected path traversal zip to be rejected")

    assert not (tmp_path / "escape.txt").exists()


def test_ensure_safe_output_dir_rejects_current_working_directory(monkeypatch, tmp_path):
    monkeypatch.chdir(tmp_path)

    try:
        _ensure_safe_output_dir(tmp_path)
    except ValueError as exc:
        assert "Refusing unsafe output_dir" in str(exc)
    else:
        raise AssertionError("Expected unsafe output_dir to be rejected")
