"""Git and CI guards for optional Reddit source package receipts."""

import hashlib
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import pytest

from reddit_source_package import REDDIT_SCOPE, validate_reddit_source_package


ROOT = Path(__file__).resolve().parents[1]
RECEIPT = "datos/source_packages/reddit/receipt.json"
CSV_NAMES = ("reddit_sentimiento_frameworks.csv", "reddit_temas_emergentes.csv")


def _git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True).stdout


def test_autocrlf_checkout_preserves_receipt_identity(tmp_path):
    producer = tmp_path / "producer"
    producer.mkdir()
    _git(producer, "init", "-q")
    _git(producer, "config", "user.name", "Fixture")
    _git(producer, "config", "user.email", "fixture@example.invalid")
    _git(producer, "config", "core.autocrlf", "true")
    shutil.copyfile(ROOT / ".gitattributes", producer / ".gitattributes")
    data = producer / "datos"
    data.mkdir()
    samples = (
        b"framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\r\nPython,2,1,1,0,50,50,0\r\n",
        b"tema,menciones\r\nPython,2\r\n",
    )
    outputs = {}
    for name, sample in zip(CSV_NAMES, samples):
        (data / name).write_bytes(sample)
        outputs[name] = {"rows": 1, "sha256": hashlib.sha256(sample).hexdigest()}
    outputs[CSV_NAMES[1]]["mentions_total"] = 2
    receipt = data / "source_packages" / "reddit" / "receipt.json"
    receipt.parent.mkdir(parents=True)
    receipt.write_text(json.dumps({
        "source": "reddit", "reference_date_utc": "2026-09-28", "source_date_utc": "2026-09-28",
        "extraction_started_at_utc": "2026-09-28T02:00:00Z",
        "extraction_finished_at_utc": "2026-09-28T02:05:00Z",
        "scope": list(REDDIT_SCOPE), "posts_count": 2, "outputs": outputs,
    }), encoding="utf-8")
    _git(producer, "add", ".gitattributes", *[f"datos/{name}" for name in CSV_NAMES], RECEIPT)
    _git(producer, "commit", "-qm", "fixture source package")

    for name, sample in zip(CSV_NAMES, samples):
        assert _git(producer, "show", f"HEAD:datos/{name}") == sample
    assert b"text: unset" in _git(producer, "check-attr", "text", "--", f"datos/{CSV_NAMES[0]}")
    assert b"diff: unset" not in _git(producer, "check-attr", "diff", "--", f"datos/{CSV_NAMES[0]}")

    checkout = tmp_path / "linux_checkout"
    subprocess.run(["git", "-c", "core.autocrlf=false", "clone", "-q", str(producer), str(checkout)], check=True)
    for name, sample in zip(CSV_NAMES, samples):
        assert (checkout / "datos" / name).read_bytes() == sample
    now = datetime(2026, 9, 28, 2, 5, tzinfo=timezone.utc)
    assert validate_reddit_source_package(checkout, "2026-09-28", now=now)
    with (checkout / "datos" / CSV_NAMES[0]).open("ab") as handle:
        handle.write(b"x")
    with pytest.raises(ValueError, match="Invalid Reddit source package"):
        validate_reddit_source_package(checkout, "2026-09-28", now=now)


def test_secret_scan_keeps_receipt_scanned_but_exempts_only_digest_line(tmp_path):
    hook = shutil.which("detect-secrets-hook")
    if hook is None:
        pytest.skip("detect-secrets-hook is not installed")
    workflow = (ROOT / ".github" / "workflows" / "secret_scan.yml").read_text(encoding="utf-8")
    digest_exception = '^ *"sha256" ?[=:] "[0-9a-f]{64}",?$'
    assert "DIGEST_PATTERN: '" + digest_exception + "'" in workflow
    assert '--exclude-lines "$DIGEST_PATTERN"' in workflow
    assert 'detect-sec""rets' not in workflow
    assert "--baseline .secrets.baseline" in workflow
    assert "--exclude-files" not in workflow
    receipt = tmp_path / "receipt.json"
    digest = hashlib.sha256(b"fixture aggregate").hexdigest()
    receipt.write_text('  "sha256": "' + digest + '"\n', encoding="utf-8")
    unfiltered = subprocess.run([hook, "--baseline", str(ROOT / ".secrets.baseline"), str(receipt)],
                                capture_output=True, text=True)
    assert unfiltered.returncode != 0
    allowed = subprocess.run([hook, "--baseline", str(ROOT / ".secrets.baseline"),
                              "--exclude-lines", digest_exception, str(receipt)],
                             capture_output=True, text=True)
    assert allowed.returncode == 0, allowed.stdout
    receipt.write_text('  "sha256": "' + digest + '",\n  "api_key": "' + digest + '"\n', encoding="utf-8")
    blocked = subprocess.run([hook, "--baseline", str(ROOT / ".secrets.baseline"),
                              "--exclude-lines", digest_exception, str(receipt)],
                             capture_output=True, text=True)
    assert blocked.returncode != 0


def test_ci_checks_optional_receipt_identity_without_freshness():
    workflow = (ROOT / ".github" / "workflows" / "secret_scan.yml").read_text(encoding="utf-8")
    assert 'if receipt_path.is_file():' in workflow
    assert 'validate_reddit_source_package(root, receipt["source_date_utc"], now=finished)' in workflow


def test_secret_scan_workflow_itself_remains_scannable():
    hook = shutil.which("detect-secrets-hook")
    if hook is None:
        pytest.skip("detect-secrets-hook is not installed")
    result = subprocess.run([hook, "--baseline", str(ROOT / ".secrets.baseline"),
                             str(ROOT / ".github" / "workflows" / "secret_scan.yml")],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stdout


def test_secret_scan_baseline_has_no_stale_workflow_allowlist():
    baseline = json.loads((ROOT / ".secrets.baseline").read_text(encoding="utf-8"))
    assert ".github/workflows/secret_scan.yml" not in baseline["results"]
