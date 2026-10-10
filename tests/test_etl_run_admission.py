"""Exercise real admission with raw REST-shaped responses, never a success stub."""

import json
import sys
from pathlib import Path

import pytest

from scripts.check_etl_run_admission import Expected, JOBS, admit, recheck


EXPECTED = Expected("owner/repo", 10, 20, "a" * 40, 30, 1)


@pytest.fixture
def api():
    e = EXPECTED
    repository = {"id": e.repository_id, "full_name": e.repository}
    run = dict(id=e.run_id, run_attempt=e.attempt, workflow_id=e.workflow_id, path=e.path,
               head_branch=e.branch, head_sha=e.sha, repository=repository, head_repository=repository,
               status="in_progress", conclusion=None)
    jobs = [dict(id=i + 1, run_id=e.run_id, run_attempt=e.attempt, head_sha=e.sha, name=name,
                 status="completed", conclusion="success") for i, name in enumerate(JOBS.values())]
    binding = dict(id=e.run_id, repository_id=e.repository_id, head_repository_id=e.repository_id,
                   head_branch=e.branch, head_sha=e.sha)
    artifacts = [dict(id=i + 101, name=f"{source}-data-{e.run_id}-{e.attempt}", expired=False,
                      digest="sha256:" + "b" * 64, workflow_run=binding)
                 for i, source in enumerate(("github", "stackoverflow", "reddit", "aggregate"))]
    data = dict(run=run, jobs=jobs, artifacts=artifacts, calls=[], change=None)

    def transport(path):
        data["calls"].append(path)
        if "?" not in path:
            if data["change"] and len(data["calls"]) > 1:
                data["change"](data)
            return 200, json.dumps(data["run"]), {}
        key = "jobs" if "/jobs?" in path else "artifacts"
        page = int(path.rsplit("=", 1)[1])
        rows = data[key]
        headers = {"Link": f'<https://api.github.com{path.rsplit("=", 1)[0]}={page + 1}>; rel="next"'} \
            if page * 100 < len(rows) else {}
        return 200, json.dumps({"total_count": len(rows), key: rows[(page - 1) * 100:page * 100]}), headers

    data["transport"] = transport
    return data


def check(api, phase="aggregate", **kwargs):
    return admit(api["transport"], EXPECTED, phase, reddit_status="ok",
                 native_ids={"github": 101, "stackoverflow": 102, "reddit": 103, "aggregate": 104}, **kwargs)


@pytest.mark.parametrize("phase", ["aggregate", "publish", "deploy", "history"])
def test_roles_and_frozen_identity(api, phase):
    if phase in ("deploy", "history"):
        api["run"].update(status="completed", conclusion="success")
    result = check(api, phase)
    assert result.artifacts[-1][1] == (103 if phase == "aggregate" else 104)
    assert result.remote_eligible is (phase == "aggregate")
    assert recheck(api["transport"], result) == result


@pytest.mark.parametrize("field,value", [("run_id", True), ("attempt", 0), ("repository_id", None),
    ("workflow_id", "20"), ("sha", "bad"), ("repository", "../repo"), ("path", "other"), ("branch", "dev")])
def test_bad_expected(field, value):
    values = dict(EXPECTED.__dict__, **{field: value})
    with pytest.raises(ValueError):
        Expected(**values)


@pytest.mark.parametrize("field,value", [("id", True), ("run_attempt", 2), ("head_sha", "c" * 40),
    ("workflow_id", None), ("path", "other"), ("head_branch", "dev"), ("repository", {}),
    ("head_repository", {"id": 11, "full_name": "owner/repo"}), ("status", "cancelled")])
def test_run_identity_and_state(api, field, value):
    api["run"][field] = value
    with pytest.raises(ValueError):
        check(api)


@pytest.mark.parametrize("source", range(5))
@pytest.mark.parametrize("conclusion", ["cancelled", "skipped", "unknown", None])
def test_job_gate_failures(api, source, conclusion):
    api["run"].update(status="completed", conclusion="success")
    api["jobs"][source]["conclusion"] = conclusion
    with pytest.raises(ValueError):
        check(api, "deploy")


@pytest.mark.parametrize("source", [0, 1, 3, 4])
@pytest.mark.parametrize("conclusion", ["failure", "timed_out"])
def test_mandatory_failure_cannot_deploy(api, source, conclusion):
    api["run"].update(status="completed", conclusion="failure")
    api["jobs"][source]["conclusion"] = conclusion
    with pytest.raises(ValueError):
        check(api, "deploy")


@pytest.mark.parametrize("damage", ["missing", "duplicate", "unknown", "attempt", "id_bool", "sha", "running"])
def test_job_schema(api, damage):
    if damage == "missing":
        api["jobs"].pop(0)
    elif damage == "duplicate":
        api["jobs"].append(dict(api["jobs"][0], id=9))
    else:
        field, value = {"unknown": ("name", "Other"), "attempt": ("run_attempt", 2),
                        "id_bool": ("id", True), "sha": ("head_sha", "b" * 40),
                        "running": ("status", "in_progress")}[damage]
        api["jobs"][0][field] = value
    with pytest.raises(ValueError):
        check(api)


@pytest.mark.parametrize("status", [None, "", "unknown", "failed"])
def test_missing_outputs_fallback(api, status):
    result = admit(api["transport"], EXPECTED, "aggregate", reddit_status=status,
                   native_ids={"github": 101, "stackoverflow": 102})
    assert not result.remote_eligible
    assert len(result.artifacts) == 2


def test_confirmed_absence_and_other_attempt(api):
    api["artifacts"][2]["name"] = "reddit-data-30-2"
    assert not check(api).remote_eligible
    api["artifacts"].append(dict(api["artifacts"][0], id=999, name="github-data-30-2"))
    assert len(check(api).artifacts) == 2


@pytest.mark.parametrize("damage", ["missing", "legacy", "duplicate", "expired", "digest", "identity"])
def test_artifact_rejections(api, damage):
    if damage == "missing":
        api["artifacts"].pop(0)
    elif damage == "duplicate":
        api["artifacts"].append(dict(api["artifacts"][0], id=999))
    else:
        field, value = {"legacy": ("name", "github-data"), "expired": ("expired", True),
                        "digest": ("digest", None), "identity": ("workflow_run", {"id": 30})}[damage]
        api["artifacts"][0][field] = value
    with pytest.raises(ValueError):
        check(api)


def test_native_ids_and_legacy_history(api):
    with pytest.raises(ValueError):
        admit(api["transport"], EXPECTED, "publish", native_ids={"aggregate": 999})
    api["run"].update(status="completed", conclusion="success")
    api["artifacts"][3]["name"] = "aggregate-data"
    with pytest.raises(ValueError):
        check(api, "history")


@pytest.mark.parametrize("conclusion", ["failure", "timed_out"])
def test_optional_failure_explains_completed_failure(api, conclusion):
    api["run"].update(status="completed", conclusion=conclusion)
    with pytest.raises(ValueError):
        check(api, "deploy")
    api["jobs"][2]["conclusion"] = conclusion
    assert check(api, "deploy").artifacts[0][1] == 104


def test_complete_pagination(api):
    api["artifacts"] += [dict(api["artifacts"][0], id=1000 + i, name=f"other-{i}") for i in range(100)]
    assert check(api).remote_eligible
    assert any("artifacts?per_page=100&page=2" in p for p in api["calls"])


@pytest.mark.parametrize("response", [(403, "{}", {}), (200, "null", {}), (200, "{", {}),
    (200, '{"id":1,"id":2}', {}), (200, '{"constant":NaN}', {}),
    (200, '{"total_count":true,"jobs":[]}', {}),
    (200, '{"total_count":2,"jobs":[]}', {}), (200, '{"total_count":0,"jobs":[]}',
     {"Link": '<https://evil.test/>; rel="next"'})])
def test_transport_and_collection_errors(api, response):
    original = api["transport"]
    api["transport"] = lambda path: response if "?" in path else original(path)
    with pytest.raises(ValueError):
        check(api)


def test_transport_exception_is_not_absence(api):
    def failed(_path):
        raise OSError("Simulated network failure")
    with pytest.raises(OSError):
        admit(failed, EXPECTED, "aggregate")


def test_incomplete_pagination_and_duplicate_ids(api):
    original = api["transport"]
    def without_links(path):
        status, body, _headers = original(path)
        return status, body, {}
    api["artifacts"] += [dict(api["artifacts"][0], id=1000 + i, name=f"other-{i}") for i in range(100)]
    api["transport"] = without_links
    with pytest.raises(ValueError):
        check(api)
    api["transport"] = original
    api["artifacts"][-1]["id"] = 101
    with pytest.raises(ValueError):
        check(api)


@pytest.mark.parametrize("change", [{"run_attempt": 2}, {"status": "completed", "conclusion": "success"},
                                    {"status": "completed", "conclusion": "cancelled"}])
def test_before_after_and_postdownload_races(api, change):
    before = check(api)
    api["change"] = lambda data: data["run"].update(change)
    with pytest.raises(ValueError):
        recheck(api["transport"], before)
    api["run"].update(status="in_progress", conclusion=None, run_attempt=1)
    api["calls"].clear()
    with pytest.raises(ValueError):
        check(api)


def test_import_is_inert(monkeypatch):
    source = Path(__file__).resolve().parents[1] / "scripts/check_etl_run_admission.py"
    with monkeypatch.context() as context:
        context.delitem(sys.modules, "scripts.check_etl_run_admission")
        context.delattr(sys.modules["scripts"], "check_etl_run_admission")
        assert "scripts.check_etl_run_admission" not in sys.modules
        context.setattr("builtins.open", lambda *a, **k: pytest.fail("Import opened a file"))
        import scripts.check_etl_run_admission as module
        assert Path(module.__file__).resolve() == source
        assert callable(module.admit)


@pytest.mark.parametrize("values,error", [
    (("invalid", "next"), "Unsafe pagination link"),
    (("next", "invalid"), "Unsafe pagination link"),
    (("next",), None), (("lower_next",), None), (("next_last",), None),
    (("next", "next"), None), (("next", "last"), None), (("last", "next"), None),
    (("other_next", "next"), "Conflicting pagination link"),
    (("next", "other_next"), "Conflicting pagination link"),
])
def test_link_aliases_preserve_all_values(api, values, error):
    base = "https://api.github.com/repos/owner/repo/actions/runs/30/artifacts?per_page=100&page="
    links = {"next": f'<{base}2>; rel="next"', "lower_next": f'<{base}2>; rel="next"',
             "last": f'<{base}2>; rel="last"', "other_next": f'<{base}3>; rel="next"',
             "invalid": '<https://evil.test/>; rel="next"'}
    links["next_last"] = links["next"] + ", " + links["last"]
    api["artifacts"] += [dict(api["artifacts"][0], id=1000 + i, name=f"other-{i}") for i in range(100)]
    original = api["transport"]
    def transport(path):
        status, body, headers = original(path)
        if "/artifacts?" in path:
            headers = {"X-Test": "one", "x-test": "two"}
            if path.endswith("page=1"):
                headers.update({("link" if value == "lower_next" or index else "Link"): links[value]
                                for index, value in enumerate(values)})
            else:
                headers["Link"] = f'<{base}1>; rel="prev", <{base}1>; rel="first"'
        return status, body, headers
    api["transport"] = transport
    if error:
        with pytest.raises(ValueError, match=error):
            check(api)
    else:
        result = check(api)
        assert result.remote_eligible and [a[1] for a in result.artifacts] == [101, 102, 103]
        assert any("artifacts?per_page=100&page=2" in path for path in api["calls"])
