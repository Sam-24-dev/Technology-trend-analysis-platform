"""Committed admission uses real disposable Git objects, never live producer data."""

from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
from pathlib import Path

import pytest

from scripts import check_reddit_package_admission as gate
from reddit_source_package import REDDIT_SCOPE, producer_minimum_mentions

NOW = datetime(2026, 10, 6, 12, tzinfo=timezone.utc)


def write_package(repo, total=800, finish=NOW):
    contents = (
        b"framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\r\nPython,2,1,1,0,50,50,0\r\n",
        f"tema,menciones\r\nPython,{total}\r\n".encode(),
    )
    outputs = {}
    for path, data in zip(gate.PATHS, contents):
        target = repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        outputs[Path(path).name] = {"rows": 1, "sha256": hashlib.sha256(data).hexdigest()}
    outputs[Path(gate.PATHS[1]).name]["mentions_total"] = total
    receipt = {"source": "reddit", "reference_date_utc": finish.date().isoformat(),
               "source_date_utc": finish.date().isoformat(), "scope": list(REDDIT_SCOPE),
               "posts_count": 3000, "outputs": outputs,
               "extraction_started_at_utc": finish.strftime("%Y-%m-%dT%H:%M:%SZ"),
               "extraction_finished_at_utc": finish.strftime("%Y-%m-%dT%H:%M:%SZ")}
    target = repo / gate.PATHS[2]
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(receipt) + "\n", encoding="utf-8")
    return receipt


def save(repo):
    gate.git(repo, "add", "--all")
    gate.git(repo, "commit", "-qm", "test: package fixture")
    return gate.git(repo, "rev-parse", "HEAD").decode().strip()


@pytest.fixture(params=[False, True])
def candidate(tmp_path, request):
    repo = tmp_path / "repo"
    repo.mkdir()
    gate.git(repo, "init", "-q")
    for key, value in (("user.name", "Fixture"), ("user.email", "fixture@example.invalid"),
                       ("core.autocrlf", str(request.param).lower())):
        gate.git(repo, "config", key, value)
    (repo / ".gitattributes").write_bytes((gate.ROOT / ".gitattributes").read_bytes())
    write_package(repo, 900, NOW - timedelta(days=9))
    base = save(repo)
    receipt = write_package(repo)
    return repo, base, receipt


def test_exact_blobs_ignore_worktree_and_allow_unchanged_csv(candidate):
    repo, base, _ = candidate
    head = save(repo)
    (repo / gate.PATHS[2]).unlink()
    gate.git(repo, "restore", "--worktree", "--", gate.PATHS[2])
    assert json.loads((repo / gate.PATHS[2]).read_bytes()) == json.loads(gate.git(repo, "cat-file", "blob", head + ":" + gate.PATHS[2]))
    assert gate.git(repo, "rev-parse", base + ":" + gate.PATHS[0]) == gate.git(repo, "rev-parse", head + ":" + gate.PATHS[0])
    (repo / gate.PATHS[1]).write_bytes(b"untrusted worktree bytes")
    before = (gate.git(repo, "show-ref"), gate.git(repo, "status", "--porcelain"))
    result = gate.admit(repo, base, head, now=NOW)
    assert result["minimum_mentions"] == 765 and result["mentions_total"] == 800
    assert result["posts_count_claim"] == 3000
    assert result["identity"] == result["freshness"] == result["eligibility"] == "pass"
    assert before == (gate.git(repo, "show-ref"), gate.git(repo, "status", "--porcelain"))
    assert (repo / gate.PATHS[1]).read_bytes() == b"untrusted worktree bytes"


@pytest.mark.parametrize("damage", ["tamper", "top_duplicate", "nested_duplicate", "scope", "counts", "csv_counts", "schema",
                                    "window", "stale", "future", "cross_date", "low", "extra", "delete", "rename", "mode", "symlink"])
def test_bad_package_never_accepts_or_changes_files_refs(candidate, damage):
    repo, base, receipt = candidate
    path = repo / gate.PATHS[2]
    if damage == "tamper":
        with (repo / gate.PATHS[1]).open("ab") as stream:
            stream.write(b"x")
    elif damage in {"top_duplicate", "nested_duplicate"}:
        key = "source" if damage == "top_duplicate" else "sha256"
        path.write_text(path.read_text().replace('"' + key + '":', '"' + key + '": "duplicate", "' + key + '":', 1))
    elif damage in {"scope", "counts", "window", "schema", "csv_counts"}:
        if damage == "scope":
            receipt["scope"][0] = "unexpected"
        elif damage == "counts":
            receipt["outputs"][Path(gate.PATHS[1]).name]["mentions_total"] += 1
        elif damage == "schema":
            receipt["outputs"][Path(gate.PATHS[1]).name]["rows"] = "1"
        elif damage == "csv_counts":
            data = b"tema,menciones\r\nPython,invalid\r\n"
            (repo / gate.PATHS[1]).write_bytes(data)
            receipt["outputs"][Path(gate.PATHS[1]).name]["sha256"] = hashlib.sha256(data).hexdigest()
        else:
            receipt["extraction_started_at_utc"] = "2026-10-06T13:00:00Z"
        path.write_text(json.dumps(receipt))
    elif damage in {"stale", "future", "cross_date", "low"}:
        finish = NOW + timedelta(days={"stale": -9, "future": 1, "cross_date": -1, "low": 0}[damage])
        write_package(repo, 764 if damage == "low" else 800, finish)
    elif damage == "extra":
        (repo / "unrelated.py").write_text("pass\n")
    elif damage == "delete":
        (repo / gate.PATHS[0]).unlink()
    elif damage == "rename":
        (repo / gate.PATHS[0]).rename(repo / "renamed.csv")
    head = save(repo)
    if damage in {"mode", "symlink"}:
        oid = gate.git(repo, "rev-parse", head + ":" + gate.PATHS[0]).decode().strip()
        gate.git(repo, "update-index", "--cacheinfo", "100755" if damage == "mode" else "120000", oid, gate.PATHS[0])
        gate.git(repo, "commit", "-qm", "test: prohibited mode")
        head = gate.git(repo, "rev-parse", "HEAD").decode().strip()
    before = (gate.git(repo, "show-ref"), gate.git(repo, "status", "--porcelain"), path.read_bytes())
    with pytest.raises(ValueError):
        gate.admit(repo, base, head, now=NOW)
    assert before == (gate.git(repo, "show-ref"), gate.git(repo, "status", "--porcelain"), path.read_bytes())


def test_code_only_skips_historical_package(candidate):
    repo, base, _ = candidate
    gate.git(repo, "restore", "--worktree", "--", *gate.PATHS)
    (repo / "code.py").write_text("pass\n")
    assert gate.admit(repo, base, save(repo), now=NOW)["eligibility"] == "not-applicable"


def test_floor_ceiling_and_verified_baseline(candidate):
    assert (301 * 85 + 99) // 100 == 256 and (300 * 85 + 99) // 100 == 255
    assert producer_minimum_mentions(301) == producer_minimum_mentions(300) == 400
    repo, base, _ = candidate
    write_package(repo, 765)
    assert gate.admit(repo, base, save(repo), now=NOW)["coverage"] == "pass"
    write_package(repo, 764)
    with pytest.raises(ValueError, match="coverage"):
        gate.admit(repo, base, save(repo), now=NOW)


@pytest.mark.parametrize("total", [399, 400])
def test_full_admission_preserves_absolute_floor(candidate, total):
    repo, _, _ = candidate
    write_package(repo, 300, NOW - timedelta(days=9))
    base = save(repo)
    write_package(repo, total)
    if total == 399:
        with pytest.raises(ValueError, match="coverage"):
            gate.admit(repo, base, save(repo), now=NOW)
    else:
        assert gate.admit(repo, base, save(repo), now=NOW)["minimum_mentions"] == 400


def test_event_binding_never_uses_merge_sha():
    event = {"number": 12, "repository": {"full_name": gate.REPOSITORY}, "pull_request": {
        "base": {"ref": "main", "sha": "a" * 40}, "head": {"sha": "b" * 40}}}
    assert gate.event_binding(event, gate.REPOSITORY) == ("a" * 40, "b" * 40, 12)
    event["pull_request"]["base"]["ref"] = "other"
    with pytest.raises(ValueError):
        gate.event_binding(event, gate.REPOSITORY)


@pytest.mark.parametrize("wrong_ref", [False, True])
def test_cli_real_fetch_binding_and_failed_gate_preserve_data(candidate, monkeypatch, tmp_path, wrong_ref):
    repo, base, _ = candidate
    (repo / gate.PATHS[1]).write_bytes(b"tampered committed CSV")
    head = save(repo)
    remote = tmp_path / "remote.git"
    gate.git(tmp_path, "init", "--bare", "-q", str(remote))
    gate.git(repo, "push", str(remote), (base if wrong_ref else head) + ":refs/pull/12/head")
    gate.git(repo, "remote", "add", "origin", "https://github.com/" + gate.REPOSITORY)
    gate.git(repo, "checkout", "--detach", base)
    event = {"number": 12, "repository": {"full_name": gate.REPOSITORY}, "pull_request": {
        "base": {"ref": "main", "sha": base}, "head": {"sha": head}}}
    path = tmp_path / "event.json"
    path.write_text(json.dumps(event))
    for key, value in {"GITHUB_EVENT_PATH": str(path), "GITHUB_REPOSITORY": gate.REPOSITORY,
                       "GITHUB_RUN_ID": "1", "GITHUB_RUN_ATTEMPT": "1", "GITHUB_TOKEN": "fixture-token"}.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(gate, "ROOT", repo)
    original = gate.git
    def service(root, *args):
        if args[0] == "fetch":
            return original(root, *args[:3], str(remote), *args[4:])
        return original(root, *args)
    monkeypatch.setattr(gate, "git", service)
    checks = []
    monkeypatch.setattr(gate, "publish_check", lambda *args: checks.append(args))
    before = (original(repo, "show-ref").decode().splitlines(), original(repo, "status", "--porcelain"), tuple((repo / p).read_bytes() for p in gate.PATHS))
    assert gate.main() == 1 and checks[0][:2] == (head, "failure")
    capture = "refs/ttap/admission/1-1"
    assert original(repo, "rev-parse", capture).decode().strip() == (base if wrong_ref else head)
    assert original(repo, "rev-parse", "HEAD").decode().strip() == base
    assert before[0] == [line for line in original(repo, "show-ref").decode().splitlines() if not line.endswith(" " + capture)]
    assert before[1:] == (original(repo, "status", "--porcelain"), tuple((repo / p).read_bytes() for p in gate.PATHS))


def test_check_publication_exact_head_and_api_failure(monkeypatch):
    seen = []
    def api(request, timeout):
        payload = json.loads(request.data)
        seen.append(payload)
        assert timeout == 30 and payload["head_sha"] == "b" * 40
        return io.BytesIO(json.dumps({"id": 1, "head_sha": payload["head_sha"], "conclusion": payload["conclusion"]}).encode())
    monkeypatch.setattr(gate, "urlopen", api)
    assert gate.publish_check("b" * 40, "failure", "Admission failed", "fixture-token") == 1
    assert seen[0]["conclusion"] == "failure"
    def unavailable(*args, **kwargs):
        raise OSError("fixture API unavailable")
    monkeypatch.setattr(gate, "urlopen", unavailable)
    with pytest.raises(OSError):
        gate.publish_check("b" * 40, "success", "validated", "fixture-token")


def test_workflow_is_trusted_and_narrow():
    workflow = (gate.ROOT / ".github/workflows/reddit_package_admission.yml").read_text()
    assert "pull_request_target:" in workflow and "checks: write" in workflow
    assert "ref:" not in workflow and 'if git(ROOT, "rev-parse", "HEAD").decode().strip() != base:' in (gate.ROOT / "scripts/check_reddit_package_admission.py").read_text()
    assert "persist-credentials: false" in workflow and "pip install" not in workflow
    assert "cache:" not in workflow and "secrets." not in workflow
    assert "--now" not in (gate.ROOT / "scripts/check_reddit_package_admission.py").read_text()
