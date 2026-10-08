"""Fixture-only checks for the local Reddit source package."""

import hashlib
import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

import pytest
from requests.exceptions import RequestException

from reddit_etl import RedditETL, write_source_package_receipt
from exceptions import ETLExtractionError
from reddit_source_package import REDDIT_SCOPE

RUNNER = Path(__file__).resolve().parent.parent / "automation" / "run_reddit_baseline.ps1"
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell.exe")


def _csvs(root: Path):
    data = root / "datos"
    data.mkdir()
    (data / "reddit_sentimiento_frameworks.csv").write_bytes(
        b"framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\nPython,2,1,1,0,50,50,0\n"
    )
    (data / "reddit_temas_emergentes.csv").write_bytes(b"tema,menciones\nPython,2\n")


def test_receipt_binds_exact_aggregates_and_extractor_utc_window(tmp_path):
    _csvs(tmp_path)
    start = datetime(2026, 9, 28, 2, 0, tzinfo=timezone.utc)
    end = datetime(2026, 9, 28, 2, 5, tzinfo=timezone.utc)
    receipt = write_source_package_receipt(
        tmp_path, start, end, datetime(2026, 9, 28, tzinfo=timezone.utc),
        ["webdev", "Python"], 2,
    )
    payload = json.loads(receipt.read_text(encoding="utf-8"))
    assert payload["extraction_started_at_utc"] == "2026-09-28T02:00:00Z"
    assert payload["extraction_finished_at_utc"] == "2026-09-28T02:05:00Z"
    assert payload["reference_date_utc"] == "2026-09-28"
    assert payload["source_date_utc"] == "2026-09-28"
    assert payload["scope"] == ["webdev", "Python"]
    assert payload["posts_count"] == 2
    assert payload["outputs"]["reddit_temas_emergentes.csv"]["mentions_total"] == 2
    assert payload["outputs"]["reddit_sentimiento_frameworks.csv"]["sha256"] == hashlib.sha256(
        (tmp_path / "datos" / "reddit_sentimiento_frameworks.csv").read_bytes()
    ).hexdigest()


@pytest.mark.parametrize("invalid", ["missing", "malformed", "malformed_sentiment", "midnight"])
def test_receipt_rejects_bad_outputs_or_utc_date_disagreement(tmp_path, invalid):
    _csvs(tmp_path)
    if invalid == "missing":
        (tmp_path / "datos" / "reddit_temas_emergentes.csv").unlink()
    elif invalid == "malformed":
        (tmp_path / "datos" / "reddit_temas_emergentes.csv").write_bytes(b"tema,menciones\nPython,nope\n")
    elif invalid == "malformed_sentiment":
        (tmp_path / "datos" / "reddit_sentimiento_frameworks.csv").write_bytes(
            b"framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\nPython,2,bad,1,0,50,50,0\n"
        )
    end = datetime(2026, 9, 29 if invalid == "midnight" else 28, 2, tzinfo=timezone.utc)
    with pytest.raises(ValueError):
        write_source_package_receipt(
            tmp_path, datetime(2026, 9, 28, 2, tzinfo=timezone.utc), end,
            datetime(2026, 9, 28, tzinfo=timezone.utc), ["webdev"], 2,
        )
    assert not (tmp_path / "datos" / "source_packages" / "reddit" / "receipt.json").exists()


def test_strict_extraction_rejects_partial_target_without_raw_receipt(tmp_path):
    etl = RedditETL()
    with (
        patch("reddit_etl._split_subreddit_targets", return_value=["webdev", "Python"]),
        patch.object(etl, "_extraer_posts_json", side_effect=[[{"post_id": "one"}], []]),
        patch.object(etl, "_extraer_posts_rss", return_value=[]),
        patch("reddit_etl.time.sleep"),
    ):
        with pytest.raises(ETLExtractionError):
            etl.extraer_posts(limit=2, strict=True)
    assert etl.extraction_started_at_utc is not None
    assert etl.extraction_finished_at_utc is None


def test_strict_extraction_rejects_unvisited_configured_target():
    etl = RedditETL()
    with (
        patch("reddit_etl._split_subreddit_targets", return_value=["webdev", "Python"]),
        patch.object(etl, "_extraer_posts_json", return_value=[{"post_id": "one"}]),
        patch("reddit_etl.time.sleep"),
    ):
        with pytest.raises(ETLExtractionError):
            etl.extraer_posts(limit=1, strict=True)


def test_strict_json_rejects_page_failure_after_posts():
    etl = RedditETL()

    class Response:
        status_code = 200

        def json(self):
            return {"data": {"children": [{"data": {"is_self": True, "id": "one"}}], "after": "next"}}

    with (
        patch("reddit_etl.requests.get", side_effect=[Response(), RequestException("network")]),
        patch("reddit_etl.time.sleep"),
    ):
        etl._strict_source_package = True
        with pytest.raises(ETLExtractionError):
            etl._extraer_posts_json("webdev", 2)


def test_strict_json_rejects_page_failure_after_non_self_page():
    etl = RedditETL()

    class Response:
        status_code = 200

        def json(self):
            return {"data": {"children": [{"data": {"is_self": False, "id": "link"}}], "after": "next"}}

    with (
        patch("reddit_etl.requests.get", side_effect=[Response(), RequestException("network")]),
        patch("reddit_etl.time.sleep"),
    ):
        etl._strict_source_package = True
        with pytest.raises(ETLExtractionError):
            etl._extraer_posts_json("webdev", 2)


def test_strict_rss_accepts_later_redundant_feed_after_first_feed_fails(monkeypatch):
    etl = RedditETL()
    etl._strict_source_package = True
    monkeypatch.setenv("REDDIT_RSS_MAX_ATTEMPTS", "2")
    monkeypatch.setenv("REDDIT_RSS_FEED_DELAY_SECONDS", "0")

    class Response:
        status_code = 200
        text = """<feed xmlns="http://www.w3.org/2005/Atom"><entry>
        <id>t3_one</id><title>Python and FastAPI</title>
        <published>2026-09-28T02:00:00Z</published></entry></feed>"""

    with (
        patch("reddit_etl.requests.get", side_effect=[
            RequestException("first attempt"), RequestException("second attempt"), Response(),
        ]) as request,
        patch("reddit_etl.time.sleep"),
    ):
        posts = etl._extraer_posts_rss("webdev", 1)

    assert [post["post_id"] for post in posts] == ["one"]
    assert request.call_count == 3


def test_strict_rss_target_with_no_usable_feed_fails_closed(monkeypatch):
    etl = RedditETL()
    monkeypatch.setenv("REDDIT_RSS_MAX_ATTEMPTS", "1")
    monkeypatch.setenv("REDDIT_RSS_FEED_DELAY_SECONDS", "0")

    class Failure:
        status_code = 503

    with (
        patch.object(etl, "_extraer_posts_json", return_value=[]),
        patch("reddit_etl.requests.get", return_value=Failure()),
        patch("reddit_etl.time.sleep"),
        pytest.raises(ETLExtractionError),
    ):
        etl.extraer_posts("webdev", limit=1, strict=True)


def test_sunday_runner_stages_only_source_package_after_coverage_and_validation():
    runner = RUNNER.read_text(encoding="utf-8")
    assert '"backend\\reddit_etl.py", "--source-package"' in runner
    assert '"datos/source_packages/reddit/receipt.json"' in runner
    assert '"datos/reddit_sentimiento_frameworks.csv"' in runner
    assert '"datos/reddit_temas_emergentes.csv"' in runner
    assert "0.85" in runner
    assert runner.index("Assert-RedditSourcePackage") < runner.index('Run-Step "git checkout branch"')
    assert "trend_score" not in runner
    assert "sync_assets" not in runner
    assert "frontend\\assets" not in runner
    assert "--max-source-age-hours" not in runner
    assert "logs\\etl_" not in runner


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
@pytest.mark.parametrize("mentions,passes", [(800, True), (700, False)])
def test_runner_receipt_and_85_percent_guard_on_fixture(tmp_path, mentions, passes):
    automation = tmp_path / "automation"
    automation.mkdir()
    shutil.copy2(RUNNER.parent / "reddit_output_transaction.psm1", automation)
    data = tmp_path / "datos"
    data.mkdir()
    (data / "reddit_sentimiento_frameworks.csv").write_text(
        "framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\nPython,1,1,0,0,100,0,0\n",
        encoding="utf-8",
    )
    (data / "reddit_temas_emergentes.csv").write_text(
        f"tema,menciones\nPython,{mentions}\n", encoding="utf-8"
    )
    date = "2026-09-28"
    for dataset, name in (
        ("reddit_sentimiento", "reddit_sentimiento_frameworks.csv"),
        ("reddit_temas", "reddit_temas_emergentes.csv"),
    ):
        for path in (
            data / "latest" / name,
            data / "history" / dataset / "year=2026" / "month=09" / "day=28" / name,
        ):
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(data / name, path)
    start = datetime(2026, 9, 28, 2, tzinfo=timezone.utc)
    write_source_package_receipt(tmp_path, start, start, start, [f"r{i}" for i in range(10)], 800)
    runner = RUNNER.read_text(encoding="utf-8")
    harness = automation / "guard_fixture.ps1"
    harness.write_text(
        runner[: runner.index("Set-Location $repo")]
        + f'\n$utcDate = "{date}"\n$parts = $utcDate.Split("-")\nAssert-RedditSourcePackage -BaselineMentions 900\n',
        encoding="utf-8",
    )
    result = subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-File", str(harness)],
        env=os.environ.copy(), capture_output=True, text=True, check=False,
    )
    assert (result.returncode == 0) is passes, result.stderr


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
@pytest.mark.parametrize("failing_step", ["git checkout branch", "git add target files", "git commit", "git push", "gh pr create", "git checkout main after PR", "restore"])
def test_late_publication_failure_restores_local_bytes_without_real_git(tmp_path, failing_step):
    automation = tmp_path / "automation"
    automation.mkdir()
    shutil.copy2(RUNNER.parent / "reddit_output_transaction.psm1", automation)
    tracked = tmp_path / "datos" / "reddit_temas_emergentes.csv"
    ignored = tmp_path / "datos" / "latest" / "reddit_temas_emergentes.csv"
    receipt = tmp_path / "datos" / "source_packages" / "reddit" / "receipt.json"
    tracked.parent.mkdir()
    ignored.parent.mkdir(parents=True)
    tracked.write_bytes(b"tracked-before\r\n")
    ignored.write_bytes(b"ignored-before\n")
    runner = RUNNER.read_text(encoding="utf-8")
    harness = automation / "late_failure_fixture.ps1"
    harness.write_text(
        runner[: runner.index("Set-Location $repo")]
        + r'''
$outputSnapshot = New-RedditOutputSnapshot -ProjectRoot $repo -RelativePaths @(
  "datos/reddit_temas_emergentes.csv",
  "datos/latest/reddit_temas_emergentes.csv",
  "datos/source_packages/reddit/receipt.json"
)
Set-Content -LiteralPath (Join-Path $repo "datos/reddit_temas_emergentes.csv") -Value "new" -NoNewline
Set-Content -LiteralPath (Join-Path $repo "datos/latest/reddit_temas_emergentes.csv") -Value "new" -NoNewline
$receipt = Join-Path $repo "datos/source_packages/reddit/receipt.json"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $receipt) | Out-Null
Set-Content -LiteralPath $receipt -Value "new" -NoNewline
if ("__FAILING_STEP__" -eq "restore") {
  Remove-Item -LiteralPath $outputSnapshot.Entries[0].Backup -Force
}
function Run-Step {
  param([string]$Label, [string[]]$Command)
  if ($Label -eq "__FAILING_STEP__" -or "__FAILING_STEP__" -eq "restore") { throw "fixture publication failure" }
}
function Assert-PreparedMainSha {}
function Assert-LocalRedditAdmission { return ('a' * 64) }
function gh {
  if ("__FAILING_STEP__" -eq "gh pr create") { throw "fixture publication failure" }
  $global:LASTEXITCODE = 0
  return "https://example.invalid/pr"
}
try { Invoke-SourcePublication -Snapshot $outputSnapshot }
finally { Remove-RedditOutputSnapshot -Snapshot $outputSnapshot }
'''.replace("__FAILING_STEP__", failing_step),
        encoding="utf-8",
    )
    result = subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-File", str(harness)],
        capture_output=True, text=True, check=False,
    )
    assert result.returncode != 0
    assert "fixture publication failure" in result.stderr
    assert "REDDIT_SOURCE_PUBLICATION_FAILED=1" in result.stdout
    assert "Git state was not rolled back" in result.stdout
    assert "REDDIT_SOURCE_PUBLICATION_FAILED_ROLLBACK" not in result.stdout
    if failing_step == "restore":
        assert "REDDIT_SOURCE_LOCAL_FILE_RESTORE_FAILED=1" in result.stdout
        assert "REDDIT_SOURCE_LOCAL_FILES_RESTORED=1" not in result.stdout
        assert tracked.read_bytes() == b"new"
        assert ignored.read_bytes() == b"new"
        assert receipt.read_bytes() == b"new"
    else:
        assert "REDDIT_SOURCE_LOCAL_FILES_RESTORED=1" in result.stdout
        assert "REDDIT_SOURCE_LOCAL_FILE_RESTORE_FAILED=1" not in result.stdout
        assert tracked.read_bytes() == b"tracked-before\r\n"
        assert ignored.read_bytes() == b"ignored-before\n"
        assert not receipt.exists()


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
@pytest.mark.parametrize("failure", ["add", "commit", "push", "pr", "index", "coherent", "hook", "hook_index", "hook_package", "success"])
def test_real_local_git_publication_failure_stops_next_run(tmp_path, failure):
    repo = tmp_path / "producer"
    remote = tmp_path / "remote.git"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(["git", "init", "--bare", "-q", str(remote)], check=True)

    def git(*args, check=True):
        return subprocess.run(
            ["git", "-C", str(repo), *args], capture_output=True, text=True, check=check,
        )

    git("config", "user.name", "Fixture")
    git("config", "user.email", "fixture@example.invalid")
    git("config", "core.autocrlf", "false")
    git("config", "core.hooksPath", str(repo / ".git" / "hooks"))
    git("remote", "add", "origin", str(remote))
    (repo / ".gitignore").write_text("datos/latest/\nautomation/\n", encoding="utf-8")
    shutil.copy2(RUNNER.parent.parent / ".gitattributes", repo)
    data = repo / "datos"
    data.mkdir()
    sentiment = data / "reddit_sentimiento_frameworks.csv"
    topics = data / "reddit_temas_emergentes.csv"
    receipt = data / "source_packages" / "reddit" / "receipt.json"
    ignored = data / "latest" / "reddit_temas_emergentes.csv"
    sentiment.write_bytes(b"framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\r\nPython,2,1,1,0,50,50,0\r\n")
    sentiment_before = sentiment.read_bytes()
    topics.write_bytes(b"tema,menciones\nPython,900\n")
    git("add", ".gitignore", ".gitattributes", "datos/reddit_sentimiento_frameworks.csv", "datos/reddit_temas_emergentes.csv")
    git("commit", "-qm", "fixture baseline")
    git("branch", "-M", "main")
    baseline = git("rev-parse", "HEAD").stdout.strip()
    automation = repo / "automation"
    automation.mkdir()
    shutil.copy2(RUNNER.parent / "reddit_output_transaction.psm1", automation)
    package = tmp_path / "package"
    package.mkdir()
    _csvs(package)
    (package / "datos/reddit_sentimiento_frameworks.csv").write_bytes(sentiment_before)
    (package / "datos/reddit_temas_emergentes.csv").write_bytes(b"tema,menciones\r\nPython,800\r\n")
    finish = datetime.now(timezone.utc).replace(microsecond=0)
    write_source_package_receipt(package, finish, finish, finish, list(REDDIT_SCOPE), 800)
    replacement = tmp_path / "replacement"
    shutil.copytree(package, replacement)
    (replacement / "datos/reddit_temas_emergentes.csv").write_bytes(b"tema,menciones\r\nPython,801\r\n")
    write_source_package_receipt(replacement, finish, finish, finish, list(REDDIT_SCOPE), 801)
    hooks = repo / ".git" / "hooks"
    if failure in {"commit", "push"}:
        hook = hooks / f"pre-{failure}"
        hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        os.chmod(hook, 0o700)
    if failure in {"hook", "hook_index"}:
        hook = hooks / ("pre-commit" if failure == "hook" else "post-commit")
        hook.write_text('#!/bin/sh\nprintf "extra" > extra.txt\ngit add extra.txt\n', encoding="utf-8")
        os.chmod(hook, 0o700)
    if failure == "hook_package":
        alternate = package / "alternate.json"
        payload = json.loads((package / "datos/source_packages/reddit/receipt.json").read_bytes())
        payload["posts_count"] += 1
        alternate.write_text(json.dumps(payload))
        hook = hooks / "pre-commit"
        hook.write_text("#!/bin/sh\ncp '" + alternate.as_posix() + "' datos/source_packages/reddit/receipt.json\ngit add datos/source_packages/reddit/receipt.json\n")
        os.chmod(hook, 0o700)

    runner = RUNNER.read_text(encoding="utf-8")
    preamble = runner[: runner.index("Set-Location $repo")].replace(
        '(Join-Path $repo "scripts/check_reddit_package_admission.py")',
        '"' + str(RUNNER.parent.parent / "scripts/check_reddit_package_admission.py") + '"')
    harness = automation / "publication_fixture.ps1"
    harness.write_text(
        preamble
        + r'''
$branch = "reddit-source-fixture"
$outputSnapshot = New-RedditOutputSnapshot -ProjectRoot $repo -RelativePaths @(
  "datos/reddit_sentimiento_frameworks.csv",
  "datos/reddit_temas_emergentes.csv",
  "datos/source_packages/reddit/receipt.json",
  "datos/latest/reddit_temas_emergentes.csv"
)
Copy-Item -LiteralPath "__PACKAGE__/datos/reddit_sentimiento_frameworks.csv" -Destination (Join-Path $repo "datos/reddit_sentimiento_frameworks.csv")
Copy-Item -LiteralPath "__PACKAGE__/datos/reddit_temas_emergentes.csv" -Destination (Join-Path $repo "datos/reddit_temas_emergentes.csv")
$latest = Join-Path $repo "datos/latest/reddit_temas_emergentes.csv"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $latest) | Out-Null
Set-Content -LiteralPath $latest -Value "ignored-new" -NoNewline
if ("__FAILURE__" -ne "add") {
  $receipt = Join-Path $repo "datos/source_packages/reddit/receipt.json"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $receipt) | Out-Null
  Copy-Item -LiteralPath "__PACKAGE__/datos/source_packages/reddit/receipt.json" -Destination $receipt
}
if ("__FAILURE__" -eq "index") {
  Set-Content -LiteralPath (Join-Path $repo "extra.txt") -Value "extra"
  git add extra.txt
}
function gh {
  if ("__FAILURE__" -eq "pr") { throw "fixture PR failure" }
  $global:LASTEXITCODE = 0
  return "https://example.invalid/pr"
}
Set-Location $repo
$PreparedMainSha = (git rev-parse HEAD).Trim()
$py = "__PYTHON__"
if ("__FAILURE__" -eq "add") { $sourceReceipt = ('a' * 64) }
else { $sourceReceipt = Assert-LocalRedditAdmission -Worktree }
if ("__FAILURE__" -eq "coherent") {
  Copy-Item -LiteralPath "__REPLACEMENT__/datos/reddit_temas_emergentes.csv" -Destination (Join-Path $repo "datos/reddit_temas_emergentes.csv")
  Copy-Item -LiteralPath "__REPLACEMENT__/datos/source_packages/reddit/receipt.json" -Destination (Join-Path $repo "datos/source_packages/reddit/receipt.json")
}
Invoke-SourcePublication -Snapshot $outputSnapshot -ExpectedReceipt $sourceReceipt
'''.replace("__FAILURE__", failure).replace("__PACKAGE__", package.as_posix())
        .replace("__PYTHON__", os.sys.executable).replace("__REPLACEMENT__", replacement.as_posix()),
        encoding="utf-8",
    )
    result = subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-File", str(harness)],
        cwd=repo, capture_output=True, text=True, check=False,
    )
    if failure == "success":
        assert result.returncode == 0, result.stdout + result.stderr
        assert git("branch", "--show-current").stdout.strip() == "main"
        assert subprocess.run(["git", "--git-dir", str(remote), "show-ref", "--verify", "--quiet", "refs/heads/reddit-source-fixture"]).returncode == 0
        return
    assert result.returncode != 0, result.stdout + result.stderr
    reached_steps = [line[4:] for line in result.stdout.splitlines() if line.startswith("==> ")]
    expected_steps = ["git checkout branch", "git add target files"]
    if failure not in {"add", "index", "coherent"}:
        expected_steps.append("git commit")
    if failure in {"push", "pr"}:
        expected_steps.append("git push")
    assert reached_steps == expected_steps
    assert "REDDIT_SOURCE_PUBLICATION_FAILED=1" in result.stdout
    assert "REDDIT_SOURCE_LOCAL_FILES_RESTORED=1" in result.stdout
    assert "Git state was not rolled back" in result.stdout
    assert "REDDIT_SOURCE_PUBLICATION_FAILED_ROLLBACK" not in result.stdout
    assert sentiment.read_bytes() == sentiment_before
    assert topics.read_bytes() == b"tema,menciones\nPython,900\n"
    assert not receipt.exists()
    assert not ignored.exists()

    branch = git("branch", "--show-current").stdout.strip()
    index = git("diff", "--cached", "--name-only").stdout.strip().splitlines()
    worktree = git("diff", "--name-only").stdout.strip().splitlines()
    head = git("rev-parse", "HEAD").stdout.strip()
    remote_branch = subprocess.run(
        ["git", "--git-dir", str(remote), "show-ref", "--verify", "--quiet", "refs/heads/reddit-source-fixture"],
        check=False,
    ).returncode == 0
    next_run = automation / "next_run_preflight.ps1"
    next_run.write_text(preamble + "\nSet-Location $repo\nAssert-CleanWorktree\n", encoding="utf-8")
    preflight = subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-File", str(next_run)],
        cwd=repo, capture_output=True, text=True, check=False,
    )
    print(f"{failure}: branch={branch} index={index} worktree={worktree} "
          f"local_commit={head != baseline} remote_branch={remote_branch} next_run_blocked={preflight.returncode != 0}")
    changed_paths = sorted([
        "datos/reddit_sentimiento_frameworks.csv",
        "datos/reddit_temas_emergentes.csv",
        "datos/source_packages/reddit/receipt.json",
    ])
    assert branch == "reddit-source-fixture"
    expected_index = changed_paths[1:] if failure in {"commit", "index", "coherent"} else []
    if failure in {"index", "hook_index"}:
        expected_index = sorted([*expected_index, "extra.txt"])
    assert sorted(index) == expected_index
    assert sorted(worktree) == (changed_paths[1:] if failure != "add" else [])
    assert preflight.returncode != 0, "Next scheduled run must not silently retry after publication failure"
    assert (head != baseline) is (failure in {"push", "pr", "hook", "hook_index", "hook_package"})
    assert remote_branch is (failure == "pr")
