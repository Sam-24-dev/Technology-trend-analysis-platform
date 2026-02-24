import pandas as pd

from trend_score import calculate_trend_score_legacy
from trend_score_duckdb import calcular_trend_score_duckdb


PESOS = {
    "github": 0.40,
    "stackoverflow": 0.35,
    "reddit": 0.25,
}


def _sample_sources():
    df_github = pd.DataFrame(
        {
            "tecnologia": [
                "Python",
                "TypeScript",
                "JavaScript",
                "Go",
                "Rust",
                "Java",
                "C#",
                "PHP",
                "Kotlin",
                "Swift",
                "Ruby",
                "Dart",
            ],
            "github_score": [100, 82, 77, 51, 44, 39, 33, 29, 26, 22, 19, 17],
        }
    )
    df_so = pd.DataFrame(
        {
            "tecnologia": [
                "Python",
                "TypeScript",
                "JavaScript",
                "Go",
                "Java",
                "C#",
                "PHP",
                "Ruby",
                "Scala",
                "Elixir",
            ],
            "so_score": [100, 76, 72, 45, 52, 35, 31, 20, 15, 11],
        }
    )
    df_reddit = pd.DataFrame(
        {
            "tecnologia": [
                "Python",
                "TypeScript",
                "JavaScript",
                "Rust",
                "Go",
                "Kubernetes",
                "DevOps",
                "AI/ML",
                "Cloud",
                "Dart",
            ],
            "reddit_score": [95, 70, 68, 50, 47, 30, 27, 45, 25, 22],
        }
    )
    return df_github, df_so, df_reddit


def _compare_scores(df_legacy, df_duckdb):
    merged = df_legacy.merge(
        df_duckdb,
        on="tecnologia",
        how="inner",
        suffixes=("_legacy", "_duckdb"),
    )
    merged["score_abs_diff"] = (merged["trend_score_legacy"] - merged["trend_score_duckdb"]).abs()
    return merged


def test_equivalence_score_abs_error_threshold():
    df_github, df_so, df_reddit = _sample_sources()
    legacy = calculate_trend_score_legacy(df_github, df_so, df_reddit)
    duckdb = calcular_trend_score_duckdb(df_github, df_so, df_reddit, PESOS)

    comparison = _compare_scores(legacy, duckdb)
    assert not comparison.empty
    assert (comparison["score_abs_diff"] <= 0.01).all()


def test_equivalence_top10_overlap_threshold():
    df_github, df_so, df_reddit = _sample_sources()
    legacy = calculate_trend_score_legacy(df_github, df_so, df_reddit)
    duckdb = calcular_trend_score_duckdb(df_github, df_so, df_reddit, PESOS)

    top10_legacy = set(legacy.head(10)["tecnologia"])
    top10_duckdb = set(duckdb.head(10)["tecnologia"])
    overlap = len(top10_legacy.intersection(top10_duckdb)) / 10.0
    assert overlap >= 0.90


def test_equivalence_ranking_delta_threshold():
    df_github, df_so, df_reddit = _sample_sources()
    legacy = calculate_trend_score_legacy(df_github, df_so, df_reddit)
    duckdb = calcular_trend_score_duckdb(df_github, df_so, df_reddit, PESOS)

    comparison = _compare_scores(legacy, duckdb)
    comparison["ranking_delta"] = (comparison["ranking_legacy"] - comparison["ranking_duckdb"]).abs()
    pct_within_delta_1 = (comparison["ranking_delta"] <= 1).sum() / len(comparison)
    assert pct_within_delta_1 >= 0.90
