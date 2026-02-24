"""Trend Score generator for the Technology Trend Analysis Platform."""

import logging
import os
from datetime import datetime

import pandas as pd

from base_etl import BaseETL
from config.settings import ARCHIVOS_SALIDA
from exceptions import ETLExtractionError
from tech_normalization import normalize_technology_name
from trend_score_duckdb import calcular_trend_score_duckdb
from validador import validar_dataframe

logger = logging.getLogger("trend_score")

PESOS = {
    "github": 0.40,
    "stackoverflow": 0.35,
    "reddit": 0.25,
}

TREND_ENGINES = {"legacy", "duckdb"}

ETIQUETAS_NO_LENGUAJE = {
    "sin especificar",
    "llms/ai",
    "ai/ml",
    "ai",
    "llm",
    "genai",
    "artificial intelligence",
}


def normalizar_nombre(nombre):
    """Normalizes technology names for cross-source comparison."""
    return normalize_technology_name(nombre)


def normalizar_scores(serie):
    """Normalizes a numeric series to 0-100 scale using min-max."""
    if serie.max() == serie.min():
        return pd.Series([50.0] * len(serie), index=serie.index)

    return ((serie - serie.min()) / (serie.max() - serie.min()) * 100).round(2)


def cargar_github():
    """Loads and processes GitHub data for scoring."""
    try:
        df_repos = pd.read_csv(ARCHIVOS_SALIDA["github_repos"])
        df_repos["language"] = df_repos["language"].fillna("Sin especificar").astype(str).str.strip()
        df_repos = df_repos[~df_repos["language"].str.lower().isin(ETIQUETAS_NO_LENGUAJE)]

        if df_repos.empty:
            logger.warning("GitHub: no classifiable languages after filters")
            return pd.DataFrame(columns=["tecnologia", "github_score"])

        langs = df_repos["language"].value_counts().head(15).reset_index()
        langs.columns = ["tecnologia", "repos_count"]
        langs["tecnologia"] = langs["tecnologia"].apply(normalizar_nombre)
        langs["github_score"] = normalizar_scores(langs["repos_count"])
        logger.info("GitHub: %d technologies loaded", len(langs))
        return langs[["tecnologia", "github_score"]]
    except FileNotFoundError:
        logger.warning("github_repos_2025.csv was not found")
        return pd.DataFrame(columns=["tecnologia", "github_score"])
    except (KeyError, ValueError) as exc:
        logger.error("Error processing GitHub data: %s", exc)
        return pd.DataFrame(columns=["tecnologia", "github_score"])


def cargar_stackoverflow():
    """Loads and processes StackOverflow data for scoring."""
    try:
        df_vol = pd.read_csv(ARCHIVOS_SALIDA["so_volumen"])
        df_vol["tecnologia"] = df_vol["lenguaje"].apply(normalizar_nombre)
        df_vol["so_score"] = normalizar_scores(df_vol["preguntas_nuevas_2025"])
        logger.info("StackOverflow: %d technologies loaded", len(df_vol))
        return df_vol[["tecnologia", "so_score"]]
    except FileNotFoundError:
        logger.warning("so_volumen_preguntas.csv was not found")
        return pd.DataFrame(columns=["tecnologia", "so_score"])
    except (KeyError, ValueError) as exc:
        logger.error("Error processing StackOverflow data: %s", exc)
        return pd.DataFrame(columns=["tecnologia", "so_score"])


def cargar_reddit():
    """Loads and processes Reddit data for scoring."""
    try:
        df_temas = pd.read_csv(ARCHIVOS_SALIDA["reddit_temas"])
        df_temas["tecnologia"] = df_temas["tema"].apply(normalizar_nombre)
        df_temas["reddit_score"] = normalizar_scores(df_temas["menciones"])
        logger.info("Reddit: %d technologies loaded", len(df_temas))
        return df_temas[["tecnologia", "reddit_score"]]
    except FileNotFoundError:
        logger.warning("reddit_temas_emergentes.csv was not found")
        return pd.DataFrame(columns=["tecnologia", "reddit_score"])
    except (KeyError, ValueError) as exc:
        logger.error("Error processing Reddit data: %s", exc)
        return pd.DataFrame(columns=["tecnologia", "reddit_score"])


def _load_score_sources():
    df_github = cargar_github()
    df_so = cargar_stackoverflow()
    df_reddit = cargar_reddit()
    return df_github, df_so, df_reddit


def _build_legacy_trend_score(df_github, df_so, df_reddit):
    """Builds Trend Score with the legacy pandas merge strategy."""
    df_combined = pd.DataFrame({"tecnologia": []})

    if not df_github.empty:
        df_combined = pd.merge(df_combined, df_github, on="tecnologia", how="outer")
    if not df_so.empty:
        df_combined = pd.merge(df_combined, df_so, on="tecnologia", how="outer")
    if not df_reddit.empty:
        df_combined = pd.merge(df_combined, df_reddit, on="tecnologia", how="outer")

    if df_combined.empty:
        logger.error("No data from any source to calculate Trend Score")
        return pd.DataFrame()

    for col in ["github_score", "so_score", "reddit_score"]:
        if col not in df_combined.columns:
            df_combined[col] = 0.0
        else:
            df_combined[col] = df_combined[col].fillna(0.0)

    df_combined["trend_score"] = (
        PESOS["github"] * df_combined["github_score"]
        + PESOS["stackoverflow"] * df_combined["so_score"]
        + PESOS["reddit"] * df_combined["reddit_score"]
    ).round(2)

    df_combined = df_combined.sort_values("trend_score", ascending=False).reset_index(drop=True)
    df_combined["ranking"] = range(1, len(df_combined) + 1)

    df_combined["fuentes"] = (
        (df_combined["github_score"] > 0).astype(int)
        + (df_combined["so_score"] > 0).astype(int)
        + (df_combined["reddit_score"] > 0).astype(int)
    )

    return df_combined[
        ["ranking", "tecnologia", "github_score", "so_score", "reddit_score", "trend_score", "fuentes"]
    ]


def calculate_trend_score_legacy(df_github, df_so, df_reddit):
    """Public helper to compute trend score with the legacy engine."""
    return _build_legacy_trend_score(df_github, df_so, df_reddit)


def resolve_trend_engine(engine=None):
    """Resolves the Trend Score engine from explicit input or environment."""
    resolved = str(engine or os.getenv("TREND_SCORE_ENGINE", "legacy")).strip().lower()
    if resolved not in TREND_ENGINES:
        logger.warning("Unknown trend engine '%s'. Falling back to 'legacy'.", resolved)
        return "legacy"
    return resolved


def _log_ranking_preview(df_combined):
    logger.info("\nTrend Score - Top Technologies (%d total):", len(df_combined))
    logger.info("%3s %-20s %8s %8s %8s %8s %8s", "#", "Technology", "GitHub", "SO", "Reddit", "Score", "Sources")
    logger.info("-" * 75)

    for _, row in df_combined.head(15).iterrows():
        logger.info(
            "#%2d %-20s %7.1f %7.1f %7.1f %7.1f %5d/3",
            row["ranking"],
            row["tecnologia"],
            row["github_score"],
            row["so_score"],
            row["reddit_score"],
            row["trend_score"],
            int(row["fuentes"]),
        )


def calcular_trend_score(engine=None):
    """Calculates the composite Trend Score for all technologies."""
    logger.info("Calculating composite Trend Score...")
    logger.info("Weights: GitHub=%s, SO=%s, Reddit=%s", PESOS["github"], PESOS["stackoverflow"], PESOS["reddit"])

    df_github, df_so, df_reddit = _load_score_sources()

    if df_github.empty and df_so.empty and df_reddit.empty:
        logger.error("No data from any source to calculate Trend Score")
        return pd.DataFrame()

    engine_name = resolve_trend_engine(engine)
    logger.info("Trend engine selected: %s", engine_name)

    if engine_name == "duckdb":
        try:
            df_result = calcular_trend_score_duckdb(
                df_github=df_github,
                df_so=df_so,
                df_reddit=df_reddit,
                pesos=PESOS,
            )
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.error("DuckDB engine failed (%s). Falling back to legacy engine.", exc)
            df_result = _build_legacy_trend_score(df_github, df_so, df_reddit)
    else:
        df_result = _build_legacy_trend_score(df_github, df_so, df_reddit)

    if df_result.empty:
        return df_result

    _log_ranking_preview(df_result)
    return df_result


def main():
    """Main function that generates the Trend Score CSV."""
    etl = TrendScoreETL()
    etl.ejecutar()


class TrendScoreETL(BaseETL):
    """ETL adapter for Trend Score under the BaseETL contract."""

    def __init__(self):
        super().__init__("trend_score")

    def definir_pasos(self):
        return [("Calculate Trend Score", self._calcular_y_guardar)]

    def _calcular_y_guardar(self):
        self.logger.info("Trend Score Generator - Technology Trend Analysis Platform")
        self.logger.info("Execution date: %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

        try:
            df_trend = calcular_trend_score()
            if df_trend.empty:
                raise ETLExtractionError(
                    "Trend Score could not be generated (no data from any source)",
                    critical=True,
                )

            columnas_salida = [
                "ranking",
                "tecnologia",
                "github_score",
                "so_score",
                "reddit_score",
                "trend_score",
                "fuentes",
            ]
            df_salida = df_trend[columnas_salida]

            validar_dataframe(df_salida, "trend_score")
            self.guardar_csv(df_salida, "trend_score")

            top3 = df_salida.head(3)
            self.logger.info("\nTop 3 trending technologies:")
            for _, row in top3.iterrows():
                self.logger.info(
                    "  #%d. %s (Score: %s)",
                    int(row["ranking"]),
                    row["tecnologia"],
                    row["trend_score"],
                )

            self.logger.info("Trend Score completed")
        except ETLExtractionError:
            raise
        except Exception as exc:  # pylint: disable=broad-exception-caught
            raise ETLExtractionError(f"Fatal error in Trend Score: {exc}", critical=True) from exc


if __name__ == "__main__":
    main()
