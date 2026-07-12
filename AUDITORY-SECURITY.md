# Exhaustive Security Audit Report

## Audit metadata

- **Repository:** `Technology-trend-analysis-platform`
- **Audit environment:** Clean worktree created from `origin/main`
- **Audited commit:** `b8f29f2bdef671480c590e6fc8e30c52aaf4b000` (verified equal to `origin/main`)
- **Audit date:** 2026-07-12
- **Production target:** `https://sam-24-dev.github.io/Technology-trend-analysis-platform/`
- **Scope:** All 226 tracked files. The 37 generated dataset/public-data files under `datos/` and `frontend/assets/data/` were inventoried and their schemas, consumers, publication paths, and exposure were reviewed; bulky row content was not manually reviewed where it had no additional security value.
- **Write scope:** This report only. No source, dependency, workflow, configuration, or generated-data file was modified.
- **Safety boundary:** Passive review only. No OWASP ZAP, Nuclei, Burp, exploit attempt, fuzzing against production, or active network scanner was used.

## Methodology

The audit traced Python ETL and artifact-recovery trust boundaries, HTTP/TLS behavior, parsing, SQL, filesystem writes, credentials and logging; reviewed Flutter/Dart routing, remote and bundled data loading, downloads, HTML/JavaScript bootstrap, and public assets; inspected every GitHub Actions workflow, permissions, trigger, expression boundary, action reference, artifact flow, and Dependabot configuration; inventoried dependency manifests and tracked-file hygiene; ran the requested scanners; and passively inspected production HTTP behavior and headers.

Severity reflects demonstrated impact and prerequisites in this repository, not scanner labels alone. No claim of “100% security” is made: this is a point-in-time audit with explicit limitations.

## Executive summary

**Security posture: generally sound; no Critical, High, or Medium vulnerability was confirmed. The remaining findings are Low or Informational hardening gaps.**

No Critical or High finding was confirmed. Existing controls are materially better than a typical small data dashboard: all 32 third-party workflow uses are pinned to full commit SHAs, most jobs use read-only permissions and credential-disabled checkout, network calls use HTTPS and timeouts, XML uses `defusedxml`, DuckDB inputs are parameterized, ZIP traversal and symlinks are rejected, secret/static/dependency workflows exist, and production redirects HTTP to HTTPS with HSTS.

The smallest concrete first fix is **SEC-004**, because a credential-bearing request exception demonstrably reaches logs. **SEC-001** and **SEC-002** remain worthwhile artifact hardening, but both require control of an artifact scoped to successful `main` workflow runs.

| Priority | ID | Severity | Confidence | Summary |
|---|---|---:|---:|---|
| P1 | SEC-004 | Low | High | Stack Overflow API key can appear in exception logs |
| P2 | SEC-001 | Low | High | Artifact metadata can write a new file outside the project root |
| P3 | SEC-002 | Low | High | Artifact download and ZIP expansion have no resource limits |
| P4 | SEC-003 | Low | High | Remote JSON accepts HTTP/arbitrary origins and unbounded bodies |
| P5 | SEC-006 | Low | High | Redundant route decoding permits a crafted-link client crash |
| P6 | SEC-007 | Low | High | Python and Flutter dependency resolution is not reproducible |
| P7 | SEC-005 | Informational | High | Optional CLI token input is process-visible when operators use it |
| P8 | SEC-008 | Informational | High | CSV exports lack one defensive serialization boundary |

## Prioritized findings

### SEC-001 — Artifact metadata can write outside the project root

- **Severity:** Low
- **Confidence:** High
- **Evidence:** `scripts/hydrate_aggregate_history_seed.py:35-45` loads artifact-derived `history_index.json`; `latest_path` and snapshot `path` from lines 49-52 become destinations at lines 64-70, and `_copy_if_missing` creates parents and copies at lines 27-31. The unsafe hydrator runs during candidate validation at `scripts/download_valid_aggregate_artifact.py:121-133,195-224` and again after restoration at `.github/workflows/etl_semanal.yml:293-328`.
- **Impact / exploitability:** Control of a consumed artifact and a matching source CSV permits an absolute or `../` destination to create a missing file outside the checkout. Existing files are not overwritten. Artifact selection is restricted to successful repository/workflow/`main` runs (`scripts/download_valid_aggregate_artifact.py:161-179`), so exploitation requires trusted-artifact or Actions supply-chain compromise; this is a containment gap, not an untrusted-PR path.
- **Smallest safe remediation:** Resolve each destination against `project_root.resolve()`, reject absolute paths, require `target.relative_to(project_root)`, and allow only the expected `datos/latest/` or `datos/history/` prefixes.
- **Validation criteria:** Tests pass malicious absolute and `../../escape.csv` targets, assert rejection, and prove no external file is created; existing valid hydration tests remain green.

### SEC-002 — Unbounded artifact download and ZIP expansion

- **Severity:** Low
- **Confidence:** High
- **Evidence:** `scripts/download_valid_aggregate_artifact.py:36-44` buffers the complete HTTP response through `response.content`. `scripts/download_valid_aggregate_artifact.py:61-74` iterates and decompresses every member without limits on compressed bytes, member count, individual size, total uncompressed size, or compression ratio.
- **Impact / exploitability:** A hostile or corrupted selected artifact can exhaust memory or disk on an ephemeral CI runner. Exploitation requires trusted-artifact compromise or operator-selected hostile input, and the aggregate job has a 20-minute timeout (`.github/workflows/etl_semanal.yml:234-235`), limiting impact to CI availability and resource consumption.
- **Smallest safe remediation:** Stream the download with a fixed byte ceiling, then reject archives exceeding fixed member-count, per-member, and total-uncompressed limits before extraction.
- **Validation criteria:** Tests reject an oversized response, excessive members, and excessive uncompressed totals while preserving valid downloads and existing traversal/symlink rejection.

### SEC-003 — Remote JSON boundary accepts cleartext/arbitrary origins and unbounded bodies

- **Severity:** Low
- **Confidence:** High
- **Evidence:** Deployment-configured URLs are accepted in `frontend/lib/config/feature_flags.dart:30-94`; `frontend/lib/services/csv_service.dart:314-326` accepts both `http` and `https`, buffers the full response, decodes malformed UTF-8, and JSON-decodes without a content-type or size check. A 15-second timeout exists at line 321. Current production config is same-origin HTTPS at `.github/workflows/deploy_frontend.yml:95-109`.
- **Impact / exploitability:** Arbitrary-origin loading requires changed build configuration plus browser CORS permission. The current production build uses a same-origin HTTPS base; its remaining exposure is unbounded response processing after source/origin compromise. Mixed-content policy normally blocks HTTP from the deployed HTTPS site.
- **Smallest safe remediation:** Require HTTPS, allowlist the expected host (or same origin), and reject oversized bodies before JSON decoding.
- **Validation criteria:** Tests reject HTTP, unexpected hosts, oversized payloads, wrong content types, malformed JSON, and non-map JSON while retaining local fallback.

### SEC-004 — Stack Overflow API key may enter exception logs

- **Severity:** Low
- **Confidence:** High
- **Evidence:** `backend/stackoverflow_etl.py:60-70` places `SO_API_KEY` in query parameters. `backend/stackoverflow_etl.py:76-77` logs the complete `RequestException`. `backend/base_etl.py:71-81` writes logs to console and a daily file.
- **Impact / exploitability:** A focused sentinel check confirmed that a Requests connection exception includes the prepared query string, so this path can expose the quota credential to console or local file-log readers. GitHub masks configured secret values in Actions logs, reducing—but not eliminating—the risk across local or differently configured runs.
- **Smallest safe remediation:** Log a fixed message and exception class, not `str(exception)`, on this credential-bearing request path.
- **Validation criteria:** A mocked exception containing a sentinel key never writes the sentinel to console or file logs.

### SEC-005 — GitHub token accepted through command-line arguments

- **Severity:** Informational
- **Confidence:** High
- **Evidence:** `scripts/download_valid_aggregate_artifact.py:248-268` accepts `--token` and forwards it. The real workflow correctly uses the `GITHUB_TOKEN` environment variable at `.github/workflows/etl_semanal.yml:293-305`.
- **Impact / exploitability:** Local process listings, shell history, or command diagnostics can expose a token when an operator chooses this option. No tracked automation uses it; the workflow supplies `GITHUB_TOKEN` through the environment.
- **Smallest safe remediation:** Remove `--token`; accept credentials only from `GITHUB_TOKEN`.
- **Validation criteria:** `--help` no longer exposes the option, environment authentication works, and a missing environment token fails without echoing sensitive data.

### SEC-006 — Redundant URI decoding permits a crafted-link client crash

- **Severity:** Low
- **Confidence:** High
- **Evidence:** GoRouter provides `state.pathParameters['tech']` at `frontend/lib/router/app_router.dart:83-92`. `frontend/lib/screens/trends_tech_screen.dart:58-59` calls `Uri.decodeComponent` again without handling `FormatException`.
- **Impact / exploitability:** A crafted doubly encoded percent sequence can make the second decode throw and break that visitor’s route/tab. There is no server compromise or cross-user impact.
- **Smallest safe remediation:** Remove the second `Uri.decodeComponent`; use GoRouter’s decoded path parameter.
- **Validation criteria:** Router tests cover encoded names and malformed/double-encoded percent sequences without uncaught exceptions.

### SEC-007 — Dependency resolution is not reproducible

- **Severity:** Low
- **Confidence:** High
- **Evidence:** Python dependencies use ranges without hashes or a transitive lock at `backend/requirements.txt:2-12`; CI resolves them repeatedly at `.github/workflows/ci.yml:27-40` and `.github/workflows/etl_semanal.yml:40-50`. Flutter uses compatible ranges at `frontend/pubspec.yaml:15-22`; `.gitignore:12-18` ignores `pubspec.lock`, and no lockfile is tracked. Dependabot is configured for both ecosystems at `.github/dependabot.yml:3-39`.
- **Impact / exploitability:** Builds can silently resolve different compatible releases, increasing compromised-release and regression exposure. The successful audit found no known Python vulnerability in the resolution produced on 2026-07-12; no exact Flutter resolution can be audited from the commit.
- **Smallest safe remediation:** Use separate PRs: commit the Flutter application lockfile; independently generate and review a Python constraints/lock file for CI. Add hashes only if stronger provenance is required.
- **Validation criteria:** Clean builds install the same versions twice; the lock/constraints files are tracked; dependency audits run against those exact versions.

### SEC-008 — CSV exports lack one safe serialization boundary

- **Severity:** Informational
- **Confidence:** High
- **Evidence:** GitHub exports concatenate fields directly at `frontend/lib/screens/github_dashboard.dart:141-209`. Reddit’s helper escapes quotes/delimiters but not formula-leading characters at `frontend/lib/screens/reddit_dashboard.dart:2581-2613` and 2650-2663. Stack Overflow follows the same helper pattern at `frontend/lib/screens/stackoverflow_dashboard.dart:129-176` and 2695-2702. ZIP downloads occur at the corresponding GitHub lines 212-236, Reddit lines 2616-2633, and Stack Overflow lines 180-212.
- **Impact / exploitability:** A future untrusted text field could corrupt CSV structure or become a spreadsheet formula when opened. Current exported text is largely constrained by fixed ETL dictionaries, fixed Stack Overflow tag lists, or GitHub naming/language rules, so an attacker-controlled formula path was **not confirmed** at this commit.
- **Smallest safe remediation:** Reuse the already installed Dart `csv` package for all exports and neutralize leading `=`, `+`, `-`, and `@` for text cells.
- **Validation criteria:** Export tests include commas, quotes, newlines, and formula-leading values; decoded ZIP members remain structurally valid and formula-neutralized.

## Existing controls that passed

- **Workflow action pinning:** 32/32 `uses:` references are pinned to full 40-character commit SHAs across `.github/workflows/*.yml`.
- **Workflow permissions:** CI, dependency, static, secret-scan, and ETL defaults are read-only (`.github/workflows/ci.yml:12-13`, `dependency_security.yml:18-19`, `static_security.yml:24-25`, `secret_scan.yml:10-11`, `etl_semanal.yml:8-10`). ETL grants `contents: write` only to the publish job at `etl_semanal.yml:528-537`.
- **Trigger safety:** No `pull_request_target` workflow exists. The privileged deployment’s `workflow_run` path requires a successful main-branch ETL run and checks out `main` at `deploy_frontend.yml:10-30`.
- **Persisted credentials:** Read-only jobs and deployment checkout set `persist-credentials: false`. The ETL publish job retains credentials because its explicit purpose is to push generated data; it runs only after the aggregate gate.
- **Artifact run scoping and structural validation:** Downloads are bound to run IDs or successful repository/workflow/`main` runs; this is run scoping, not cryptographic provenance. Recovery validates expected structure before replacement, but validation currently invokes the unsafe hydrator described in SEC-001. ZIP member containment and symlink rejection are implemented at `scripts/download_valid_aggregate_artifact.py:47-74`; traversal tests exist at `tests/test_download_valid_aggregate_artifact.py:345-355`.
- **SQL injection:** DuckDB query text is static and numeric weights are parameterized at `backend/trend_score_duckdb.py:18-26` and 50-105.
- **XML/JSON:** Reddit RSS parsing uses `defusedxml` (`backend/reddit_etl.py:18`, 353-357). Public run-manifest schema rejects additional properties at `backend/config/run_manifest_public_schema.json:5-18`.
- **HTTP/TLS in code:** Reviewed production ETL calls use fixed HTTPS origins and explicit timeouts; no `verify=False` was found.
- **Subprocess/dynamic execution:** No production `subprocess`, shell execution, `eval`, `exec`, `pickle`, `marshal`, or unsafe YAML load was found.
- **Secrets/tracked hygiene:** Credentials are environment-derived; `.env` and logs are ignored. `.env.example` contains placeholders, not live values. The detect-secrets baseline’s four current entries are marked reviewed false positives and no new current-tree candidate was found.
- **Frontend navigation/XSS:** `frontend/web/404.html:10-24` redirects only to `window.location.origin`; `history.replaceState` does not perform external navigation. No tracked application use of `innerHTML`, WebView, dynamic code execution, or arbitrary external-navigation API was found.
- **Public assets:** `frontend/pubspec.yaml:29-34` intentionally publishes `assets/data/`; the public manifest contains aggregate metadata, not credentials.
- **Production transport:** Passive requests returned HTTP 301 to HTTPS and HTTPS 200 with `Strict-Transport-Security: max-age=31556952`. TLS certificate verification succeeded.

## Scanner matrix

No requested scanner was unavailable or timed out. Initial malformed local invocations of TruffleHog, pip-audit, and Semgrep produced only command/path errors; each was corrected and rerun successfully.

| Tool | Version | Exact successful command | Result and exit semantics | Limitations |
|---|---:|---|---|---|
| detect-secrets | 1.5.0 | `git ls-files -z \| grep -zv '^\.secrets\.baseline$' \| xargs -0r detect-secrets-hook --baseline .secrets.baseline` | Exit 0; no output; no new current tracked-file candidate outside the baseline. | Baseline suppressions require human review; this command checks the current tracked snapshot, not deleted history. |
| TruffleHog | 3.95.7 | `trufflehog git file://. --fail --json` | Exit 183 because `--fail` found 2 candidates; 0 verified. Both were unverified `Box` detector matches in deleted historical Chrome optimization-model binaries at commit `5ce28c012329a22f0901055892e251eaeb69824f`; no secret values were printed or retained in this report. | Verification can be inconclusive; historical binary heuristics can false-positive. The two candidates should not be treated as credentials without independent verification. |
| Bandit | 1.8.6 | `bandit -r backend scripts -x "**/__pycache__/**" -ll -f json -o <temporary-file>` | Exit 0; 0 medium/high findings; 0 scan errors. | `-ll` intentionally reports medium/high only; Bandit does not model application dataflow or Dart. |
| pip-audit | 2.9.0 | `pip-audit -r backend/requirements.txt -f json -o <temporary-file>` | Exit 0; 28 resolved dependencies; 0 known vulnerabilities. Exit 0 means no vulnerability was reported. | Audited a resolution generated on audit date from ranges, not a committed lock; advisory coverage is ecosystem/database dependent. |
| Semgrep | 1.141.0 | `semgrep scan --error --metrics=off --config p/python --config p/javascript --config p/github-actions --config p/secrets --exclude .git --exclude frontend/build --exclude frontend/.dart_tool --exclude datos --exclude frontend/assets/data --json-output <temporary-file> .` | Exit 0; 132 files scanned before this report existed; 0 findings; 0 errors. The current worktree adds this report as a 133rd scanned file. With `--error`, a blocking finding would produce non-zero status. | Rulesets do not provide complete Dart/Flutter semantic coverage; generated datasets were intentionally excluded. |

## Production passive HTTP findings

Observed on 2026-07-12:

- `http://...` redirects to HTTPS with 301.
- HTTPS root returns 200 and HSTS.
- Root response lacks CSP, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, and frame-embedding control headers.
- `frontend/web/index.html:24` supplies a meta referrer policy. No demonstrated DOM-XSS sink was found.
- `/.well-known/security.txt` under the project path returns 404.
- `Access-Control-Allow-Origin: *` is consistent with intentionally public static assets.

The missing hardening headers are recorded as residual risk rather than a standalone vulnerability: GitHub Pages does not expose arbitrary response-header configuration for this deployment, the app is a read-only public dashboard, and a CSP added blindly would likely break Flutter bootstrap/inline scripts/Wasm resources. If stronger browser isolation becomes a requirement, move the static build behind a host/CDN that supports tested headers. Do not add an untested meta CSP.

## Phased PR roadmap

Keep every item independently reviewable; do not mix unrelated fixes.

1. **Phase 1 — SEC-004 only:** Redact Stack Overflow request exceptions and add a sentinel-log test. This is the smallest confirmed credential-handling fix.
2. **Phase 2 — SEC-001 only:** Add destination containment and allowed-prefix validation to history hydration, with traversal/absolute-path tests.
3. **Phase 3 — SEC-002 only:** Add streamed download and ZIP resource ceilings, with exhaustion tests.
4. **Phase 4 — SEC-003 only:** Enforce HTTPS/expected origin and bounded remote JSON bodies in the frontend.
5. **Phase 5 — SEC-006 only:** Remove redundant route decoding and add crafted-link tests.
6. **Phase 6A — Flutter reproducibility:** Track `frontend/pubspec.lock` and validate clean locked builds.
7. **Phase 6B — Python reproducibility:** Add a reviewed CI constraints/lock file and audit that exact resolution.
8. **Optional hardening:** Remove the unused CLI token option and centralize CSV serialization/formula neutralization using the existing dependency.
9. **Hosting hardening decision:** Separately evaluate CSP, nosniff, frame controls, Permissions-Policy, and `security.txt`; this may require hosting/CDN changes and must not be bundled into application fixes.

## Residual risks and deferred items

- This is a point-in-time audit; new dependencies, workflow SHAs, data sources, or hosting behavior require re-audit.
- Public datasets and operational metadata are intentionally world-readable. They must never gain credentials, private identifiers, or licensed/private source data.
- The two historical TruffleHog candidates are unverified and likely binary false positives; repository-history cleanup is not justified without independent evidence.
- Full action SHA pinning prevents tag drift but does not eliminate maintainer compromise or malicious code already present at a pinned commit.
- Deployment grants `contents: write` across its only job (`.github/workflows/deploy_frontend.yml:15-17`), including checkout, Flutter setup, and artifact-download actions before publishing. The explicit token input appears only on the deploy action, but actions can access `github.token`; split build and publish jobs or adopt the official Pages artifact/OIDC flow if reducing token exposure justifies the migration.
- `scripts/download_valid_aggregate_artifact.py:77-95,146-150` recursively replaces an operator-selected output directory after limited guard checks. Tracked automation fixes it to `prev_artifacts`, so this remains an operator-safety concern rather than an exploitable automated path.
- No active application scanner or authenticated attack simulation was run by design.
- Semgrep has limited Dart semantics, Bandit was configured for medium/high severity, and advisory databases can have coverage delays.
- Missing `security.txt` affects vulnerability-reporting discoverability, not application confidentiality or integrity.

This report does not promise or imply “100% security.” It records evidence, limitations, and prioritized risk reduction for the audited commit.
