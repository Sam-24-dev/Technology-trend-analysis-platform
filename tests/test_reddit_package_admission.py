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


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_local_exact_index_and_commit_without_ci(candidate, monkeypatch, newline, capsys):
    repo, base, receipt = candidate
    (repo / gate.PATHS[2]).write_bytes((json.dumps(receipt) + newline).encode())
    original_receipt = gate.receipt_identity((repo / gate.PATHS[2]).read_bytes())
    gate.git(repo, "add", "--all")
    staged = gate.admit_local(repo, base, expected_receipt=original_receipt, now=NOW)
    original = gate.git
    def local_git(root, *args):
        assert args[0] not in {"fetch", "push", "remote"}
        return original(root, *args)
    monkeypatch.setattr(gate, "git", local_git)
    monkeypatch.setattr(gate, "publish_check", lambda *args: pytest.fail("Local check publication"))
    assert original(repo, "rev-parse", base + ":" + gate.PATHS[0]) == original(repo, "rev-parse", ":" + gate.PATHS[0])
    head = save(repo)
    assert gate.admit_local(repo, base, head=head, expected_index=staged["index_fingerprint"], expected_receipt=original_receipt, now=NOW) == staged
    finish = datetime.now(timezone.utc).replace(microsecond=0)
    write_package(repo, finish=finish)
    original_receipt = gate.receipt_identity((repo / gate.PATHS[2]).read_bytes())
    gate.git(repo, "add", "--all")
    valid_index = gate.admit_local(repo, head, expected_receipt=original_receipt, now=finish)
    head = save(repo)
    expected = valid_index["index_fingerprint"]
    assert gate.fingerprint(gate.manifest(repo, head)) == expected
    assert gate.admit(repo, base, head, now=finish)["eligibility"] == "pass"
    assert gate.receipt_identity(gate.git(repo, "cat-file", "blob", head + ":" + gate.PATHS[2])) == original_receipt
    assert gate.local_main(["--root", str(repo), "--base", base, "--head", head,
                           "--expected-index", expected, "--expected-receipt", original_receipt]) == 1
    assert capsys.readouterr().out.strip() == "Local admission failed: Committed package must have prepared main as its sole parent"


@pytest.mark.parametrize("damage", ["empty", "code", "extra", "delete", "rename", "mode", "symlink", "unmerged", "tamper", "duplicate"])
def test_local_bad_index_is_read_only(candidate, damage):
    repo, base, _ = candidate
    original_receipt = gate.receipt_identity((repo / gate.PATHS[2]).read_bytes())
    if damage in {"empty", "code"}:
        gate.git(repo, "restore", "--worktree", "--", *gate.PATHS)
    if damage in {"code", "extra"}:
        (repo / "unrelated.py").write_text("pass\n")
    if damage == "delete":
        (repo / gate.PATHS[0]).unlink()
    if damage == "rename":
        (repo / gate.PATHS[0]).rename(repo / "renamed.csv")
    if damage == "tamper":
        (repo / gate.PATHS[1]).write_bytes(b"altered")
    if damage == "duplicate":
        path = repo / gate.PATHS[2]
        path.write_text(path.read_text().replace('"source":', '"source":"duplicate","source":'))
    gate.git(repo, "add", "--all")
    oid = gate.git(repo, "rev-parse", base + ":" + gate.PATHS[0]).decode().strip()
    if damage in {"mode", "symlink"}:
        gate.git(repo, "update-index", "--cacheinfo", "100755" if damage == "mode" else "120000", oid, gate.PATHS[0])
    if damage == "unmerged":
        gate.git(repo, "update-index", "--force-remove", "--", gate.PATHS[0])
        gate.subprocess.run(["git", "-C", str(repo), "update-index", "--index-info"],
                            input=f"100644 {oid} 1\t{gate.PATHS[0]}\n".encode(), check=True)
    before = (gate.git(repo, "show-ref"), (repo / ".git/index").read_bytes())
    with pytest.raises(ValueError):
        gate.admit_local(repo, base, expected_receipt=original_receipt, now=NOW)
    assert before == (gate.git(repo, "show-ref"), (repo / ".git/index").read_bytes())


@pytest.mark.parametrize("baseline,total,finish", [(300, 399, NOW), (300, 400, NOW), (501, 425, NOW), (501, 426, NOW),
                                                  (501, 500, NOW + timedelta(seconds=1)), (501, 500, NOW - timedelta(days=1)),
                                                  (501, 500, NOW - timedelta(days=9))])
def test_local_utc_and_integer_ceiling(candidate, baseline, total, finish):
    repo, _, _ = candidate
    write_package(repo, baseline, NOW - timedelta(days=9))
    base = save(repo)
    write_package(repo, total, finish)
    original_receipt = gate.receipt_identity((repo / gate.PATHS[2]).read_bytes())
    gate.git(repo, "add", "--all")
    if total in {400, 426}:
        assert gate.admit_local(repo, base, expected_receipt=original_receipt, now=NOW)["minimum_mentions"] == total
    else:
        with pytest.raises(ValueError):
            gate.admit_local(repo, base, expected_receipt=original_receipt, now=NOW)


@pytest.mark.parametrize("committed", [False, True])
def test_local_valid_but_different_package_is_tampering(candidate, committed):
    repo, base, _ = candidate
    original_receipt = gate.receipt_identity((repo / gate.PATHS[2]).read_bytes())
    gate.git(repo, "add", "--all")
    admitted = gate.admit_local(repo, base, expected_receipt=original_receipt, now=NOW)["index_fingerprint"]
    head = save(repo) if not committed else None
    write_package(repo, 801)
    gate.git(repo, "add", "--all")
    head = save(repo) if committed else head
    with pytest.raises(ValueError, match="differs"):
        gate.admit_local(repo, base, head=head, expected_index=admitted, expected_receipt=original_receipt, now=NOW)


def test_local_cli_real_clock_never_calls_ci(candidate, monkeypatch, capsys):
    repo, base, _ = candidate
    finish = datetime.now(timezone.utc).replace(microsecond=0)
    write_package(repo, finish=finish)
    gate.git(repo, "add", "--all")
    monkeypatch.setattr(gate, "main", lambda: pytest.fail("CI entry"))
    monkeypatch.setattr(gate, "urlopen", lambda *args, **kwargs: pytest.fail("Network"))
    args = ["--root", str(repo), "--base", base]
    assert gate.local_main([*args, "--worktree"]) == 0
    original_receipt = json.loads(capsys.readouterr().out)["receipt_fingerprint"]
    assert gate.local_main([*args, "--index"]) == 1
    assert "initially validated source" in capsys.readouterr().out
    args += ["--expected-receipt", original_receipt]
    assert gate.local_main([*args, "--head", ""]) == 1
    assert "exact commit SHA" in capsys.readouterr().out
    assert gate.local_main([*args, "--index"]) == 0
    staged = json.loads(capsys.readouterr().out)
    head = save(repo)
    assert gate.local_main([*args, "--head", head, "--expected-index", staged["index_fingerprint"]]) == 0
    assert json.loads(capsys.readouterr().out) == staged


def test_local_coherent_staged_replacement_rejects_original_source(candidate):
    repo, base, _ = candidate
    original = gate.admit_worktree(repo, base, now=NOW)["receipt_fingerprint"]
    write_package(repo, 801)
    gate.git(repo, "add", "--all")
    with pytest.raises(ValueError, match="initially validated source"):
        gate.admit_local(repo, base, expected_receipt=original, now=NOW)


def test_floor_ceiling_and_verified_baseline(candidate):
    assert (301 * 85 + 99) // 100 == 256 and (300 * 85 + 99) // 100 == 255
    assert producer_minimum_mentions(301) == producer_minimum_mentions(300) == 400
    repo, base, _ = candidate
    write_package(repo, 765)
    assert gate.admit(repo, base, save(repo), now=NOW)["coverage"] == "pass"
    write_package(repo, 764)
    with pytest.raises(ValueError, match="coverage"):
        gate.admit(repo, base, save(repo), now=NOW)


@pytest.mark.parametrize("baseline,total,minimum", [(300, 399, 400), (300, 400, 400), (501, 425, 426), (501, 426, 426)])
def test_full_admission_preserves_absolute_floor(candidate, baseline, total, minimum):
    repo, _, _ = candidate
    write_package(repo, baseline, NOW - timedelta(days=9))
    base = save(repo)
    write_package(repo, total)
    head = save(repo)
    assert producer_minimum_mentions(baseline) == minimum
    if total < minimum:
        with pytest.raises(ValueError, match="^Package below producer coverage minimum$"):
            gate.admit(repo, base, head, now=NOW)
    else:
        result = gate.admit(repo, base, head, now=NOW)
        assert result["baseline_mentions"] == baseline and result["minimum_mentions"] == minimum
        assert result["mentions_total"] == total and result["coverage"] == "pass"


def test_event_binding_never_uses_merge_sha():
    event = {"number": 12, "repository": {"full_name": gate.REPOSITORY}, "pull_request": {
        "base": {"ref": "main", "sha": "a" * 40}, "head": {"sha": "b" * 40}}}
    assert gate.event_binding(event, gate.REPOSITORY) == ("a" * 40, "b" * 40, 12)
    event["pull_request"]["base"]["ref"] = "other"
    with pytest.raises(ValueError):
        gate.event_binding(event, gate.REPOSITORY)



def bind_cli_event(repo, base, head, monkeypatch, tmp_path, run_id="1"):
    event = {"number": 12, "repository": {"full_name": gate.REPOSITORY}, "pull_request": {
        "base": {"ref": "main", "sha": base}, "head": {"sha": head}}}
    path = tmp_path / "event.json"
    path.write_text(json.dumps(event))
    for key, value in {"GITHUB_EVENT_PATH": str(path), "GITHUB_REPOSITORY": gate.REPOSITORY,
                       "GITHUB_RUN_ID": run_id, "GITHUB_RUN_ATTEMPT": "1", "GITHUB_TOKEN": "fixture-token"}.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(gate, "ROOT", repo)


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
    bind_cli_event(repo, base, head, monkeypatch, tmp_path)
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


def test_cli_success_real_clock_fetch_and_exact_head_publication(candidate, monkeypatch, tmp_path, capsys):
    import os
    import shutil
    import sys

    repo, base, _ = candidate
    remote = tmp_path / "remote.git"
    gate.git(tmp_path, "init", "--bare", "-q", str(remote))
    origin = "https://github.com/" + gate.REPOSITORY
    gate.git(repo, "remote", "add", "origin", origin)
    finish = datetime.now(timezone.utc).replace(microsecond=0)
    write_package(repo, finish=finish)
    head = save(repo)
    gate.git(repo, "push", str(remote), head + ":refs/pull/12/head")
    gate.git(repo, "checkout", "--detach", base)
    bind_cli_event(repo, base, head, monkeypatch, tmp_path, "success")
    monkeypatch.setenv("GIT_ALLOW_PROTOCOL", "file")
    real_git = shutil.which("git")
    assert real_git
    shim = tmp_path / "git.py"
    routing = "url." + remote.as_posix() + ".insteadOf=" + origin
    shim.write_text("import subprocess,sys\nargs=sys.argv[1:]\n"
                    "if 'fetch' in args: args=['-c'," + repr(routing) + ",*args]\n"
                    "sys.exit(subprocess.call([" + repr(real_git) + ",*args]))\n", encoding="utf-8")
    launcher = tmp_path / ("git.exe" if os.name == "nt" else "git")
    if os.name == "nt":
        source = tmp_path / "git.cs"
        source.write_text("""
using System;
using System.Diagnostics;
public class GitShim
{
    public static int Main()
    {
        string command = Environment.CommandLine;
        int end = command[0] == '"' ? command.IndexOf('"', 1) + 1 : command.IndexOf(' ');
        string arguments = command.Substring(end);
        if (arguments.Contains(" fetch "))
            arguments = "-c \\"" + ROUTING + "\\" " + arguments;
        var start = new ProcessStartInfo(NATIVE_GIT, arguments);
        start.UseShellExecute = false;
        using (var child = Process.Start(start))
        {
            child.WaitForExit();
            return child.ExitCode;
        }
    }
}
""".replace("ROUTING", json.dumps(routing)).replace("NATIVE_GIT", json.dumps(real_git)), encoding="utf-8")
        powershell = shutil.which("powershell.exe")
        assert powershell
        command = "Add-Type -Path $env:SHIM_SOURCE -OutputAssembly $env:SHIM_EXE -OutputType ConsoleApplication"
        gate.subprocess.run([powershell, "-NoProfile", "-NonInteractive", "-Command", command], check=True,
                            env=dict(os.environ, TEMP=str(tmp_path), TMP=str(tmp_path), SHIM_SOURCE=str(source), SHIM_EXE=str(launcher)))
    else:
        launcher.write_text("#!" + sys.executable + "\n" + shim.read_text(), encoding="utf-8")
        launcher.chmod(0o755)
    before = (gate.git(repo, "show-ref").decode().splitlines(), gate.git(repo, "rev-parse", "HEAD"),
              (repo / ".git/index").read_bytes(), tuple((repo / p).read_bytes() for p in gate.PATHS))
    trace = tmp_path / "git.trace"
    monkeypatch.setenv("GIT_TRACE", str(trace))
    monkeypatch.setenv("PATH", str(tmp_path) + os.pathsep + os.environ["PATH"])
    seen = []
    def api(request, timeout):
        payload = json.loads(request.data)
        seen.append(payload)
        assert request.full_url == "https://api.github.com/repos/" + gate.REPOSITORY + "/check-runs"
        assert request.method == "POST" and timeout == 30
        return io.BytesIO(json.dumps({"id": 1, "head_sha": payload["head_sha"],
                                     "conclusion": payload["conclusion"]}).encode())
    monkeypatch.setattr(gate, "urlopen", api)
    start = datetime.now(timezone.utc)
    assert gate.main() == 0
    end = datetime.now(timezone.utc)
    summary = json.loads(capsys.readouterr().out.strip())
    assert summary["baseline_sha"] == base and summary["aggregate_date_utc"] == finish.date().isoformat()
    assert finish <= start <= end and start.date() == end.date() == finish.date()
    assert summary["identity"] == summary["coverage"] == summary["freshness"] == summary["eligibility"] == "pass"
    assert len(seen) == 1 and seen[0]["head_sha"] == head and seen[0]["conclusion"] == "success"
    assert json.loads(seen[0]["output"]["summary"]) == summary
    capture = "refs/ttap/admission/success-1"
    assert gate.git(repo, "rev-parse", capture).decode().strip() == head
    assert before[0] == [line for line in gate.git(repo, "show-ref").decode().splitlines() if not line.endswith(" " + capture)]
    assert before[1:] == (gate.git(repo, "rev-parse", "HEAD"), (repo / ".git/index").read_bytes(),
                           tuple((repo / p).read_bytes() for p in gate.PATHS))
    commands = trace.read_text()
    assert "fetch --no-tags --no-recurse-submodules origin refs/pull/12/head:" + capture in commands
    assert str(remote).replace("\\", "/") in commands.replace("\\", "/") and "checkout" not in commands
