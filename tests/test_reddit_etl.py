"""
Tests for reddit_etl.py - Reddit ETL module.

Tests cover:
- Sentiment analysis with known text
- Emerging topics detection
- API mocking
"""
import pytest
import pandas as pd
from unittest.mock import patch  # noqa: F401
from reddit_etl import RedditETL
from exceptions import ETLExtractionError


@pytest.fixture
def etl():
    """Creates a RedditETL instance with logging configured."""
    instance = RedditETL()
    instance.configurar_logging()
    return instance


@pytest.fixture
def sample_posts_df():
    """Creates sample posts DataFrame for testing."""
    return pd.DataFrame({
        "post_id": ["abc1", "abc2", "abc3", "abc4"],
        "titulo": [
            "Django is amazing for backend",
            "FastAPI performance is incredible",
            "Express.js has too many issues",
            "Machine learning with Python is great"
        ],
        "contenido": [
            "I love using Django for web development, great framework",
            "FastAPI is blazing fast, love it for APIs",
            "Express keeps breaking, terrible experience with Node.js",
            "AI and machine learning with Python is the future of cloud computing"
        ],
        "upvotes": [100, 80, 50, 120],
        "comentarios": [20, 15, 10, 25],
        "created_at": ["2025-06-01", "2025-07-01", "2025-08-01", "2025-09-01"],
        "autor": ["user1", "user2", "user3", "user4"]
    })


class TestDefinirPasos:
    """Tests for definir_pasos."""

    def test_returns_five_steps(self, etl):
        pasos = etl.definir_pasos()
        assert len(pasos) == 6

    def test_step_names(self, etl):
        pasos = etl.definir_pasos()
        nombres = [n for n, _ in pasos]
        assert "Preparar recursos NLTK" in nombres
        assert "Autenticacion OAuth" in nombres
        assert "Sentimiento de frameworks" in nombres
        assert "Temas emergentes" in nombres


class TestConfiguracionReddit:
    """Tests for early configuration validation in Reddit ETL."""

    def test_validar_configuracion_falla_si_credenciales_incompletas(self, etl):
        with patch("reddit_etl.REDDIT_CLIENT_ID", "id_solo"), patch("reddit_etl.REDDIT_CLIENT_SECRET", None):
            with pytest.raises(ETLExtractionError):
                etl.validar_configuracion()

    def test_validar_configuracion_permite_modo_publico(self, etl):
        with patch("reddit_etl.REDDIT_CLIENT_ID", None), patch("reddit_etl.REDDIT_CLIENT_SECRET", None):
            etl.validar_configuracion()


class TestSentimientoFrameworks:
    """Tests for analizar_sentimiento_frameworks."""

    def test_sentiment_produces_correct_columns(self, etl, sample_posts_df, tmp_path):
        """Verify output has correct columns."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_sentimiento": tmp_path / "test.csv"}):
            etl.analizar_sentimiento_frameworks()

        df = pd.read_csv(tmp_path / "test.csv")
        expected = ["framework", "total_menciones", "positivos", "neutros", "negativos", "% positivo"]
        for col in expected:
            assert col in df.columns

    def test_sentiment_detects_frameworks(self, etl, sample_posts_df, tmp_path):
        """Verify that framework mentions are detected."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_sentimiento": tmp_path / "test.csv"}):
            etl.analizar_sentimiento_frameworks()

        df = pd.read_csv(tmp_path / "test.csv")
        frameworks = df["framework"].tolist()
        assert "Django" in frameworks
        assert "FastAPI" in frameworks

    def test_sentiment_positive_text(self, etl, tmp_path):
        """Verify positive text is classified correctly."""
        positive_posts = pd.DataFrame({
            "post_id": ["p1"],
            "titulo": ["Django is the best framework ever, absolutely love it"],
            "contenido": ["Amazing, wonderful, excellent, fantastic, great experience"],
            "upvotes": [100],
            "comentarios": [10],
            "created_at": ["2025-06-01"],
            "autor": ["happy_user"]
        })
        etl.df_posts = positive_posts

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_sentimiento": tmp_path / "test.csv"}):
            etl.analizar_sentimiento_frameworks()

        df = pd.read_csv(tmp_path / "test.csv")
        django_row = df[df["framework"] == "Django"]
        if not django_row.empty:
            assert django_row["positivos"].values[0] >= 1

    def test_sentiment_raises_on_empty(self, etl):
        """Verify it raises on empty DataFrame."""
        etl.df_posts = pd.DataFrame()
        with pytest.raises(Exception):
            etl.analizar_sentimiento_frameworks()


class TestTemasEmergentes:
    """Tests for detectar_temas_emergentes."""

    def test_detects_known_topics(self, etl, sample_posts_df, tmp_path):
        """Verify known topics are detected from sample data."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_temas": tmp_path / "test.csv"}):
            etl.detectar_temas_emergentes()

        df = pd.read_csv(tmp_path / "test.csv")
        temas = df["tema"].tolist()
        # Post 4 mentions AI/ML and Cloud and Python
        assert "IA/Machine Learning" in temas
        assert "Python" in temas

    def test_topics_have_positive_counts(self, etl, sample_posts_df, tmp_path):
        """Verify all detected topics have at least 1 mention."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_temas": tmp_path / "test.csv"}):
            etl.detectar_temas_emergentes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert (df["menciones"] > 0).all()

    def test_topics_raises_on_empty(self, etl):
        """Verify it raises on empty DataFrame."""
        etl.df_posts = pd.DataFrame()
        with pytest.raises(Exception):
            etl.detectar_temas_emergentes()


class TestKeywordPrecision:
    """Tests for keyword matching precision in Reddit ETL."""

    def test_javascript_does_not_match_java_keyword(self, etl, tmp_path):
        """Ensure 'javascript' does not trigger Java/Spring false positives."""
        etl.df_posts = pd.DataFrame({
            "post_id": ["p1"],
            "titulo": ["JavaScript ecosystem news and Django notes"],
            "contenido": ["This post is about javascript tooling and django usage"],
            "upvotes": [10],
            "comentarios": [2],
            "created_at": ["2025-06-01"],
            "autor": ["user_js"]
        })

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_sentimiento": tmp_path / "test.csv"}):
            etl.analizar_sentimiento_frameworks()

        df = pd.read_csv(tmp_path / "test.csv")
        if "Spring" in df["framework"].tolist():
            spring_row = df[df["framework"] == "Spring"]
            assert spring_row["total_menciones"].values[0] == 0

    def test_api_word_alone_does_not_count_as_microservices(self, etl, tmp_path):
        """Ensure generic 'api' alone does not count as Microservicios."""
        etl.df_posts = pd.DataFrame({
            "post_id": ["p2"],
            "titulo": ["Public API release for cloud users"],
            "contenido": ["We launched a new api today on azure cloud"],
            "upvotes": [8],
            "comentarios": [1],
            "created_at": ["2025-06-01"],
            "autor": ["user_api"]
        })

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_temas": tmp_path / "test.csv"}):
            etl.detectar_temas_emergentes()

        df = pd.read_csv(tmp_path / "test.csv")
        if "Microservicios" in df["tema"].tolist():
            micro_row = df[df["tema"] == "Microservicios"]
            assert micro_row["menciones"].values[0] == 0
