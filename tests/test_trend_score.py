"""
Tests for trend_score.py - Trend Score module.

Tests cover:
- Trend Score calculation with sample data
- Correct ranking order
- Normalization logic
- Handling missing sources
"""
import pandas as pd
from unittest.mock import patch
from trend_score import (
    normalizar_nombre,
    normalizar_scores,
    cargar_github,
    calcular_trend_score,
    PESOS
)


class TestNormalizarNombre:
    """Tests for technology name normalization."""

    def test_python_normalized(self):
        assert normalizar_nombre("python") == "Python"

    def test_javascript_normalized(self):
        assert normalizar_nombre("javascript") == "JavaScript"

    def test_reactjs_normalized(self):
        assert normalizar_nombre("reactjs") == "React"

    def test_vue_normalized(self):
        assert normalizar_nombre("vue.js") == "Vue.js"

    def test_unknown_gets_title_case(self):
        result = normalizar_nombre("sometech")
        assert result == "Sometech"

    def test_preserves_mapping(self):
        assert normalizar_nombre("c#") == "C#"
        assert normalizar_nombre("c++") == "C++"


class TestNormalizarScores:
    """Tests for min-max score normalization."""

    def test_normalizes_to_0_100(self):
        serie = pd.Series([10, 20, 30, 40, 50])
        result = normalizar_scores(serie)
        assert result.min() == 0.0
        assert result.max() == 100.0

    def test_handles_equal_values(self):
        """When all values are equal, should return 50."""
        serie = pd.Series([5, 5, 5])
        result = normalizar_scores(serie)
        assert (result == 50.0).all()

    def test_preserves_order(self):
        serie = pd.Series([10, 30, 20])
        result = normalizar_scores(serie)
        assert result.iloc[0] < result.iloc[2] < result.iloc[1]


class TestCalcularTrendScore:
    """Tests for the composite Trend Score calculation."""

    def test_correct_ranking_order(self):
        """Top score should be ranked #1."""
        df_github = pd.DataFrame({
            "tecnologia": ["Python", "JavaScript"],
            "github_score": [100.0, 50.0]
        })
        df_so = pd.DataFrame({
            "tecnologia": ["Python", "JavaScript"],
            "so_score": [80.0, 60.0]
        })
        df_reddit = pd.DataFrame({
            "tecnologia": ["Python", "JavaScript"],
            "reddit_score": [70.0, 40.0]
        })

        with patch("trend_score.cargar_github", return_value=df_github), \
             patch("trend_score.cargar_stackoverflow", return_value=df_so), \
             patch("trend_score.cargar_reddit", return_value=df_reddit):
            result = calcular_trend_score()

        assert result.iloc[0]["tecnologia"] == "Python"
        assert result.iloc[0]["ranking"] == 1
        assert result.iloc[1]["ranking"] == 2

    def test_weighted_calculation(self):
        """Verify the weighted formula is correct."""
        df_github = pd.DataFrame({
            "tecnologia": ["TestLang"],
            "github_score": [100.0]
        })
        df_so = pd.DataFrame({
            "tecnologia": ["TestLang"],
            "so_score": [100.0]
        })
        df_reddit = pd.DataFrame({
            "tecnologia": ["TestLang"],
            "reddit_score": [100.0]
        })

        with patch("trend_score.cargar_github", return_value=df_github), \
             patch("trend_score.cargar_stackoverflow", return_value=df_so), \
             patch("trend_score.cargar_reddit", return_value=df_reddit):
            result = calcular_trend_score()

        # 0.40*100 + 0.35*100 + 0.25*100 = 100
        expected = PESOS["github"] * 100 + PESOS["stackoverflow"] * 100 + PESOS["reddit"] * 100
        assert result.iloc[0]["trend_score"] == expected

    def test_missing_source_fills_zero(self):
        """Technologies not in a source should get 0 for that source."""
        df_github = pd.DataFrame({
            "tecnologia": ["Python", "Go"],
            "github_score": [100.0, 50.0]
        })
        df_so = pd.DataFrame({
            "tecnologia": ["Python"],
            "so_score": [80.0]
        })
        df_reddit = pd.DataFrame(columns=["tecnologia", "reddit_score"])

        with patch("trend_score.cargar_github", return_value=df_github), \
             patch("trend_score.cargar_stackoverflow", return_value=df_so), \
             patch("trend_score.cargar_reddit", return_value=df_reddit):
            result = calcular_trend_score()

        go_row = result[result["tecnologia"] == "Go"]
        assert go_row["so_score"].values[0] == 0.0
        assert go_row["reddit_score"].values[0] == 0.0

    def test_fuentes_count(self):
        """Verify the 'fuentes' column counts sources correctly."""
        df_github = pd.DataFrame({
            "tecnologia": ["Python", "Rust"],
            "github_score": [100.0, 80.0]
        })
        df_so = pd.DataFrame({
            "tecnologia": ["Python"],
            "so_score": [90.0]
        })
        df_reddit = pd.DataFrame({
            "tecnologia": ["Python"],
            "reddit_score": [70.0]
        })

        with patch("trend_score.cargar_github", return_value=df_github), \
             patch("trend_score.cargar_stackoverflow", return_value=df_so), \
             patch("trend_score.cargar_reddit", return_value=df_reddit):
            result = calcular_trend_score()

        python_row = result[result["tecnologia"] == "Python"]
        rust_row = result[result["tecnologia"] == "Rust"]
        assert python_row["fuentes"].values[0] == 3
        assert rust_row["fuentes"].values[0] == 1

    def test_empty_all_sources(self):
        """Returns empty DataFrame when no data is available."""
        empty = pd.DataFrame(columns=["tecnologia", "github_score"])

        with patch("trend_score.cargar_github", return_value=empty), \
             patch("trend_score.cargar_stackoverflow", return_value=pd.DataFrame(columns=["tecnologia", "so_score"])), \
             patch("trend_score.cargar_reddit", return_value=pd.DataFrame(columns=["tecnologia", "reddit_score"])):
            result = calcular_trend_score()

        assert result.empty


class TestCargarGitHub:
    """Tests for GitHub data loading and filtering in trend score."""

    def test_filtra_etiquetas_no_lenguaje(self):
        sample = pd.DataFrame({
            "language": ["Python", "Sin especificar", "LLMs/AI", "AI/ML"],
            "repo_name": ["a", "b", "c", "d"],
        })

        with patch("trend_score.pd.read_csv", return_value=sample):
            result = cargar_github()

        assert not result.empty
        assert "Python" in result["tecnologia"].tolist()
        assert "Sin Especificar" not in result["tecnologia"].tolist()
        assert "Llms/Ai" not in result["tecnologia"].tolist()
        assert "Ai/Ml" not in result["tecnologia"].tolist()
