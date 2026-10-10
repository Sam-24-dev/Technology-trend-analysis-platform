"""Inert exact-attempt admission; callers supply transport and trusted producer context."""

import json
import re
from dataclasses import dataclass


JOBS = dict(zip(("github", "stackoverflow", "reddit", "aggregate", "publish"),
                ("Source - GitHub", "Source - StackOverflow", "Source - Reddit",
                 "Aggregate + Quality Gate", "Publish Data")))


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _positive(value):
    return type(value) is int and value > 0


@dataclass(frozen=True)
class Expected:
    repository: str
    repository_id: int
    workflow_id: int
    sha: str
    run_id: int
    attempt: int
    path: str = ".github/workflows/etl_semanal.yml"
    branch: str = "main"

    def __post_init__(self):
        _require(isinstance(self.repository, str) and re.fullmatch(
            r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", self.repository), "Invalid repository")
        _require(all(_positive(v) for v in (self.repository_id, self.workflow_id,
                                          self.run_id, self.attempt)), "Invalid IDs")
        _require(isinstance(self.sha, str) and re.fullmatch(r"[0-9a-f]{40}", self.sha), "Invalid SHA")
        _require(self.path == ".github/workflows/etl_semanal.yml" and self.branch == "main",
                 "Unexpected workflow or branch")


@dataclass(frozen=True)
class Admission:
    expected: Expected
    phase: str
    state: tuple
    artifacts: tuple
    remote_eligible: bool


def _unique(pairs):
    result = dict(pairs)
    _require(len(result) == len(pairs), "Duplicate JSON key")
    return result


def _get(transport, path):
    status, body, headers = transport(path)
    _require(type(status) is int and status == 200, "API request failed")
    _require(isinstance(headers, dict) and all(isinstance(k, str) and isinstance(v, str)
                                             for k, v in headers.items()), "Invalid headers")
    _require(isinstance(body, (str, bytes)), "Expected raw JSON")
    def invalid_constant(_value):
        raise ValueError("Invalid JSON constant")
    payload = json.loads(body, object_pairs_hook=_unique, parse_constant=invalid_constant)
    _require(isinstance(payload, dict), "Invalid API envelope")
    normalized = {}
    for key, value in headers.items():
        key = key.lower()
        normalized[key] = normalized[key] + ", " + value if key == "link" and key in normalized else value
    return payload, normalized


def _collection(transport, path, key):
    rows, total = [], None
    for page in range(1, 11):
        payload, headers = _get(transport, f"{path}?per_page=100&page={page}")
        count, batch = payload.get("total_count"), payload.get(key)
        _require(type(count) is int and 0 <= count <= 1000 and isinstance(batch, list),
                 "Invalid collection")
        total = count if total is None else total
        _require(count == total and len(batch) == min(100, total - len(rows)), "Incomplete collection")
        links = {}
        for link in headers.get("link", "").split(","):
            if not link.strip():
                continue
            match = re.fullmatch(r'\s*<([^>]+)>; rel="(next|prev|first|last)"\s*', link)
            _require(match is not None, "Invalid pagination link")
            url, relation = match.groups()
            _require(re.fullmatch(re.escape("https://api.github.com" + path)
                                 + r"\?per_page=100&page=([1-9]|10)", url), "Unsafe pagination link")
            _require(relation not in links or links[relation] == url, "Conflicting pagination link")
            links[relation] = url
        rows.extend(batch)
        next_url = f"https://api.github.com{path}?per_page=100&page={page + 1}"
        _require(links.get("next") == (next_url if len(rows) < total else None), "Incomplete pagination")
        if len(rows) == total:
            _require(all(isinstance(row, dict) and _positive(row.get("id")) for row in rows),
                     "Invalid collection item")
            _require(len({row["id"] for row in rows}) == len(rows), "Duplicate item ID")
            return rows
    raise ValueError("Pagination bound exceeded")


def _run(transport, expected, phase):
    root = f"/repos/{expected.repository}/actions/runs/{expected.run_id}"
    run, _ = _get(transport, root)
    identity = dict(id=expected.run_id, run_attempt=expected.attempt, workflow_id=expected.workflow_id,
                    path=expected.path, head_branch=expected.branch, head_sha=expected.sha)
    _require(all(type(run.get(k)) is type(v) and run[k] == v for k, v in identity.items()), "Run drift")
    for key in ("repository", "head_repository"):
        repository = run.get(key)
        _require(isinstance(repository, dict) and type(repository.get("id")) is int
                 and repository["id"] == expected.repository_id
                 and repository.get("full_name") == expected.repository, "Repository drift")
    state = run.get("status"), run.get("conclusion")
    allowed = (("in_progress", None),) if phase in ("aggregate", "publish") else (
        ("completed", "success"), ("completed", "failure"), ("completed", "timed_out"))
    _require(state in allowed, "Run cancelled, unknown or inappropriate for phase")
    return root, state


def recheck(transport, admission):
    """Detect post-download/pre-delivery drift; this is not an atomic delivery lock."""
    _, state = _run(transport, admission.expected, admission.phase)
    _require(state == admission.state, "Run state drift")
    return admission


def admit(transport, expected, phase, *, reddit_status=None, native_ids=None):
    """Reject legacy by default; future callers must deploy the trusted suffixed-name contract."""
    _require(phase in ("aggregate", "publish", "deploy", "history"), "Unknown phase")
    _require(reddit_status in (None, "", "unknown", "failed", "ok"), "Unknown Reddit output")
    native_ids = {} if native_ids is None else native_ids
    _require(isinstance(native_ids, dict) and all(k in JOBS and _positive(v)
                                                for k, v in native_ids.items()), "Invalid native IDs")
    root, state = _run(transport, expected, phase)
    jobs = _collection(transport, f"{root}/attempts/{expected.attempt}/jobs", "jobs")
    by_name = {}
    for job in jobs:
        name = job.get("name")
        _require(isinstance(name, str) and name in JOBS.values() and name not in by_name,
                 "Unknown or duplicate job")
        _require(type(job.get("run_id")) is int and job["run_id"] == expected.run_id
                 and type(job.get("run_attempt")) is int and job["run_attempt"] == expected.attempt
                 and job.get("head_sha") == expected.sha, "Job identity mismatch")
        by_name[name] = job
    required = ("github", "stackoverflow", "reddit") + (() if phase == "aggregate" else ("aggregate",))
    if phase in ("deploy", "history"):
        required += ("publish",)
    for source in required:
        job = by_name.get(JOBS[source], {})
        conclusions = ("success", "failure", "timed_out") if source == "reddit" else ("success",)
        _require(job.get("status") == "completed" and job.get("conclusion") in conclusions,
                 f"Required job not admitted: {source}")
    reddit_ok = by_name[JOBS["reddit"]]["conclusion"] == "success"
    _require(state[1] not in ("failure", "timed_out") or not reddit_ok, "Unexplained workflow failure")
    artifacts = _collection(transport, f"{root}/artifacts", "artifacts")
    _require(all(isinstance(a.get("name"), str) for a in artifacts)
             and len({a["name"] for a in artifacts}) == len(artifacts), "Invalid or duplicate artifact name")
    selected = []
    sources = ("github", "stackoverflow", "reddit") if phase == "aggregate" else ("aggregate",)
    remote = False
    for source in sources:
        name = f"{source}-data-{expected.run_id}-{expected.attempt}"
        matches = [a for a in artifacts if a["name"] == name]
        if source == "reddit" and (not reddit_ok or reddit_status != "ok" or not matches):
            continue
        _require(len(matches) == 1, f"Required current-attempt artifact missing: {source}")
        artifact = matches[0]
        binding = artifact.get("workflow_run")
        identity = dict(id=expected.run_id, repository_id=expected.repository_id,
                        head_repository_id=expected.repository_id, head_branch=expected.branch,
                        head_sha=expected.sha)
        _require(isinstance(binding, dict) and all(type(binding.get(k)) is type(v)
                 and binding[k] == v for k, v in identity.items()), "Artifact identity mismatch")
        _require(artifact.get("expired") is False and isinstance(artifact.get("digest"), str)
                 and re.fullmatch(r"sha256:[0-9a-f]{64}", artifact["digest"]), "Invalid artifact digest/state")
        if phase in ("aggregate", "publish") or source in native_ids:
            _require(native_ids.get(source) == artifact["id"], "Native artifact ID mismatch")
        selected.append((source, artifact["id"], artifact["digest"]))
        remote = source == "reddit" or remote
    admission = Admission(expected, phase, state, tuple(selected), remote)
    return recheck(transport, admission)
