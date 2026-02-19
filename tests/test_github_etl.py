"""
Tests for github_etl.py - GitHub ETL module.

Tests cover:
- Transformation: analizar_lenguajes returns correct columns
- Validation: no nulls in critical columns
- Mock of API responses (no real API calls)
"""
import pytest
import pandas as pd
from unittest.mock import patch, MagicMock
from github_etl import GitHubETL


@pytest.fixture
def etl():
    """Creates a GitHubETL instance with logging configured."""
    instance = GitHubETL()
    instance.configurar_logging()
    return instance


@pytest.fixture
def sample_repos_df():
    """Creates a sample repos DataFrame for testing."""
    return pd.DataFrame({
        "repo_name": ["user/repo1", "user/repo2", "user/repo3", "user/repo4", "user/repo5"],
        "language": ["Python", "Python", "JavaScript", "TypeScript", "Python"],
        "stars": [1000, 800, 600, 400, 200],
        "forks": [100, 80, 60, 40, 20],
        "created_at": ["2025-06-01", "2025-07-01", "2025-08-01", "2025-09-01", "2025-10-01"],
        "description": ["ML lib", "Web app", "UI framework", "CLI tool", "Data tool"]
    })


class TestGitHubETLDefinirPasos:
    """Tests for the definir_pasos method."""

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
    """Tests for the analizar_lenguajes method."""

    def test_lenguajes_correct_columns(self, etl, sample_repos_df, tmp_path):
        """Verify that analizar_lenguajes produces correct columns."""
        etl.df_repos = sample_repos_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert "lenguaje" in df.columns
        assert "repos_count" in df.columns
        assert "porcentaje" in df.columns

    def test_lenguajes_correct_counts(self, etl, sample_repos_df, tmp_path):
        """Verify that language counts are correct."""
        etl.df_repos = sample_repos_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        python_row = df[df["lenguaje"] == "Python"]
        assert python_row["repos_count"].values[0] == 3

    def test_lenguajes_no_nulls_in_critical(self, etl, sample_repos_df, tmp_path):
        """Verify no nulls in critical columns."""
        etl.df_repos = sample_repos_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"github_lenguajes": tmp_path / "test.csv"}):
            etl.analizar_lenguajes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert df["lenguaje"].isnull().sum() == 0
        assert df["repos_count"].isnull().sum() == 0

    def test_lenguajes_raises_on_empty_df(self, etl):
        """Verify it raises when df_repos is empty."""
        etl.df_repos = pd.DataFrame()
        with pytest.raises(Exception):
            etl.analizar_lenguajes()

    def test_lenguajes_filtra_no_clasificables(self, etl, tmp_path):
        """Verify 'Sin especificar' and AI labels are excluded from language ranking."""
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
    """Tests for AI/LLM insights generation."""

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
    """Tests for extraer_repos with mocked API."""

    def test_extraer_repos_success(self, etl, tmp_path):
        """Test successful repo extraction with mocked API."""
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
        """Test that empty API response raises ETLExtractionError."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"items": []}

        with patch("github_etl.requests.get", return_value=mock_response):
            with pytest.raises(Exception):
                etl.extraer_repos(max_repos=1)


class TestAnalizarCorrelacion:
    """Tests for analizar_correlacion."""

    def test_correlacion_raises_on_empty_df(self, etl):
        """Verify it raises when df_repos is empty."""
        etl.df_repos = pd.DataFrame()
        with pytest.raises(Exception):
            etl.analizar_correlacion()
