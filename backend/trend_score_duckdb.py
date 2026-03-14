"""Motor DuckDB para el cálculo de Trend Score."""

from __future__ import annotations

import pandas as pd

try:
    import duckdb
except Exception:  # pylint: disable=broad-exception-caught
    duckdb = None


def calcular_trend_score_duckdb(df_github, df_so, df_reddit, pesos):
    """Calcula Trend Score usando SQL de DuckDB sobre DataFrames en memoria."""
    if duckdb is None:
        raise RuntimeError("DuckDB engine is unavailable. Install 'duckdb' to use this engine.")

    github_scores = (
        df_github[["tecnologia", "github_score"]].copy()
        if not df_github.empty
        else pd.DataFrame(columns=["tecnologia", "github_score"])
    )
    so_scores = (
        df_so[["tecnologia", "so_score"]].copy()
        if not df_so.empty
        else pd.DataFrame(columns=["tecnologia", "so_score"])
    )
    reddit_scores = (
        df_reddit[["tecnologia", "reddit_score"]].copy()
        if not df_reddit.empty
        else pd.DataFrame(columns=["tecnologia", "reddit_score"])
    )

    connection = duckdb.connect(database=":memory:")
    try:
        connection.register("github_scores", github_scores)
        connection.register("so_scores", so_scores)
        connection.register("reddit_scores", reddit_scores)

        query = f"""
            WITH merged AS (
                SELECT
                    COALESCE(g.tecnologia, s.tecnologia, r.tecnologia) AS tecnologia,
                    COALESCE(g.github_score, 0.0) AS github_score,
                    COALESCE(s.so_score, 0.0) AS so_score,
                    COALESCE(r.reddit_score, 0.0) AS reddit_score
                FROM github_scores g
                FULL OUTER JOIN so_scores s
                    ON g.tecnologia = s.tecnologia
                FULL OUTER JOIN reddit_scores r
                    ON COALESCE(g.tecnologia, s.tecnologia) = r.tecnologia
            ),
            scored AS (
                SELECT
                    tecnologia,
                    github_score,
                    so_score,
                    reddit_score,
                    ROUND((
                        {pesos['github']} * github_score +
                        {pesos['stackoverflow']} * so_score +
                        {pesos['reddit']} * reddit_score
                    ), 2) AS trend_score,
                    (
                        CASE WHEN github_score > 0 THEN 1 ELSE 0 END +
                        CASE WHEN so_score > 0 THEN 1 ELSE 0 END +
                        CASE WHEN reddit_score > 0 THEN 1 ELSE 0 END
                    ) AS fuentes
                FROM merged
            ),
            ranked AS (
                SELECT
                    ROW_NUMBER() OVER (ORDER BY trend_score DESC, tecnologia ASC) AS ranking,
                    tecnologia,
                    github_score,
                    so_score,
                    reddit_score,
                    trend_score,
                    fuentes
                FROM scored
                WHERE trend_score > 0
            )
            SELECT
                ranking,
                tecnologia,
                github_score,
                so_score,
                reddit_score,
                trend_score,
                fuentes
            FROM ranked
            ORDER BY ranking
        """

        return connection.execute(query).df()
    finally:
        connection.close()
