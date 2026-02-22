"""
Trend Score Generator - Technology Trend Analysis Platform

Combines data from GitHub, StackOverflow, and Reddit to produce
a unified technology ranking. The composite score uses weighted
metrics from each source.

Formula:
    Trend Score = (peso_github × github_score) +
                  (peso_so × so_score) +
                  (peso_reddit × reddit_score)

Author: Samir Caizapasto
"""
import pandas as pd
import logging
from datetime import datetime

from config.settings import (
    ARCHIVOS_SALIDA,
)
from validador import validar_dataframe
from base_etl import BaseETL
from exceptions import ETLExtractionError
from tech_normalization import normalize_technology_name

logger = logging.getLogger("trend_score")

# Weights per data source
PESOS = {
    "github": 0.40,
    "stackoverflow": 0.35,
    "reddit": 0.25
}

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
    """Normalizes technology names for cross-source comparison.

    Args:
        nombre: Raw technology name from any source.

    Returns:
        Normalized lowercase name.
    """
    return normalize_technology_name(nombre)


def normalizar_scores(serie):
    """Normalizes a numeric series to 0-100 scale using min-max.

    Args:
        serie: pandas Series with numeric values.

    Returns:
        Normalized series (0-100).
    """
    if serie.max() == serie.min():
        return pd.Series([50.0] * len(serie), index=serie.index)

    return ((serie - serie.min()) / (serie.max() - serie.min()) * 100).round(2)


def cargar_github():
    """Loads and processes GitHub data for scoring.

    Returns:
        DataFrame with columns: [tecnologia, github_score]
    """
    try:
        df_repos = pd.read_csv(ARCHIVOS_SALIDA["github_repos"])
        df_repos["language"] = df_repos["language"].fillna("Sin especificar").astype(str).str.strip()
        df_repos = df_repos[~df_repos["language"].str.lower().isin(ETIQUETAS_NO_LENGUAJE)]

        if df_repos.empty:
            logger.warning("GitHub: sin lenguajes clasificables tras aplicar filtros")
            return pd.DataFrame(columns=["tecnologia", "github_score"])

        langs = df_repos["language"].value_counts().head(15).reset_index()
        langs.columns = ["tecnologia", "repos_count"]
        langs["tecnologia"] = langs["tecnologia"].apply(normalizar_nombre)
        langs["github_score"] = normalizar_scores(langs["repos_count"])
        logger.info("GitHub: %d tecnologias cargadas", len(langs))
        return langs[["tecnologia", "github_score"]]
    except FileNotFoundError:
        logger.warning("No se encontro github_repos_2025.csv")
        return pd.DataFrame(columns=["tecnologia", "github_score"])
    except (KeyError, ValueError) as e:
        logger.error("Error procesando datos de GitHub: %s", e)
        return pd.DataFrame(columns=["tecnologia", "github_score"])


def cargar_stackoverflow():
    """Loads and processes StackOverflow data for scoring.

    Returns:
        DataFrame with columns: [tecnologia, so_score]
    """
    try:
        df_vol = pd.read_csv(ARCHIVOS_SALIDA["so_volumen"])
        df_vol["tecnologia"] = df_vol["lenguaje"].apply(normalizar_nombre)
        df_vol["so_score"] = normalizar_scores(df_vol["preguntas_nuevas_2025"])
        logger.info("StackOverflow: %d tecnologias cargadas", len(df_vol))
        return df_vol[["tecnologia", "so_score"]]
    except FileNotFoundError:
        logger.warning("No se encontro so_volumen_preguntas.csv")
        return pd.DataFrame(columns=["tecnologia", "so_score"])
    except (KeyError, ValueError) as e:
        logger.error("Error procesando datos de StackOverflow: %s", e)
        return pd.DataFrame(columns=["tecnologia", "so_score"])


def cargar_reddit():
    """Loads and processes Reddit data for scoring.

    Returns:
        DataFrame with columns: [tecnologia, reddit_score]
    """
    try:
        df_temas = pd.read_csv(ARCHIVOS_SALIDA["reddit_temas"])
        df_temas["tecnologia"] = df_temas["tema"].apply(normalizar_nombre)
        df_temas["reddit_score"] = normalizar_scores(df_temas["menciones"])
        logger.info("Reddit: %d tecnologias cargadas", len(df_temas))
        return df_temas[["tecnologia", "reddit_score"]]
    except FileNotFoundError:
        logger.warning("No se encontro reddit_temas_emergentes.csv")
        return pd.DataFrame(columns=["tecnologia", "reddit_score"])
    except (KeyError, ValueError) as e:
        logger.error("Error procesando datos de Reddit: %s", e)
        return pd.DataFrame(columns=["tecnologia", "reddit_score"])


def calcular_trend_score():
    """Calculates the composite Trend Score for all technologies.

    Combines normalized scores from GitHub, StackOverflow, and Reddit
    using weighted average. Technologies not found in a source get
    a score of 0 for that source.

    Returns:
        DataFrame with columns: [tecnologia, github_score, so_score,
                                  reddit_score, trend_score, ranking]
    """
    logger.info("Calculando Trend Score compuesto...")
    logger.info("Pesos: GitHub=%s, SO=%s, Reddit=%s", PESOS['github'], PESOS['stackoverflow'], PESOS['reddit'])

    # Load data from each source
    df_github = cargar_github()
    df_so = cargar_stackoverflow()
    df_reddit = cargar_reddit()

    # Combine all technologies (outer join)
    df_combined = pd.DataFrame({"tecnologia": []})

    if not df_github.empty:
        df_combined = pd.merge(df_combined, df_github, on="tecnologia", how="outer")
    if not df_so.empty:
        df_combined = pd.merge(df_combined, df_so, on="tecnologia", how="outer")
    if not df_reddit.empty:
        df_combined = pd.merge(df_combined, df_reddit, on="tecnologia", how="outer")

    if df_combined.empty:
        logger.error("No hay datos de ninguna fuente para calcular Trend Score")
        return pd.DataFrame()

    # Fill NaN with 0 (technology not present in that source)
    for col in ["github_score", "so_score", "reddit_score"]:
        if col not in df_combined.columns:
            df_combined[col] = 0.0
        else:
            df_combined[col] = df_combined[col].fillna(0.0)

    # Calculate composite score
    df_combined["trend_score"] = (
        PESOS["github"] * df_combined["github_score"] +
        PESOS["stackoverflow"] * df_combined["so_score"] +
        PESOS["reddit"] * df_combined["reddit_score"]
    ).round(2)

    # Sort by trend_score and add ranking
    df_combined = df_combined.sort_values("trend_score", ascending=False).reset_index(drop=True)
    df_combined["ranking"] = range(1, len(df_combined) + 1)

    # Count how many sources each technology appears in
    df_combined["fuentes"] = (
        (df_combined["github_score"] > 0).astype(int) +
        (df_combined["so_score"] > 0).astype(int) +
        (df_combined["reddit_score"] > 0).astype(int)
    )

    # Ranking log
    logger.info("\nTrend Score - Top Tecnologias (%d total):", len(df_combined))
    logger.info("%3s %-20s %8s %8s %8s %8s %8s", "#", "Tecnologia", "GitHub", "SO", "Reddit", "Score", "Fuentes")
    logger.info("-" * 75)

    for _, row in df_combined.head(15).iterrows():
        logger.info(
            "#%2d %-20s %7.1f %7.1f %7.1f %7.1f %5d/3",
            row['ranking'], row['tecnologia'],
            row['github_score'], row['so_score'],
            row['reddit_score'], row['trend_score'],
            int(row['fuentes'])
        )

    return df_combined


def main():
    """Main function that generates the Trend Score CSV."""
    etl = TrendScoreETL()
    etl.ejecutar()


class TrendScoreETL(BaseETL):
    """ETL adapter for Trend Score using the BaseETL contract.

    Keeps the existing behavior without over-engineering: a single step
    that computes, validates, and persists the trend score CSV.
    """

    def __init__(self):
        super().__init__("trend_score")

    def definir_pasos(self):
        return [("Calcular Trend Score", self._calcular_y_guardar)]

    def _calcular_y_guardar(self):
        self.logger.info("Trend Score Generator - Technology Trend Analysis Platform")
        self.logger.info("Fecha: %s", datetime.now().strftime('%Y-%m-%d %H:%M:%S'))

        try:
            df_trend = calcular_trend_score()
            if df_trend.empty:
                raise ETLExtractionError(
                    "No se pudo generar Trend Score (sin datos de ninguna fuente)",
                    critical=True,
                )

            columnas_salida = [
                "ranking", "tecnologia", "github_score",
                "so_score", "reddit_score", "trend_score", "fuentes"
            ]
            df_salida = df_trend[columnas_salida]

            # Keep explicit contract validation and uniform write path
            validar_dataframe(df_salida, "trend_score")
            self.guardar_csv(df_salida, "trend_score")

            top3 = df_salida.head(3)
            self.logger.info("\nTop 3 tecnologias trending:")
            for _, row in top3.iterrows():
                self.logger.info(
                    "  #%d. %s (Score: %s)",
                    int(row['ranking']), row['tecnologia'], row['trend_score']
                )

            self.logger.info("Trend Score completado")
        except ETLExtractionError:
            raise
        except Exception as e:  # pylint: disable=broad-exception-caught
            raise ETLExtractionError(f"Error fatal en Trend Score: {e}", critical=True) from e


if __name__ == "__main__":
    main()
