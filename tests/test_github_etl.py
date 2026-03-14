"""
Tests para github_etl.py - módulo ETL de GitHub.

Los tests cubren:
- Transformación: analizar_lenguajes retorna columnas correctas
- Validación: sin nulos en columnas críticas
- Mock de respuestas de API (sin llamadas reales a la API)
"""
import pytest
import pandas as pd
from unittest.mock import patch, MagicMock
from github_etl import GitHubETL


@pytest.fixture
def etl():
    """Crea una instancia de GitHubETL con logging configurado."""
    instance = GitHubETL()
    instance.configurar_logging()
    return instance


@pytest.fixture
def sample_repos_df():
    """Crea un DataFrame de repos de ejemplo para pruebas."""
    return pd.DataFrame({
        "repo_name": ["user/repo1", "user/repo2", "user/repo3", "user/repo4", "user/repo5"],
        "language": ["Python", "Python", "JavaScript", "TypeScript", "Python"],
        "stars": [1000, 800, 600, 400, 200],
        "forks": [100, 80, 60, 40, 20],
        "created_at": ["2025-06-01", "2025-07-01", "2025-08-01", "2025-09-01", "2025-10-01"],
        "description": ["ML lib", "Web app", "UI framework", "CLI tool", "Data tool"]
    })


class TestGitHubETLDefinirPasos:
    """Tests del método definir_pasos."""

    def test_definir_pasos_returns_list(self, etl):
        pasos = etl.definir_pasos()
        assert isinstance(pasos, list)
        assert len(pasos) == 6

    def test_definir_pasos_has_correct_names(self, etl):
        pasos = etl.definir_pasos()
        nombres = [nombre for nombre, _ in pasos]
        assert "Verificar conexion" in nombres
        assert "Extraccion de repos" in nombres
        assert "Analisis de lenguajes" in nombres
        assert "Insights repos IA" in nombres


class TestAnalizarLenguajes:
    """Tests del método analizar_lenguajes."""

    def test_lenguajes_correct_columns(self, etl, sample_repos_df, tmp_path):
        """Verifica que analizar_lenguajes produzca columnas correctas."""
        etl.df_repos = sample_repos_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert "lenguaje" in df.columns
        assert "repos_count" in df.columns
        assert "porcentaje" in df.columns

    def test_lenguajes_correct_counts(self, etl, sample_repos_df, tmp_path):
        """Verifica que los conteos de lenguaje sean correctos."""
        etl.df_repos = sample_repos_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        python_row = df[df["lenguaje"] == "Python"]
        assert python_row["repos_count"].values[0] == 3

    def test_lenguajes_no_nulls_in_critical(self, etl, sample_repos_df, tmp_path):
        """Verifica que no haya nulos en columnas críticas."""
        etl.df_repos = sample_repos_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert df["lenguaje"].isnull().sum() == 0
        assert df["repos_count"].isnull().sum() == 0

    def test_lenguajes_raises_on_empty_df(self, etl):
        """Verifica que lance excepción cuando df_repos está vacío."""
        etl.df_repos = pd.DataFrame()
        with pytest.raises(Exception):
            etl.analizar_lenguajes()

    def test_lenguajes_filtra_no_clasificables(self, etl, tmp_path):
        """Verifica que 'Sin especificar' y etiquetas de AI se excluyan del ranking de lenguajes."""
        etl.df_repos = pd.DataFrame({
            "repo_name": ["a/repo1", "a/repo2", "a/repo3", "a/repo4"],
            "language": ["Python", "Sin especificar", "LLMs/AI", "AI/ML"],
            "stars": [10, 20, 30, 40],
            "forks": [1, 2, 3, 4],
            "created_at": ["2025-01-01", "2025-01-01", "2025-01-01", "2025-01-01"],
            "description": ["x", "x", "x", "x"],
        })

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert "Python" in df["lenguaje"].tolist()
        assert "Sin especificar" not in df["lenguaje"].tolist()
        assert "LLMs/AI" not in df["lenguaje"].tolist()
        assert "AI/ML" not in df["lenguaje"].tolist()


class TestInsightsIA:
    """Tests para la generación de insights de AI/LLM."""

    def test_genera_insights_ai_csv(self, etl, tmp_path):
        etl.df_repos = pd.DataFrame({
            "repo_name": ["openai/gpt-sdk", "example/webapp"],
            "language": ["Sin especificar", "Python"],
            "stars": [1000, 100],
            "forks": [50, 10],
            "created_at": ["2025-02-15T00:00:00Z", "2025-02-01T00:00:00Z"],
            "description": ["SDK for gpt and llm apps", "regular backend service"],
        })

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_ai_insights": tmp_path / "ai.csv"}):
            etl.generar_insights_repos_ai()

        df = pd.read_csv(tmp_path / "ai.csv")
        assert "repos_ai_detectados" in df.columns
        assert int(df.iloc[0]["repos_ai_detectados"]) >= 1
        assert float(df.iloc[0]["porcentaje_ai"]) > 0


class TestExtraerRepos:
    """Tests para extraer_repos con API mockeada."""

    def test_extraer_repos_success(self, etl, tmp_path):
        """Test de extracción exitosa de repos con API mockeada."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "items": [
                {
                    "full_name": "test/repo1",
                    "language": "Python",
                    "stargazers_count": 500,
                    "forks_count": 50,
                    "created_at": "2025-06-15",
                    "description": "Test repo"
                }
            ]
        }
        mock_response.headers = {"X-RateLimit-Remaining": "100"}

        with patch("github_etl.requests.get", return_value=mock_response):
            with patch("base_etl.ARCHIVOS_SALIDA", {"github_repos": tmp_path / "repos.csv"}):
                etl.extraer_repos(max_repos=1)

        assert etl.df_repos is not None
        assert len(etl.df_repos) == 1
        assert etl.df_repos.iloc[0]["repo_name"] == "test/repo1"

    def test_extraer_repos_handles_empty_response(self, etl):
        """Test que verifica que una respuesta vacía de API lance ETLExtractionError."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"items": []}

        with patch("github_etl.requests.get", return_value=mock_response):
            with pytest.raises(Exception):
                etl.extraer_repos(max_repos=1)


class TestAnalizarCorrelacion:
    """Tests para analizar_correlacion."""

    def test_correlacion_raises_on_empty_df(self, etl):
        """Verifica que lance excepción cuando df_repos está vacío."""
        etl.df_repos = pd.DataFrame()
        with pytest.raises(Exception):
            etl.analizar_correlacion()

    def test_correlacion_adds_derived_metrics_and_snapshot_date(self, etl, tmp_path):
        etl.df_repos = pd.DataFrame(
            {
                "repo_name": ["vercel/next.js", "angular/angular", "facebook/react"],
                "language": ["JavaScript", "TypeScript", "JavaScript"],
                "stars": [5000, 4333, 1380],
            }
        )

        def _contributors_response(total):
            response = MagicMock()
            response.status_code = 200
            response.json.return_value = [{}] * total
            response.headers = {}
            return response

        with patch("github_etl.requests.get", side_effect=[
            _contributors_response(304),
            _contributors_response(274),
            _contributors_response(90),
        ]):
            with patch("github_etl.time.sleep", return_value=None):
                with patch("base_etl.WRITE_LEGACY_CSV", True):
                    with patch("base_etl.WRITE_LATEST_CSV", False):
                        with patch("base_etl.WRITE_HISTORY_CSV", False):
                            with patch(
                                "base_etl.ARCHIVOS_SALIDA",
                                {"github_correlacion": tmp_path / "github_correlacion.csv"},
                            ):
                                etl.analizar_correlacion()

        df = pd.read_csv(tmp_path / "github_correlacion.csv")

        assert "engagement_ratio" in df.columns
        assert "contributors_per_1k_stars" in df.columns
        assert "expected_contributors" in df.columns
        assert "contributors_delta_vs_trend" in df.columns
        assert "outlier_score" in df.columns
        assert "trend_bucket" in df.columns
        assert "snapshot_date_utc" in df.columns

        next_row = df[df["repo_name"] == "vercel/next.js"].iloc[0]
        assert int(next_row["contributors"]) == 304
        assert float(next_row["engagement_ratio"]) == pytest.approx(304 / 5000, rel=1e-6)
        assert float(next_row["contributors_per_1k_stars"]) == pytest.approx((304 / 5000) * 1000, rel=1e-6)
        assert float(next_row["expected_contributors"]) >= 0
        assert next_row["trend_bucket"] in {"above_trend", "near_trend", "below_trend"}
        assert str(next_row["snapshot_date_utc"]).strip()


class TestAnalizarCommitsFrameworks:
    """Tests para actividad de frameworks con métricas extendidas."""

    def test_commits_schema_extendido_y_delta(self, etl, tmp_path):
        previous_map = {
            "React": 100,
            "Vue 3": 80,
            "Angular": 60,
            "Svelte": 45,
            "Next.js": 90,
        }
        fake_metrics = {
            "React": {
                "framework": "React",
                "repo": "facebook/react",
                "commits_2025": 130,
                "active_contributors": 42,
                "merged_prs": 30,
                "closed_issues": 25,
                "releases_count": 3,
                "monthly_commits": {"2026-03": 40},
            },
            "Vue 3": {
                "framework": "Vue 3",
                "repo": "vuejs/core",
                "commits_2025": 70,
                "active_contributors": 28,
                "merged_prs": 18,
                "closed_issues": 20,
                "releases_count": 2,
                "monthly_commits": {"2026-03": 22},
            },
            "Angular": {
                "framework": "Angular",
                "repo": "angular/angular",
                "commits_2025": 65,
                "active_contributors": 24,
                "merged_prs": 14,
                "closed_issues": 19,
                "releases_count": 1,
                "monthly_commits": {"2026-03": 18},
            },
            "Svelte": {
                "framework": "Svelte",
                "repo": "sveltejs/svelte",
                "commits_2025": 52,
                "active_contributors": 19,
                "merged_prs": 11,
                "closed_issues": 14,
                "releases_count": 2,
                "monthly_commits": {"2026-03": 16},
            },
            "Next.js": {
                "framework": "Next.js",
                "repo": "vercel/next.js",
                "commits_2025": 120,
                "active_contributors": 35,
                "merged_prs": 21,
                "closed_issues": 27,
                "releases_count": 4,
                "monthly_commits": {"2026-03": 33},
            },
        }

        def _fake_collect(framework, _repo_path):
            return fake_metrics[framework]

        with patch.object(etl, "_load_previous_commits_map", return_value=(previous_map, "2026-03-03")):
            with patch.object(etl, "_collect_framework_metrics", side_effect=_fake_collect):
                with patch(
                    "base_etl.ARCHIVOS_SALIDA",
                    {
                        "github_commits": tmp_path / "github_commits_frameworks.csv",
                        "github_commits_monthly": tmp_path / "github_commits_frameworks_monthly.csv",
                    },
                ):
                    etl.analizar_commits_frameworks()

        commits_df = pd.read_csv(tmp_path / "github_commits_frameworks.csv")
        monthly_df = pd.read_csv(tmp_path / "github_commits_frameworks_monthly.csv")

        assert "active_contributors" in commits_df.columns
        assert "merged_prs" in commits_df.columns
        assert "closed_issues" in commits_df.columns
        assert "releases_count" in commits_df.columns
        assert "commits_prev" in commits_df.columns
        assert "delta_commits" in commits_df.columns
        assert "growth_pct" in commits_df.columns
        assert "trend_direction" in commits_df.columns

        react = commits_df[commits_df["framework"] == "React"].iloc[0]
        assert int(react["commits_prev"]) == 100
        assert int(react["delta_commits"]) == 30
        assert float(react["growth_pct"]) == 30.0
        assert react["trend_direction"] == "creciendo"

        vue = commits_df[commits_df["framework"] == "Vue 3"].iloc[0]
        assert int(vue["delta_commits"]) == -10
        assert vue["trend_direction"] == "cayendo"

        assert {"framework", "repo", "month", "commits"}.issubset(
            set(monthly_df.columns)
        )
        assert (monthly_df["framework"] == "React").any()
