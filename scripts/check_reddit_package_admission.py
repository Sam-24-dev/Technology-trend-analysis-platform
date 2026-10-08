"""Admit committed Reddit packages as data using trusted code and a real UTC clock."""

import argparse
import csv
from datetime import datetime, timezone
import io
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
from reddit_source_package import producer_minimum_mentions, validate_reddit_source_package  # noqa: E402
from reddit_source_package import _unique_json_keys  # noqa: E402

PATHS = ("datos/reddit_sentimiento_frameworks.csv", "datos/reddit_temas_emergentes.csv",
         "datos/source_packages/reddit/receipt.json")
REPOSITORY = "Sam-24-dev/Technology-trend-analysis-platform"
SELECTORS = (r"^GIT_(DIR|WORK_TREE|COMMON_DIR|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|"
             r"NAMESPACE|.*PREFIX|SHALLOW_FILE|GRAFT_FILE|CONFIG.*|CEILING_DIRECTORIES|"
             r"DISCOVERY_ACROSS_FILESYSTEM|IMPLICIT_WORK_TREE|REPLACE_REF_BASE)$")


def git(root, *args):
    rejected = sorted(name for name in os.environ if re.match(SELECTORS, name, re.I))
    if rejected:
        raise ValueError("Rejected Git environment names: " + ", ".join(rejected))
    result = subprocess.run(["git", "--no-optional-locks", "-C", str(root), *args],
                            capture_output=True, timeout=60, check=False,
                            env=dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never"))
    if result.returncode:
        raise ValueError("Git operation failed: " + args[0])
    return result.stdout


def commit(root, sha):
    if not re.fullmatch(r"[0-9a-f]{40}", sha) or git(root, "rev-parse", sha + "^{commit}").decode().strip() != sha:
        raise ValueError("Expected an exact commit SHA")
    return sha


def admit(root, base, head, *, now=None):
    """Read immutable blobs only; now injection is internal to fixture tests."""
    root = Path(root)
    base, head = commit(root, base), commit(root, head)
    diff = git(root, "diff", "--no-ext-diff", "--no-renames", "--name-status", "-z", base, head).split(b"\0")[:-1]
    changes = [(diff[i].decode(), diff[i + 1].decode()) for i in range(0, len(diff), 2)]
    if not any(path in PATHS for _, path in changes):
        return {"classification": "code-only", "eligibility": "not-applicable"}
    if any(status not in {"A", "M"} or path not in PATHS for status, path in changes):
        raise ValueError("Package diff contains prohibited paths or changes")
    blobs = {}
    for path in PATHS:
        entry = git(root, "ls-tree", head, "--", path).decode().strip().split()
        if len(entry) != 4 or entry[:2] != ["100644", "blob"] or entry[3] != path:
            raise ValueError("Package requires three regular 100644 files")
        blobs[path] = git(root, "cat-file", "blob", entry[2])
    return admit_blobs(root, base, blobs, now=now)


def admit_blobs(root, base, blobs, *, now=None):
    """One provenance and coverage contract for committed and staged bytes."""
    current = now if now is not None else datetime.now(timezone.utc)
    if current.tzinfo is None:
        raise ValueError("Admission clock must be UTC-aware")
    current = current.astimezone(timezone.utc)
    package = validate_reddit_source_package(
        root, current.date().isoformat(), now=current,
        read_bytes=lambda path: blobs[path.relative_to(root).as_posix()],
    )
    baseline_bytes = git(root, "cat-file", "blob", base + ":" + PATHS[1])
    rows = list(csv.DictReader(io.StringIO(baseline_bytes.decode("utf-8"), newline=""), strict=True))
    counts = [int(row["menciones"]) for row in rows]
    if not counts or any(count <= 0 for count in counts):
        raise ValueError("Invalid verified-base topic snapshot")
    baseline = sum(counts)
    minimum = producer_minimum_mentions(baseline)
    if package["mentions_total"] < minimum:
        raise ValueError("Package below producer coverage minimum")
    return {"classification": "source-package", "identity": "pass", "coverage": "pass",
            "freshness": "pass", "eligibility": "pass", "aggregate_date_utc": current.date().isoformat(),
            "baseline_sha": base, "baseline_mentions": baseline, "minimum_mentions": minimum,
            "posts_count_claim": package["posts_count"], "mentions_total": package["mentions_total"]}


def manifest(root, head=None):
    """Capture every path, mode and object; never manufacture a tree from the worktree."""
    entries = {}
    raw = git(root, "ls-tree", "-r", "-z", head) if head else git(root, "ls-files", "--stage", "-z")
    for record in raw.split(b"\0")[:-1]:
        metadata, path = record.split(b"\t", 1)
        mode, middle, last = metadata.split()
        oid, stage = (last, b"0") if head else (middle, last)
        if stage != b"0" or path in entries:
            raise ValueError("Unmerged or duplicate index entry")
        entries[path] = (mode, oid)
    return entries


def fingerprint(entries):
    return hashlib.sha256(b"".join(path + b"\0" + mode + b" " + oid + b"\0"
                                   for path, (mode, oid) in sorted(entries.items()))).hexdigest()


def receipt_identity(data):
    receipt = json.loads(data.decode("utf-8"), object_pairs_hook=_unique_json_keys)
    return hashlib.sha256(json.dumps(receipt, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def admit_worktree(root, base, *, now=None):
    root = Path(root)
    base = commit(root, base)
    blobs = {path: (root / path).read_bytes() for path in PATHS}
    result = admit_blobs(root, base, blobs, now=now)
    if git(root, "rev-parse", "HEAD").decode().strip() != base or any((root / path).read_bytes() != data for path, data in blobs.items()):
        raise ValueError("Source package or HEAD changed during worktree admission")
    result["receipt_fingerprint"] = receipt_identity(blobs[PATHS[2]])
    return result


def admit_local(root, base, *, head=None, expected_index=None, expected_receipt=None, now=None):
    """Require a package and preserve the exact admitted complete index across commit hooks."""
    root = Path(root)
    base = commit(root, base)
    before = manifest(root)
    if head is not None:
        head = commit(root, head)
        if git(root, "rev-list", "--parents", "-n", "1", head).decode().split() != [head, base]:
            raise ValueError("Committed package must have prepared main as its sole parent")
        entries = manifest(root, head)
        if not expected_index or fingerprint(entries) != expected_index or before != entries:
            raise ValueError("Committed tree or index differs from admitted index")
    else:
        entries = before
    baseline = manifest(root, base)
    changed = {path for path in baseline.keys() | entries.keys() if baseline.get(path) != entries.get(path)}
    if not changed or not changed <= {path.encode() for path in PATHS} or any(path not in entries for path in changed):
        raise ValueError("Local publication requires only added or modified package paths")
    blobs = {}
    for path in PATHS:
        mode, oid = entries.get(path.encode(), (None, None))
        if mode != b"100644":
            raise ValueError("Package requires three regular 100644 files")
        blobs[path] = git(root, "cat-file", "blob", oid.decode())
    result = admit_blobs(root, base, blobs, now=now)
    if receipt_identity(blobs[PATHS[2]]) != expected_receipt:
        raise ValueError("Package differs from initially validated source receipt")
    if manifest(root) != before or git(root, "rev-parse", "HEAD").decode().strip() != (head or base):
        raise ValueError("Index or HEAD changed during local admission")
    result["index_fingerprint"] = fingerprint(entries)
    return result


def local_main(argv):
    parser = argparse.ArgumentParser(description="Read-only local Reddit package admission")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--base", required=True)
    view = parser.add_mutually_exclusive_group(required=True)
    view.add_argument("--index", action="store_true")
    view.add_argument("--worktree", action="store_true")
    view.add_argument("--head")
    parser.add_argument("--expected-index")
    parser.add_argument("--expected-receipt")
    args = parser.parse_args(argv)
    try:
        result = admit_worktree(args.root, args.base) if args.worktree else admit_local(
            args.root, args.base, head=args.head, expected_index=args.expected_index, expected_receipt=args.expected_receipt)
        print(json.dumps(result))
    except (ValueError, OSError, KeyError, UnicodeError, subprocess.TimeoutExpired) as exc:
        print("Local admission failed: " + str(exc))
        return 1
    return 0


def event_binding(event, repository):
    pr = event["pull_request"]
    if repository != REPOSITORY or event["repository"]["full_name"] != repository or pr["base"]["ref"] != "main":
        raise ValueError("Unexpected admission repository or base")
    if type(event["number"]) is not int or event["number"] <= 0:
        raise ValueError("Invalid PR number")
    base, head = pr["base"]["sha"], pr["head"]["sha"]
    if not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (base, head)):
        raise ValueError("Invalid event commit binding")
    return base, head, event["number"]


def publish_check(head, conclusion, summary, token):
    """One request, no retry; publish only a completed exact-head result."""
    payload = {"name": "Reddit package admission", "head_sha": head, "status": "completed",
               "conclusion": conclusion, "output": {"title": "Committed package admission", "summary": summary}}
    request = Request("https://api.github.com/repos/" + REPOSITORY + "/check-runs",
                      data=json.dumps(payload).encode(), method="POST",
                      headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
                               "X-GitHub-Api-Version": "2022-11-28"})
    with urlopen(request, timeout=30) as response:  # nosec B310: fixed HTTPS GitHub endpoint
        result = json.load(response)
    if result.get("head_sha") != head or result.get("conclusion") != conclusion or not result.get("id"):
        raise ValueError("Check response did not confirm exact-head result")
    return result["id"]


def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    base, head, number = event_binding(event, os.environ["GITHUB_REPOSITORY"])
    conclusion, summary = "failure", "Admission did not complete"
    try:
        if git(ROOT, "rev-parse", "HEAD").decode().strip() != base:
            raise ValueError("Trusted checkout differs from event base")
        if git(ROOT, "remote", "get-url", "origin").decode().strip().removesuffix(".git") != "https://github.com/" + REPOSITORY:
            raise ValueError("Unexpected fetch origin")
        capture = "refs/ttap/admission/" + os.environ["GITHUB_RUN_ID"] + "-" + os.environ["GITHUB_RUN_ATTEMPT"]
        git(ROOT, "fetch", "--no-tags", "--no-recurse-submodules", "origin", f"refs/pull/{number}/head:{capture}")
        if git(ROOT, "rev-parse", capture + "^{commit}").decode().strip() != head:
            raise ValueError("Fetched PR head differs from event")
        summary = json.dumps(admit(ROOT, base, head), sort_keys=True)
        conclusion = "success"
    except (ValueError, OSError, KeyError, UnicodeError, subprocess.TimeoutExpired) as exc:
        summary = "Admission failed; no package accepted: " + str(exc).split(":", 1)[0]
    print(summary)
    publish_check(head, conclusion, summary, os.environ["GITHUB_TOKEN"])
    return 0 if conclusion == "success" else 1


if __name__ == "__main__":
    sys.exit(local_main(sys.argv[1:]) if len(sys.argv) > 1 else main())
