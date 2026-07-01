"""
Tests para reddit_etl.py - módulo ETL de Reddit.

Los tests cubren:
- Análisis de sentimiento con texto conocido
- Detección de temas emergentes
- Mocking de API
"""
import pytest
import pandas as pd
from unittest.mock import patch  # noqa: F401
from reddit_etl import RedditETL
from exceptions import ETLExtractionError


@pytest.fixture
def etl():
    """Crea una instancia de RedditETL con logging configurado."""
    instance = RedditETL()
    instance.configurar_logging()
    return instance


@pytest.fixture
def sample_posts_df():
    """Crea un DataFrame de posts de ejemplo para pruebas."""
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
    """Tests para definir_pasos."""

    def test_returns_five_steps(self, etl):
        pasos = etl.definir_pasos()
        assert len(pasos) == 5

    def test_step_names(self, etl):
        pasos = etl.definir_pasos()
        nombres = [n for n, _ in pasos]
        assert "Preparar recursos NLTK" not in nombres
        assert "Autenticacion OAuth" in nombres
        assert "Sentimiento de frameworks" in nombres
        assert "Temas emergentes" in nombres


class TestConfiguracionReddit:
    """Tests para validación temprana de configuración en Reddit ETL."""

    def test_validar_configuracion_falla_si_credenciales_incompletas(self, etl):
        with patch("reddit_etl.REDDIT_CLIENT_ID", "id_solo"), patch("reddit_etl.REDDIT_CLIENT_SECRET", None):
            with pytest.raises(ETLExtractionError):
                etl.validar_configuracion()

    def test_validar_configuracion_permite_modo_publico(self, etl):
        with patch("reddit_etl.REDDIT_CLIENT_ID", None), patch("reddit_etl.REDDIT_CLIENT_SECRET", None):
            etl.validar_configuracion()


class TestOAuthLogging:
    """Tests for secure Reddit OAuth logging."""

    def test_missing_oauth_token_does_not_log_response_payload(self, etl, caplog):
        class FakeResponse:
            status_code = 200

            @staticmethod
            def json():
                return {
                    "error": "invalid_client",
                    "error_description": "redacted-marker-alpha",
                    "debug_payload": "redacted-marker-beta",
                }

        with (
            patch("reddit_etl.REDDIT_CLIENT_ID", "client-id"),
            patch("reddit_etl.REDDIT_CLIENT_SECRET", "client-secret"),
            patch("reddit_etl.requests.post", return_value=FakeResponse()),
            caplog.at_level("WARNING", logger=etl.logger.name),
        ):
            etl._obtener_token_oauth()

        assert etl.access_token is None
        assert etl.api_base == "https://www.reddit.com"
        assert "redacted-marker-alpha" not in caplog.text
        assert "redacted-marker-beta" not in caplog.text
        assert "debug_payload" not in caplog.text


class TestRssFallback:
    """Tests for the Reddit RSS fallback parser."""

    def test_rss_fallback_parses_atom_entries(self, etl):
        atom_payload = """<?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>t3_post123</id>
            <title>Python and FastAPI are useful</title>
            <content type="html">&lt;p&gt;Django &amp;amp; FastAPI content&lt;/p&gt;</content>
            <published>2026-06-30T12:34:56Z</published>
            <author><name>rss_author</name></author>
          </entry>
        </feed>
        """

        class FakeResponse:
            status_code = 200
            text = atom_payload
            headers = {}

        with (
            patch("reddit_etl.requests.get", return_value=FakeResponse()),
            patch("reddit_etl.time.sleep"),
        ):
            posts = etl._extraer_posts_rss("webdev", 1)

        assert posts == [
            {
                "post_id": "post123",
                "titulo": "Python and FastAPI are useful",
                "contenido": "Django & FastAPI content",
                "upvotes": 0,
                "comentarios": 0,
                "created_at": pd.Timestamp("2026-06-30T12:34:56").to_pydatetime(),
                "autor": "rss_author",
            }
        ]


class TestSentimientoFrameworks:
    """Tests para analizar_sentimiento_frameworks."""

    def test_sentiment_produces_correct_columns(self, etl, sample_posts_df, tmp_path):
        """Verifica que la salida tenga columnas correctas."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_sentimiento": tmp_path / "test.csv"}):
            etl.analizar_sentimiento_frameworks()

        df = pd.read_csv(tmp_path / "test.csv")
        expected = ["framework", "total_menciones", "positivos", "neutros", "negativos", "% positivo"]
        for col in expected:
            assert col in df.columns

    def test_sentiment_detects_frameworks(self, etl, sample_posts_df, tmp_path):
        """Verifica que las menciones de frameworks sean detectadas."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_sentimiento": tmp_path / "test.csv"}):
            etl.analizar_sentimiento_frameworks()

        df = pd.read_csv(tmp_path / "test.csv")
        frameworks = df["framework"].tolist()
        assert "Django" in frameworks
        assert "FastAPI" in frameworks

    def test_sentiment_positive_text(self, etl, tmp_path):
        """Verifica que el texto positivo sea clasificado correctamente."""
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
        """Verifica que lance excepción con DataFrame vacío."""
        etl.df_posts = pd.DataFrame()
        with pytest.raises(Exception):
            etl.analizar_sentimiento_frameworks()


class TestTemasEmergentes:
    """Tests para detectar_temas_emergentes."""

    def test_detects_known_topics(self, etl, sample_posts_df, tmp_path):
        """Verifica que temas conocidos se detecten desde datos de ejemplo."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_temas": tmp_path / "test.csv"}):
            etl.detectar_temas_emergentes()

        df = pd.read_csv(tmp_path / "test.csv")
        temas = df["tema"].tolist()
        # El post 4 menciona AI/ML, Cloud y Python
        assert "IA/Machine Learning" in temas
        assert "Python" in temas

    def test_topics_have_positive_counts(self, etl, sample_posts_df, tmp_path):
        """Verifica que todos los temas detectados tengan al menos 1 mención."""
        etl.df_posts = sample_posts_df

        with patch("base_etl.ARCHIVOS_SALIDA", {"reddit_temas": tmp_path / "test.csv"}):
            etl.detectar_temas_emergentes()

        df = pd.read_csv(tmp_path / "test.csv")
        assert (df["menciones"] > 0).all()

    def test_topics_raises_on_empty(self, etl):
        """Verifica que lance excepción con DataFrame vacío."""
        etl.df_posts = pd.DataFrame()
        with pytest.raises(Exception):
            etl.detectar_temas_emergentes()


class TestKeywordPrecision:
    """Tests para precisión de matching de keywords en Reddit ETL."""

    def test_javascript_does_not_match_java_keyword(self, etl, tmp_path):
        """Asegura que 'javascript' no dispare falsos positivos de Java/Spring."""
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
        """Asegura que 'api' genérico por sí solo no cuente como Microservicios."""
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
