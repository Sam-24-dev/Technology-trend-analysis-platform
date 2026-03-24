"""Descarga el ultimo aggregate-data valido desde GitHub Actions."""

from __future__ import annotations

import argparse
import io
import json
import shutil
import tempfile
import zipfile
from pathlib import Path

import requests

from scripts.check_bridge_integrity import check_bridge_integrity
from scripts.materialize_etl_artifacts import materialize_artifacts


def _api_get_json(session: requests.Session, url: str) -> dict:
    response = session.get(url, timeout=60)
    response.raise_for_status()
    return response.json()


def _download_artifact_zip(session: requests.Session, url: str) -> bytes:
    response = session.get(
        url,
        timeout=120,
        headers={"Accept": "application/vnd.github+json"},
        allow_redirects=True,
    )
    response.raise_for_status()
    return response.content


def _extract_zip(content: bytes, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        archive.extractall(destination)


def _validate_candidate(candidate_root: Path) -> tuple[bool, str | None]:
    with tempfile.TemporaryDirectory() as tmp_dir:
        workspace_root = Path(tmp_dir) / "workspace"
        materialize_artifacts(workspace_root, [candidate_root])
        try:
            check_bridge_integrity(workspace_root, expect_previous_history=False)
        except Exception as exc:  # pragma: no cover - exercised in tests via result string
            return False, str(exc)
    return True, None


def download_latest_valid_aggregate_artifact(
    *,
    repo: str,
    workflow: str,
    branch: str,
    artifact_name: str,
    output_dir: Path | str,
    token: str,
    max_runs: int = 20,
) -> dict[str, object]:
    output_dir = Path(output_dir)
    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
    )

    runs_url = (
        f"https://api.github.com/repos/{repo}/actions/workflows/{workflow}/runs"
        f"?branch={branch}&status=success&per_page={max_runs}"
    )
    runs_payload = _api_get_json(session, runs_url)
    tested_runs: list[dict[str, object]] = []

    for run in runs_payload.get("workflow_runs", []):
        run_id = run["id"]
        artifacts_url = f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/artifacts"
        artifacts_payload = _api_get_json(session, artifacts_url)
        artifacts = [
            artifact
            for artifact in artifacts_payload.get("artifacts", [])
            if artifact.get("name") == artifact_name and not artifact.get("expired")
        ]
        if not artifacts:
            continue

        artifact = artifacts[0]
        with tempfile.TemporaryDirectory() as tmp_dir:
            candidate_root = Path(tmp_dir) / "artifact"
            zip_bytes = _download_artifact_zip(session, artifact["archive_download_url"])
            _extract_zip(zip_bytes, candidate_root)
            is_valid, reason = _validate_candidate(candidate_root)
            tested_runs.append(
                {
                    "run_id": run_id,
                    "created_at": run.get("created_at"),
                    "valid": is_valid,
                    "reason": reason,
                }
            )
            if is_valid:
                shutil.rmtree(output_dir)
                shutil.copytree(candidate_root, output_dir)
                return {
                    "status": "ok",
                    "selected_run_id": run_id,
                    "selected_artifact_id": artifact["id"],
                    "tested_runs": tested_runs,
                }

    return {
        "status": "missing",
        "selected_run_id": None,
        "selected_artifact_id": None,
        "tested_runs": tested_runs,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--workflow", required=True)
    parser.add_argument("--branch", default="main")
    parser.add_argument("--artifact-name", default="aggregate-data")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--max-runs", type=int, default=20)
    parser.add_argument(
        "--token",
        default=None,
        help="GitHub token; si se omite, usa GITHUB_TOKEN del entorno.",
    )
    args = parser.parse_args()

    token = args.token
    if not token:
        token = str(__import__("os").environ.get("GITHUB_TOKEN", "")).strip()
    if not token:
        raise SystemExit("Missing GitHub token. Provide --token or set GITHUB_TOKEN.")

    summary = download_latest_valid_aggregate_artifact(
        repo=args.repo,
        workflow=args.workflow,
        branch=args.branch,
        artifact_name=args.artifact_name,
        output_dir=Path(args.output_dir),
        token=token,
        max_runs=args.max_runs,
    )
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
