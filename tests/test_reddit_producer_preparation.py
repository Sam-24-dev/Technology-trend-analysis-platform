"""Preparation acceptance uses temporary local Git and mocked guarded children only."""
import os
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

import pytest

from scripts import prepare_reddit_producer as prep

ROOT = Path(__file__).resolve().parents[1]
PS = shutil.which("powershell.exe") or shutil.which("pwsh")


@pytest.fixture(autouse=True)
def isolated_interpreter(monkeypatch):
    monkeypatch.setattr(prep.sys, "base_prefix", "fixture-only-base-prefix")


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def snapshot(root):
    return {"HEAD": git(root, "rev-parse", "HEAD"), "refs": git(root, "show-ref"),
            "symbolic": git(root, "symbolic-ref", "HEAD"), "status": git(root, "status", "--porcelain"),
            "index": hashlib.sha256((root / ".git/index").read_bytes()).hexdigest(),
            "FETCH_HEAD": ((root / ".git/FETCH_HEAD").read_bytes()
                           if (root / ".git/FETCH_HEAD").exists() else None),
            "files": {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in root.rglob("*") if p.is_file() and ".git" not in p.parts}}


@pytest.fixture
def producer(tmp_path, monkeypatch):
    repo, remote = tmp_path / "producer", tmp_path / "remote.git"
    repo.mkdir()
    git(repo, "init", "-q")
    subprocess.run(["git", "init", "--bare", "-q", str(remote)], check=True)
    for key, value in (("user.name", "Fixture"), ("user.email", "fixture@example.invalid"),
                       ("core.autocrlf", "true"), ("core.hooksPath", str(repo / ".git/hooks"))):
        git(repo, "config", key, value)
    for name in (*prep.CONTROLS, "backend/requirements.lock", "datos/reddit_temas_emergentes.csv"):
        path = repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("sample==1.0\n" if name.endswith(".lock") else "old\n", encoding="utf-8")
    (repo / ".gitignore").write_text("datos/latest/\ndatos/history/\ndatos/metadata/\n", encoding="utf-8")
    (repo / ".gitattributes").write_text(
        (ROOT / ".gitattributes").read_text(encoding="utf-8") + "*.ps1 text\n", encoding="utf-8")
    git(repo, "add", ".")
    git(repo, "commit", "-qm", "test: create baseline")
    git(repo, "branch", "-M", "main")
    baseline = git(repo, "rev-parse", "HEAD")
    (repo / "datos/reddit_temas_emergentes.csv").write_bytes(b"fresh\n")
    git(repo, "commit", "-qam", "test: refresh data")
    target = git(repo, "rev-parse", "HEAD")
    git(repo, "remote", "add", "origin", remote.as_posix())
    git(repo, "push", "-q", "origin", "main")
    git(repo, "reset", "--hard", baseline)
    monkeypatch.setattr(prep.metadata, "version", lambda name: "1.0")
    return repo, remote.as_posix(), baseline, target


@pytest.mark.parametrize("kind", ["equal", "behind", "crlf", "tracking_ref"])
def test_prepares_exact_main_and_fresh_baseline(producer, monkeypatch, kind):
    repo, origin, baseline, target = producer
    if kind == "equal":
        git(repo, "reset", "--hard", target)
    if kind == "crlf":
        (repo / prep.CONTROLS[0]).write_bytes(b"old\r\n")
        git(repo, "-c", "core.autocrlf=true", "add", "--", prep.CONTROLS[0])
    if kind == "tracking_ref":
        injected = []
        original = prep.git
        def command(root, *args):
            if args[0] == "rev-parse" and args[1].startswith("refs/ttap/preparation/"):
                git(repo, "update-ref", "refs/remotes/origin/main", baseline)
                injected.append(True)
            return original(root, *args)
        monkeypatch.setattr(prep, "git", command)
    assert prep.prepare(repo, origin) == target
    if kind == "tracking_ref":
        assert injected == [True] and git(repo, "rev-parse", "origin/main") == baseline
    assert git(repo, "rev-parse", "HEAD") == target
    assert not git(repo, "status", "--porcelain")
    assert (repo / "datos/reddit_temas_emergentes.csv").read_bytes() == b"fresh\n"


@pytest.mark.parametrize("kind", ["dirty", "untracked", "ignored", "ahead", "diverged", "index.lock", "MERGE_HEAD",
                                  "fetch", "advance", "intervening", "interrupt", "blob", "mode",
                                  "missing", "mismatch", "origin"])
def test_failures_preserve_main_files_and_report_stage(producer, monkeypatch, kind):
    repo, origin, baseline, target = producer
    if kind in {"blob", "mode"}:
        git(repo, "reset", "--hard", target)
        if kind == "blob":
            (repo / prep.CONTROLS[0]).write_text("changed\n", encoding="utf-8")
            git(repo, "add", prep.CONTROLS[0])
        else:
            git(repo, "update-index", "--chmod=+x", prep.CONTROLS[0])
        git(repo, "commit", "-qm", "test: change bootstrap")
        git(repo, "push", "-q", "origin", "main")
        git(repo, "reset", "--hard", baseline)
    if kind in {"ahead", "diverged"}:
        if kind == "ahead":
            git(repo, "reset", "--hard", target)
        (repo / "local.txt").write_text("local", encoding="utf-8")
        git(repo, "add", "local.txt")
        git(repo, "commit", "-qm", "test: create local commit")
    if kind == "dirty":
        (repo / "datos/reddit_temas_emergentes.csv").write_bytes(b"protected")
    if kind == "untracked":
        git(repo, "config", "status.showUntrackedFiles", "no")
        (repo / "protected.txt").write_bytes(b"protected")
    if kind == "ignored":
        path = repo / "datos/latest/protected.csv"
        path.parent.mkdir()
        path.write_bytes(b"protected")
    if kind in {"index.lock", "MERGE_HEAD"}:
        (repo / ".git" / kind).write_bytes(b"preserve operation")
    if kind == "origin":
        origin += "-unexpected"
    if kind in {"missing", "mismatch"}:
        def version(name):
            if kind == "missing":
                raise prep.metadata.PackageNotFoundError(name)
            return "0.9"
        monkeypatch.setattr(prep.metadata, "version", version)
    original, steps = prep.git, []
    def command(root, *args):
        steps.append(args[0])
        if args[0] == kind or (kind == "advance" and args[0] == "merge"):
            raise RuntimeError("injected command failure")
        if kind == "interrupt" and args[0] == "show":
            raise KeyboardInterrupt
        if kind == "intervening" and args[0] == "show":
            git(repo, "reset", "--hard", target)
        return original(root, *args)
    monkeypatch.setattr(prep, "git", command)
    before_head = git(repo, "rev-parse", "HEAD")
    before = {p: p.read_bytes() for p in repo.rglob("*") if p.is_file() and ".git" not in p.parts}
    with pytest.raises(RuntimeError, match="Preparation failed at") as failure:
        prep.prepare(repo, origin)
    preflight = {"dirty", "untracked", "ignored", "index.lock", "MERGE_HEAD", "origin"}
    stage = "admission"
    if kind in preflight:
        stage = "preflight"
    elif kind == "fetch":
        stage = "fetch"
    elif kind in {"advance", "intervening"}:
        stage = "advance"
    elif kind in {"missing", "mismatch", "interrupt"}:
        stage = "dependencies"
    assert f"Preparation failed at {stage};" in str(failure.value)
    assert steps.count("fetch") == (0 if kind in preflight else 1)
    assert git(repo, "rev-parse", "HEAD") == (target if kind == "intervening" else before_head)
    if kind != "intervening":
        assert before == {p: p.read_bytes() for p in repo.rglob("*") if p.is_file() and ".git" not in p.parts}
    assert "merge" not in steps or kind == "advance"
    if kind in {"index.lock", "MERGE_HEAD"}:
        assert (repo / ".git" / kind).read_bytes() == b"preserve operation"
    assert not (repo / "publication.txt").exists()


@pytest.mark.parametrize("lock", ["", "sample>=1.0", "sample==1.0; python_version>='3'",
                                  "--index-url https://example.invalid", "sample==1.0\nsample==1.0"])
def test_unsupported_locks_fail_closed(lock, monkeypatch):
    monkeypatch.setattr(prep.metadata, "version", lambda name: "1.0")
    with pytest.raises(RuntimeError):
        prep.dependencies(lock)


def test_all_current_pins_and_isolated_python_are_checked(monkeypatch):
    lock = (ROOT / "backend/requirements.lock").read_text(encoding="utf-8")
    from importlib.metadata import version
    checked = []
    monkeypatch.setattr(prep.metadata, "version", lambda name: (checked.append(name), version(name))[1])
    prep.dependencies(lock)
    assert len(checked) == 29
    isolated = prep.sys.prefix
    monkeypatch.setattr(prep.sys, "prefix", prep.sys.base_prefix)
    with pytest.raises(RuntimeError, match="isolated Python"):
        prep.dependencies(lock)
    monkeypatch.setattr(prep.sys, "prefix", isolated)
    monkeypatch.setattr(prep.sys, "version_info", (3, 12))
    with pytest.raises(RuntimeError, match="isolated Python"):
        prep.dependencies(lock)


@pytest.mark.skipif(PS is None, reason="PowerShell required")
@pytest.mark.parametrize("kind", ["missing", "invalid", "drift", "branch"])
def test_child_rejects_unprepared_revision_before_baseline(producer, kind):
    repo, origin, baseline, target = producer
    runner = (ROOT / "automation/run_reddit_baseline.ps1").read_text(encoding="utf-8")
    assertion = runner[runner.index("function Assert-PreparedMainSha"):runner.index("function Get-TopicMentions")]
    expected = "" if kind == "missing" else "invalid" if kind == "invalid" else target if kind == "drift" else baseline
    if kind == "branch":
        git(repo, "checkout", "-qb", "other")
    code = 'Import-Module "' + str(ROOT / "automation/reddit_output_transaction.psm1") + '" -Force\n' + assertion
    code += '\nSet-Location -LiteralPath "' + str(repo) + '"\n$PreparedMainSha="' + expected + '"\n'
    result = subprocess.run([PS, "-NoProfile", "-NonInteractive", "-Command",
        '$ErrorActionPreference="Stop"\n' + code + 'Assert-PreparedMainSha\nWrite-Output "BASELINE_REACHED=1"'],
        capture_output=True, text=True, timeout=15)
    assert result.returncode != 0 and "BASELINE_REACHED=1" not in result.stdout
    assert git(repo, "rev-parse", "HEAD") == baseline


@pytest.mark.skipif(os.name != "nt" or PS is None, reason="Windows PowerShell runtime required")
@pytest.mark.parametrize("kind", ["failure", "dependency", "missing_python", "stderr", "interruption", "child",
                                  "selectors", "child_selectors"])
def test_guard_holds_mutex_and_preparation_failure_cannot_mark_success(tmp_path, kind):
    automation = tmp_path / "automation"
    automation.mkdir()
    shutil.copyfile(ROOT / "automation/reddit_output_transaction.psm1", automation / "reddit_output_transaction.psm1")
    marker = automation / "state/reddit_baseline_last_window.txt"
    marker.parent.mkdir()
    marker.write_bytes(b"2026-10-04")
    name = "Global\\TTAP-preparation-" + uuid.uuid4().hex
    guard = (ROOT / "automation/run_reddit_baseline_guarded.ps1").read_text(encoding="utf-8")
    guard = guard.replace("Global\\TechnologyTrend-RedditBaselineWeekly", name).replace(
        "$utcNow = (Get-Date).ToUniversalTime()",
        "$utcNow = [datetime]::Parse('2026-10-12T02:00:00Z').ToUniversalTime()")
    guard = guard.replace("  $popupFlags = @{", "  return\n  $popupFlags = @{")
    if kind != "missing_python":
        guard = guard.replace('& $py -I -B (Join-Path $repo "scripts\\prepare_reddit_producer.py") --root $repo',
                              '& powershell.exe -NoProfile -File (Join-Path $repo "preparation.ps1")')
    if kind == "dependency":
        probe_python = tmp_path / "dependency.py"
        probe_python.write_text("import runpy\nm = runpy.run_path(" +
            repr(str(ROOT / "scripts/prepare_reddit_producer.py")) +
            ")\ntry: m['dependencies']('ttap-fixture-not-installed==1.0')\n"
            "except RuntimeError as exc: print(exc); raise SystemExit(1)\n", encoding="utf-8")
        guard = guard.replace('& powershell.exe -NoProfile -File (Join-Path $repo "preparation.ps1")',
                              '& "' + sys.executable + '" -I -B "' + str(probe_python) + '"')
    probe = '$m=[Threading.Mutex]::new($false,"' + name + '");if($m.WaitOne(0)){throw "mutex not held"};$m.Dispose();'
    (tmp_path / "preparation.ps1").write_text(probe + ("exit 7" if kind == "failure" else
        '[Console]::Error.WriteLine("fixture native stderr");exit 7' if kind == "stderr" else
        'Write-Output "' + "a" * 40 + '"'), encoding="utf-8")
    child = automation / "run_reddit_baseline.ps1"
    child.write_text('param([string]$PreparedMainSha)\n' + probe +
        'if($PreparedMainSha -ne "' + "a" * 40 + '"){throw "wrong SHA"};Write-Output "CHILD_COMPLETED=1"',
        encoding="utf-8")
    if kind == "interruption":
        guard = guard.replace('$preparedSha = [string]$preparation[0]', 'throw "fixture interruption"')
    if kind == "child_selectors":
        guard = guard.replace('$preparedSha = [string]$preparation[0]',
            '$preparedSha = [string]$preparation[0]\n$env:GIT_DIR="' + str(tmp_path / "B/.git") + '"')
    path = automation / "run_reddit_baseline_guarded.ps1"
    path.write_text(guard, encoding="utf-8")
    env = dict(os.environ)
    if kind == "selectors":
        env["GIT_DIR"] = str(tmp_path / "B/.git")
    result = subprocess.run([PS, "-NoProfile", "-NonInteractive", "-File", str(path)],
                            env=env, capture_output=True, text=True, timeout=30)
    assert (result.returncode == 0) is (kind == "child"), result.stderr
    assert marker.read_text(encoding="ascii").strip() == ("2026-10-11" if kind == "child" else "2026-10-04")
    assert ("CHILD_COMPLETED=1" in result.stdout) is (kind == "child")
    if kind in {"failure", "dependency", "missing_python", "stderr", "selectors"}:
        status = tmp_path / "automation/state/reddit_baseline_last_status.txt"
        assert "outcome=preparation_failed" in status.read_text(encoding="utf-8-sig")
    release = subprocess.run([PS, "-NoProfile", "-NonInteractive", "-Command",
        '$m=[Threading.Mutex]::new($false,"' + name + '");if(-not $m.WaitOne(0)){exit 1};$m.ReleaseMutex();$m.Dispose()'],
        check=False)
    assert release.returncode == 0


def test_revision_assertions_precede_baseline_and_publication():
    runner = (ROOT / "automation/run_reddit_baseline.ps1").read_text(encoding="utf-8")
    runtime = runner.split("Set-Location $repo", 1)[1]
    assert runtime.index("Assert-PreparedMainSha") < runtime.index("$baselineMentions =")
    publication = runner.split("function Invoke-SourcePublication", 1)[1].split("Set-Location $repo", 1)[0]
    assert publication.index("Assert-PreparedMainSha") < publication.index('Run-Step "git checkout branch"')


@pytest.mark.parametrize("selector", ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR",
                                     "GIT_OBJECT_DIRECTORY", "GIT_CONFIG_COUNT", "combined"])
def test_selector_child_cannot_inspect_or_mutate_other_repository(producer, selector):
    repo, origin, baseline, target = producer
    other = repo.parent / "B"
    subprocess.run(["git", "clone", "-q", origin, str(other)], check=True, capture_output=True)
    git(other, "checkout", "-qB", "main", baseline)
    git(other, "remote", "set-url", "origin", origin)
    before, other_before = snapshot(repo), snapshot(other)
    values = {"GIT_DIR": other / ".git", "GIT_WORK_TREE": other, "GIT_INDEX_FILE": other / ".git/index",
              "GIT_COMMON_DIR": other / ".git", "GIT_OBJECT_DIRECTORY": other / ".git/objects"}
    env = dict(os.environ, **({selector: str(values.get(selector, 1))} if selector != "combined" else {}))
    if selector == "combined":
        env.update(GIT_DIR=str(other / ".git"), GIT_WORK_TREE=str(other), GIT_INDEX_FILE=str(other / ".git/index"))
    if selector == "GIT_CONFIG_COUNT":
        env.update(GIT_CONFIG_KEY_0="core.worktree", GIT_CONFIG_VALUE_0=str(other))
    code = "import runpy,sys\nm=runpy.run_path(sys.argv[1])\nm['metadata'].version=lambda name:'1.0'\n"
    code += "try: m['prepare'](sys.argv[2],sys.argv[3])\n"
    code += "except RuntimeError as exc: print(exc); raise SystemExit(1)\n"
    result = subprocess.run([sys.executable, "-I", "-B", "-c", code,
        str(ROOT / "scripts/prepare_reddit_producer.py"), str(repo), origin], env=env,
        capture_output=True, text=True, timeout=20)
    assert result.returncode == 1 and "Preparation failed at preflight;" in result.stdout
    expected_name = "GIT_DIR" if selector == "combined" else selector
    assert "Rejected Git environment:" in result.stdout and expected_name in result.stdout
    assert str(other) not in result.stdout + result.stderr
    assert snapshot(repo) == before and snapshot(other) == other_before
    assert prep.prepare(repo, origin) == target
    assert snapshot(other) == other_before


def test_real_other_branch_fetch_cannot_replace_frozen_main(producer, monkeypatch):
    repo, origin, baseline, target = producer
    git(repo, "checkout", "-qb", "other", target)
    (repo / "datos/reddit_temas_emergentes.csv").write_bytes(b"other\n")
    git(repo, "commit", "-qam", "test: create other data branch")
    other = git(repo, "rev-parse", "HEAD")
    git(repo, "push", "-q", "origin", "other")
    git(repo, "checkout", "-q", "main")
    git(repo, "update-ref", "refs/ttap/preparation/existing", baseline)
    before, original, injected = snapshot(repo), prep.git, []
    def command(root, *args):
        if args[0] == "rev-parse" and args[1].startswith("refs/ttap/preparation/"):
            original(root, "fetch", "--no-tags", "--no-recurse-submodules", "origin", "refs/heads/other")
            injected.append(True)
        return original(root, *args)
    monkeypatch.setattr(prep, "git", command)
    assert prep.prepare(repo, origin) == target and injected == [True]
    assert git(repo, "rev-parse", "refs/remotes/origin/main") == target
    assert git(repo, "rev-parse", "FETCH_HEAD^{commit}") == other
    after = snapshot(repo)
    assert after["HEAD"] == target and after["symbolic"] == before["symbolic"] and not after["status"]
    assert after["refs"] == before["refs"].replace(baseline + " refs/heads/main", target + " refs/heads/main")
    expected = dict(before["files"], **{"datos/reddit_temas_emergentes.csv": hashlib.sha256(b"fresh\n").hexdigest()})
    assert after["files"] == expected


@pytest.mark.skipif(PS is None, reason="PowerShell required")
@pytest.mark.parametrize("actor", ["Assert-CleanWorktree", "Assert-PreparedMainSha"])
def test_actual_child_assertions_reject_repository_selectors(producer, actor):
    repo, origin, baseline, target = producer
    other = repo.parent / "B"
    subprocess.run(["git", "clone", "-q", origin, str(other)], check=True, capture_output=True)
    git(other, "checkout", "-qB", "main", target)
    git(other, "remote", "set-url", "origin", origin)
    before, other_before = snapshot(repo), snapshot(other)
    runner = (ROOT / "automation/run_reddit_baseline.ps1").read_text(encoding="utf-8")
    checks = runner[runner.index("function Assert-CleanWorktree"):runner.index("function Get-TopicMentions")]
    code = '$ErrorActionPreference="Stop"\nImport-Module "' + str(ROOT / "automation/reddit_output_transaction.psm1")
    code += '" -Force\n' + checks + '\nSet-Location "' + str(repo) + '"\n$PreparedMainSha="' + target + '"\n'
    env = dict(os.environ, GIT_DIR=str(other / ".git"), GIT_WORK_TREE=str(other),
               GIT_INDEX_FILE=str(other / ".git/index"))
    result = subprocess.run([PS, "-NoProfile", "-NonInteractive", "-Command", code + actor +
        '\nWrite-Output "ACTOR_REACHED=1"'], env=env, capture_output=True, text=True, timeout=20)
    assert result.returncode != 0 and "Rejected Git environment:" in result.stderr
    assert "ACTOR_REACHED=1" not in result.stdout and str(other) not in result.stderr
    assert snapshot(repo) == before and snapshot(other) == other_before
