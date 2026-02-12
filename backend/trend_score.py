"""
Trend Score Generator - Technology Trend Analysis Platform

Combines data from GitHub, StackOverflow, and Reddit to produce
a unified technology ranking. The composite score uses weighted
metrics from each source.

Formula:
    Trend Score = (peso_github × github_score) +
                  (peso_so × so_score) +
                  (peso_reddit × reddit_score)

Author: Technology Trend Analysis Platform Team
"""
import pandas as pd
import numpy as np
import logging
from datetime import datetime

from config.settings import (
    ARCHIVOS_SALIDA, LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR
)
from validador import validar_dataframe

# Logger para este modulo
logger = logging.getLogger("trend_score")

# Pesos para cada fuente de datos
PESOS = {
    "github": 0.40,
    "stackoverflow": 0.35,
    "reddit": 0.25
}


def configurar_logging():
    """Sets up logging to console and daily log file."""
    logger.setLevel(logging.INFO)

    if logger.handlers:
        return

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(console)

    fecha = datetime.now().strftime("%Y-%m-%d")
    archivo = LOGS_DIR / f"etl_{fecha}.log"
    file_handler = logging.FileHandler(archivo, encoding="utf-8")
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(file_handler)


def normalizar_nombre(nombre):
    """Normalizes technology names for cross-source comparison.

    Args:
        nombre: Raw technology name from any source.

    Returns:
        Normalized lowercase name.
    """
    mapeo = {
        "python": "Python",
        "javascript": "JavaScript",
        "typescript": "TypeScript",
        "java": "Java",
        "go": "Go",
        "rust": "Rust",
        "c#": "C#",
        "c++": "C++",
        "ruby": "Ruby",
        "php": "PHP",
        "swift": "Swift",
        "kotlin": "Kotlin",
        "reactjs": "React",
        "react": "React",
        "vue.js": "Vue.js",
        "vue 3": "Vue.js",
        "angular": "Angular",
        "next.js": "Next.js",
        "svelte": "Svelte",
        "django": "Django",
        "fastapi": "FastAPI",
        "express": "Express",
        "spring": "Spring",
        "laravel": "Laravel",
        "ia/machine learning": "AI/ML",
        "cloud": "Cloud",
        "devops": "DevOps",
        "microservicios": "Microservices",
        "testing": "Testing",
        "performance": "Performance",
        "seguridad": "Security",
        "web3/blockchain": "Web3",
    }

    nombre_lower = nombre.strip().lower()
    return mapeo.get(nombre_lower, nombre.strip().title())


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
        langs = df_repos["language"].value_counts().head(15).reset_index()
        langs.columns = ["tecnologia", "repos_count"]
        langs["tecnologia"] = langs["tecnologia"].apply(normalizar_nombre)
        langs["github_score"] = normalizar_scores(langs["repos_count"])
        logger.info(f"GitHub: {len(langs)} tecnologias cargadas")
        return langs[["tecnologia", "github_score"]]
    except FileNotFoundError:
        logger.warning("No se encontro github_repos_2025.csv")
        return pd.DataFrame(columns=["tecnologia", "github_score"])
    except Exception as e:
        logger.error(f"Error procesando datos de GitHub: {e}")
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
        logger.info(f"StackOverflow: {len(df_vol)} tecnologias cargadas")
        return df_vol[["tecnologia", "so_score"]]
    except FileNotFoundError:
        logger.warning("No se encontro so_volumen_preguntas.csv")
        return pd.DataFrame(columns=["tecnologia", "so_score"])
    except Exception as e:
        logger.error(f"Error procesando datos de StackOverflow: {e}")
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
        logger.info(f"Reddit: {len(df_temas)} tecnologias cargadas")
        return df_temas[["tecnologia", "reddit_score"]]
    except FileNotFoundError:
        logger.warning("No se encontro reddit_temas_emergentes.csv")
        return pd.DataFrame(columns=["tecnologia", "reddit_score"])
    except Exception as e:
        logger.error(f"Error procesando datos de Reddit: {e}")
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
    logger.info(f"Pesos: GitHub={PESOS['github']}, SO={PESOS['stackoverflow']}, Reddit={PESOS['reddit']}")

    # Cargar datos de cada fuente
    df_github = cargar_github()
    df_so = cargar_stackoverflow()
    df_reddit = cargar_reddit()

    # Combinar todas las tecnologias (outer join)
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

    # Rellenar NaN con 0 (tecnologia no encontrada en esa fuente)
    for col in ["github_score", "so_score", "reddit_score"]:
        if col not in df_combined.columns:
            df_combined[col] = 0.0
        else:
            df_combined[col] = df_combined[col].fillna(0.0)

    # Calcular score compuesto
    df_combined["trend_score"] = (
        PESOS["github"] * df_combined["github_score"] +
        PESOS["stackoverflow"] * df_combined["so_score"] +
        PESOS["reddit"] * df_combined["reddit_score"]
    ).round(2)

    # Ordenar por trend_score y agregar ranking
    df_combined = df_combined.sort_values("trend_score", ascending=False).reset_index(drop=True)
    df_combined["ranking"] = range(1, len(df_combined) + 1)

    # Contar en cuantas fuentes aparece cada tecnologia
    df_combined["fuentes"] = (
        (df_combined["github_score"] > 0).astype(int) +
        (df_combined["so_score"] > 0).astype(int) +
        (df_combined["reddit_score"] > 0).astype(int)
    )

    # Log del ranking
    logger.info(f"\nTrend Score - Top Tecnologias ({len(df_combined)} total):")
    logger.info(f"{'#':>3} {'Tecnologia':<20} {'GitHub':>8} {'SO':>8} {'Reddit':>8} {'Score':>8} {'Fuentes':>8}")
    logger.info("-" * 75)

    for _, row in df_combined.head(15).iterrows():
        logger.info(
            f"#{row['ranking']:>2} {row['tecnologia']:<20} "
            f"{row['github_score']:>7.1f} {row['so_score']:>7.1f} "
            f"{row['reddit_score']:>7.1f} {row['trend_score']:>7.1f} "
            f"{int(row['fuentes']):>5}/3"
        )

    return df_combined


def main():
    """Main function that generates the Trend Score CSV."""
    configurar_logging()

    logger.info("Trend Score Generator - Technology Trend Analysis Platform")
    logger.info(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    df_trend = calcular_trend_score()

    if df_trend.empty:
        logger.error("No se pudo generar Trend Score")
        return

    # Guardar resultado
    columnas_salida = [
        "ranking", "tecnologia", "github_score",
        "so_score", "reddit_score", "trend_score", "fuentes"
    ]
    df_salida = df_trend[columnas_salida]

    validar_dataframe(df_salida, "trend_score")
    df_salida.to_csv(ARCHIVOS_SALIDA["trend_score"], index=False, encoding="utf-8")
    logger.info(f"Trend Score guardado en: {ARCHIVOS_SALIDA['trend_score']}")

    # Resumen
    top3 = df_salida.head(3)
    logger.info(f"\nTop 3 tecnologias trending:")
    for _, row in top3.iterrows():
        logger.info(f"  #{int(row['ranking'])}. {row['tecnologia']} (Score: {row['trend_score']})")

    logger.info("Trend Score completado")


if __name__ == "__main__":
    main()
