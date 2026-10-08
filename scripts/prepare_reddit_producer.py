"""Prepare clean producer main without installing packages or replacing bootstrap code."""

import argparse
from importlib import metadata
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

ORIGIN = "https://github.com/Sam-24-dev/Technology-trend-analysis-platform"
CONTROLS = ("automation/run_reddit_baseline_guarded.ps1", "automation/run_reddit_baseline.ps1",
            "automation/reddit_output_transaction.psm1", "scripts/prepare_reddit_producer.py",
            "scripts/check_reddit_package_admission.py", "backend/reddit_source_package.py")
GIT_SELECTORS = (r"^GIT_(DIR|WORK_TREE|COMMON_DIR|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|"
                 r"NAMESPACE|.*PREFIX|SHALLOW_FILE|GRAFT_FILE|CONFIG.*|CEILING_DIRECTORIES|"
                 r"DISCOVERY_ACROSS_FILESYSTEM|IMPLICIT_WORK_TREE|REPLACE_REF_BASE)$")


def git(root, *args):
    rejected = sorted(name for name in os.environ if re.match(GIT_SELECTORS, name, re.IGNORECASE))
    if rejected:
        raise RuntimeError("Rejected Git environment: " + ", ".join(rejected))
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="Never",
               GIT_SSH_COMMAND="ssh -oBatchMode=yes")
    result = subprocess.run(["git", "-C", str(root), *args],
                            env=env, capture_output=True, text=True, timeout=60, check=False)
    if result.returncode:
        raise RuntimeError(f"Git {args[0]} failed; Git state was not rolled back")
    return result.stdout.strip()


def clean_main(root):
    if git(root, "branch", "--show-current") != "main":
        raise RuntimeError("Producer requires main")
    for operation in ("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-apply",
                      "rebase-merge", "sequencer", "index.lock"):
        path = Path(git(root, "rev-parse", "--git-path", operation))
        if (path if path.is_absolute() else Path(root) / path).exists():
            raise RuntimeError("Git operation or index lock exists; preserve it for inspection")
    if git(root, "status", "--porcelain", "--untracked-files=all") or any(line.startswith("!! ") for line in
            git(root, "status", "--porcelain", "--ignored", "--untracked-files=all", "--",
                "datos/latest", "datos/history", "datos/metadata").splitlines()):
        raise RuntimeError("Existing changes or ignored outputs; refusing preparation")
    return git(root, "rev-parse", "HEAD")


def dependencies(lock):
    if sys.version_info[:2] != (3, 11) or sys.prefix == sys.base_prefix:
        raise RuntimeError("An explicitly invoked isolated Python 3.11 is required")
    pins = {}
    for line in lock.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = re.fullmatch(r"([A-Za-z0-9][A-Za-z0-9_.-]*)==([0-9]+(?:\.[0-9]+)*(?:\.post[0-9]+)?)", line)
        if not match:
            raise RuntimeError("Unsupported lock syntax")
        name, version = match.groups()
        name = re.sub(r"[-_.]+", "-", name).lower()
        if name in pins:
            raise RuntimeError("Duplicate lock pin")
        pins[name] = version
        try:
            installed = metadata.version(name)
        except metadata.PackageNotFoundError as exc:
            raise RuntimeError(f"Missing locked dependency: {name}") from exc
        if installed != version:
            raise RuntimeError(f"Installed dependency differs from frozen lock: {name}")
    if not pins:
        raise RuntimeError("Empty dependency lock")


def prepare(root, expected_origin=ORIGIN):
    """The origin argument is for direct local fixtures; CLI never overrides production origin."""
    stage = "preflight"
    head = target = "unknown"
    try:
        head = clean_main(root)
        origin = git(root, "remote", "get-url", "--all", "origin").removesuffix(".git")
        if origin != expected_origin.removesuffix(".git"):
            raise RuntimeError("Unexpected origin")
        stage = "fetch"
        capture = f"refs/ttap/preparation/{uuid.uuid4().hex}"
        git(root, "fetch", "--atomic", "--no-tags", "--no-recurse-submodules", "origin",
            "refs/heads/main:refs/remotes/origin/main", f"refs/heads/main:{capture}")
        target = git(root, "rev-parse", f"{capture}^{{commit}}")
        git(root, "update-ref", "-d", capture, target)
        stage = "admission"
        git(root, "merge-base", "--is-ancestor", head, target)
        original = git(root, "ls-tree", head, "--", *CONTROLS)
        if len(original.splitlines()) != len(CONTROLS) or original != git(root, "ls-tree", target, "--", *CONTROLS):
            raise RuntimeError("Bootstrap blobs or modes changed; activate reviewed controls explicitly")
        stage = "dependencies"
        dependencies(git(root, "show", f"{target}:backend/requirements.lock"))
        stage = "advance"
        if clean_main(root) != head:
            raise RuntimeError("HEAD changed during preparation")
        if head != target:
            git(root, "merge", "--ff-only", target)
        if clean_main(root) != target:
            raise RuntimeError("Prepared HEAD differs from frozen main")
        return target
    except (RuntimeError, subprocess.TimeoutExpired, OSError, KeyboardInterrupt) as exc:
        try:
            actual = git(root, "rev-parse", "HEAD")
        except (RuntimeError, subprocess.TimeoutExpired, OSError, KeyboardInterrupt):
            actual = "unknown"
        reason = str(exc) if isinstance(exc, RuntimeError) else type(exc).__name__
        raise RuntimeError(f"Preparation failed at {stage}; H={head}; T={target}; actualHEAD={actual}; "
                           f"fetched refs may have changed; no Git rollback: {reason}") from exc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(prepare(args.root))
    except RuntimeError as exc:
        print(str(exc))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
