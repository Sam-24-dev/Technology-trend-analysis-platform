"""Descarga el ultimo aggregate-data valido desde GitHub Actions."""

from __future__ import annotations

import argparse
import io
import json
import os
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

import requests


REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from scripts.check_bridge_integrity import check_bridge_integrity  # noqa: E402
from scripts.materialize_etl_artifacts import materialize_artifacts  # noqa: E402


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


def _is_zip_symlink(member: zipfile.ZipInfo) -> bool:
    unix_mode = (member.external_attr >> 16) & 0o170000
    return unix_mode == 0o120000


def _resolve_member_path(destination: Path, member_name: str) -> Path:
    target_path = (destination / member_name).resolve()
    try:
        target_path.relative_to(destination.resolve())
    except ValueError as exc:
        raise ValueError(f"Unsafe zip member path: {member_name}") from exc
    return target_path


def _extract_zip(content: bytes, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(content)) as archive:
        for member in archive.infolist():
            if not member.filename or member.filename.endswith("/"):
                continue
            if _is_zip_symlink(member):
                raise ValueError(
                    f"Refusing symlink in artifact archive: {member.filename}"
                )
            safe_target = _resolve_member_path(destination, member.filename)
            safe_target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, safe_target.open("wb") as target:
                shutil.copyfileobj(source, target)


def _ensure_safe_output_dir(output_dir: Path) -> None:
    resolved = output_dir.resolve()
    forbidden = {
        Path(resolved.anchor).resolve(),
        Path.cwd().resolve(),
        Path.home().resolve(),
    }
    if resolved in forbidden:
        raise ValueError(f"Refusing unsafe output_dir: {output_dir}")
    if output_dir.exists() and not output_dir.is_dir():
        raise ValueError(f"output_dir must be a directory path: {output_dir}")
    if not output_dir.name:
        raise ValueError(f"Refusing unsafe output_dir: {output_dir}")


def _replace_output_dir(source_root: Path, output_dir: Path) -> None:
    if output_dir.exists():
        shutil.rmtree(output_dir)
    shutil.copytree(source_root, output_dir)


def _validate_candidate(candidate_root: Path) -> tuple[bool, str | None]:
    with tempfile.TemporaryDirectory() as tmp_dir:
        workspace_root = Path(tmp_dir) / "workspace"
        materialize_artifacts(workspace_root, [candidate_root])
        try:
            check_bridge_integrity(workspace_root, expect_previous_history=False)
        except Exception as exc:
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
    _ensure_safe_output_dir(output_dir)
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
        try:
            artifacts_url = (
                f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/artifacts"
            )
            artifacts_payload = _api_get_json(session, artifacts_url)
            artifacts = [
                artifact
                for artifact in artifacts_payload.get("artifacts", [])
                if artifact.get("name") == artifact_name and not artifact.get("expired")
            ]
        except Exception as exc:
            tested_runs.append(
                {
                    "run_id": run_id,
                    "created_at": run.get("created_at"),
                    "valid": False,
                    "reason": str(exc),
                }
            )
            continue

        if not artifacts:
            continue

        artifact = artifacts[0]
        with tempfile.TemporaryDirectory() as tmp_dir:
            candidate_root = Path(tmp_dir) / "artifact"
            try:
                zip_bytes = _download_artifact_zip(
                    session, artifact["archive_download_url"]
                )
                _extract_zip(zip_bytes, candidate_root)
                is_valid, reason = _validate_candidate(candidate_root)
            except Exception as exc:
                tested_runs.append(
                    {
                        "run_id": run_id,
                        "created_at": run.get("created_at"),
                        "valid": False,
                        "reason": str(exc),
                    }
                )
                continue

            tested_runs.append(
                {
                    "run_id": run_id,
                    "created_at": run.get("created_at"),
                    "valid": is_valid,
                    "reason": reason,
                }
            )
            if not is_valid:
                continue
            _replace_output_dir(candidate_root, output_dir)
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
        token = str(os.environ.get("GITHUB_TOKEN", "")).strip()
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
