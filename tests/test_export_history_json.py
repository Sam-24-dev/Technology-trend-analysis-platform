import json

import export_history_json


def test_export_bridge_assets_generates_history_and_trend_json(tmp_path):
    project_root = tmp_path
    history_dir = project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=02" / "day=22"
    so_history_dir = project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=07"
    acceptance_history_dir = (
        project_root / "datos" / "history" / "so_aceptacion" / "year=2026" / "month=03" / "day=07"
    )
    latest_dir = project_root / "datos" / "latest"

    history_dir.mkdir(parents=True, exist_ok=True)
    so_history_dir.mkdir(parents=True, exist_ok=True)
    acceptance_history_dir.mkdir(parents=True, exist_ok=True)
    latest_dir.mkdir(parents=True, exist_ok=True)
    (project_root / "frontend" / "assets" / "data").mkdir(parents=True, exist_ok=True)

    trend_csv_content = (
        "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
        "1,Python,100,100,5.8,76.45,3\n"
        "2,TypeScript,70.7,17.7,1.0,34.74,3\n"
    )
    (history_dir / "trend_score.csv").write_text(trend_csv_content, encoding="utf-8")
    (latest_dir / "trend_score.csv").write_text(trend_csv_content, encoding="utf-8")
    (so_history_dir / "so_volumen_preguntas.csv").write_text(
        "lenguaje,preguntas_nuevas_2025\npython,100\njavascript,80\n",
        encoding="utf-8",
    )
    (latest_dir / "so_volumen_preguntas.csv").write_text(
        "lenguaje,preguntas_nuevas_2025\npython,100\njavascript,80\n",
        encoding="utf-8",
    )
    (acceptance_history_dir / "so_tasa_aceptacion.csv").write_text(
        (
            "tecnologia,total_preguntas,respuestas_aceptadas,tasa_aceptacion_pct\n"
            "angular,1000,800,80.0\n"
            "svelte,10,9,90.0\n"
        ),
        encoding="utf-8",
    )
    (latest_dir / "so_tasa_aceptacion.csv").write_text(
        (
            "tecnologia,total_preguntas,respuestas_aceptadas,tasa_aceptacion_pct\n"
            "angular,1000,800,80.0\n"
            "svelte,10,9,90.0\n"
        ),
        encoding="utf-8",
    )

    summary = export_history_json.export_bridge_assets(project_root)

    assert summary["files_written"] == 13
    history_index = project_root / "frontend" / "assets" / "data" / "history_index.json"
    trend_history = project_root / "frontend" / "assets" / "data" / "trend_score_history.json"
    reddit_sentiment = project_root / "frontend" / "assets" / "data" / "reddit_sentimiento_public.json"
    reddit_topics_history = project_root / "frontend" / "assets" / "data" / "reddit_temas_history.json"
    reddit_intersection_history = project_root / "frontend" / "assets" / "data" / "reddit_interseccion_history.json"
    github_languages_public = project_root / "frontend" / "assets" / "data" / "github_lenguajes_public.json"
    github_frameworks_history = project_root / "frontend" / "assets" / "data" / "github_frameworks_history.json"
    github_correlation_history = project_root / "frontend" / "assets" / "data" / "github_correlacion_history.json"
    home_highlights = project_root / "frontend" / "assets" / "data" / "home_highlights.json"
    so_volume_history = project_root / "frontend" / "assets" / "data" / "so_volumen_history.json"
    so_acceptance_history = project_root / "frontend" / "assets" / "data" / "so_aceptacion_history.json"
    so_trends_history = project_root / "frontend" / "assets" / "data" / "so_tendencias_history.json"
    technology_profiles = project_root / "frontend" / "assets" / "data" / "technology_profiles.json"

    assert history_index.exists()
    assert trend_history.exists()
    assert reddit_sentiment.exists()
    assert reddit_topics_history.exists()
    assert reddit_intersection_history.exists()
    assert github_languages_public.exists()
    assert github_frameworks_history.exists()
    assert github_correlation_history.exists()
    assert home_highlights.exists()
    assert so_volume_history.exists()
    assert so_acceptance_history.exists()
    assert so_trends_history.exists()
    assert technology_profiles.exists()

    history_payload = json.loads(history_index.read_text(encoding="utf-8"))
    trend_payload = json.loads(trend_history.read_text(encoding="utf-8"))

    assert history_payload["dataset_count"] >= 1
    assert any(dataset["dataset"] == "trend_score" for dataset in history_payload["datasets"])
    assert any(dataset["dataset"] == "so_volumen" for dataset in history_payload["datasets"])
    assert any(dataset["dataset"] == "so_aceptacion" for dataset in history_payload["datasets"])
    assert trend_payload["snapshot_count"] == 1
    assert trend_payload["snapshots"][0]["source_type"] == "history"
    assert trend_payload["snapshots"][0]["top_10"][0]["tecnologia"] == "Python"
    assert trend_payload["snapshots"][0]["top_10"][0]["github_score"] == 100.0
    assert trend_payload["snapshots"][0]["top_10"][0]["available_source_codes"] == ["GH", "SO", "RD"]


def test_build_so_volume_history_adds_growth_share_and_summary(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=06"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=07"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "python,100\n"
            "javascript,80\n"
            "go,50\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "python,120\n"
            "javascript,70\n"
            "go,50\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_volume_history(project_root, history_index)

    assert payload["dataset"] == "so_volumen_preguntas"
    assert payload["snapshot_count"] == 2
    assert payload["latest_snapshot_date"] == "2026-03-07"
    assert payload["previous_snapshot_date"] == "2026-03-06"
    assert payload["has_historical_comparison"] is True
    assert payload["item_count"] == 3
    assert payload["summary"]["total_questions"] == 240
    assert payload["summary"]["leader"]["lenguaje"] == "python"
    assert payload["summary"]["highest_growth"]["lenguaje"] == "python"
    assert payload["summary"]["largest_drop"]["lenguaje"] == "javascript"

    python_item = next(item for item in payload["latest_items"] if item["lenguaje"] == "python")
    assert python_item["preguntas"] == 120
    assert python_item["preguntas_prev"] == 100
    assert python_item["delta_preguntas"] == 20
    assert python_item["growth_pct"] == 20.0
    assert python_item["trend_direction"] == "creciendo"
    assert python_item["share_pct"] == 50.0

    javascript_item = next(item for item in payload["latest_items"] if item["lenguaje"] == "javascript")
    assert javascript_item["delta_preguntas"] == -10
    assert javascript_item["trend_direction"] == "cayendo"


def test_compact_frontend_payload_preserves_full_so_trends_points_only():
    so_payload = {
        "dataset": "so_tendencias_mensuales",
        "snapshot_count": 15,
        "months": ["2025-03", "2025-04", "2025-05", "2025-06"],
        "series": [
            {
                "tecnologia": "Python",
                "points": [2056, 1659, 1374, 1022],
            }
        ],
    }
    other_payload = {
        "dataset": "github_correlacion",
        "series": [
            {
                "tecnologia": "Repo A",
                "points": [10, 20, 30, 40],
            }
        ],
    }

    compact_so = export_history_json._build_compact_frontend_payload(  # pylint: disable=protected-access
        so_payload
    )
    compact_other = export_history_json._build_compact_frontend_payload(  # pylint: disable=protected-access
        other_payload
    )

    assert compact_so["snapshot_count"] == 2
    assert compact_so["series"][0]["points"] == [2056, 1659, 1374, 1022]
    assert compact_other["series"][0]["points"] == [30, 40]


def test_compact_frontend_payload_aligns_trend_series_with_retained_snapshots():
    trend_payload = {
        "snapshot_count": 3,
        "snapshots": [
            {"date": "2026-03-06"},
            {"date": "2026-03-24"},
            {"date": "2026-03-28"},
        ],
        "series": [
            {
                "tecnologia": "Python",
                "slug": "python",
                "points": [
                    {"date": "2026-03-24", "trend_score": 79.08, "fuentes": 3},
                    {"date": "2026-03-28", "trend_score": 78.15, "fuentes": 3},
                ],
            },
            {
                "tecnologia": "Csharp",
                "slug": "csharp",
                "points": [
                    {"date": "2026-03-06", "trend_score": 0.0, "fuentes": 0},
                    {"date": "2026-03-07", "trend_score": 0.0, "fuentes": 0},
                ],
            },
        ],
    }

    compact_trend = export_history_json._build_compact_frontend_payload(  # pylint: disable=protected-access
        trend_payload
    )

    assert compact_trend["snapshot_count"] == 2
    assert [item["date"] for item in compact_trend["snapshots"]] == [
        "2026-03-24",
        "2026-03-28",
    ]
    assert [series["slug"] for series in compact_trend["series"]] == ["python"]
    assert [point["date"] for point in compact_trend["series"][0]["points"]] == [
        "2026-03-24",
        "2026-03-28",
    ]


def test_build_so_volume_history_handles_single_snapshot_cleanly(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=07"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "python,120\n"
            "javascript,70\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_volume_history(project_root, history_index)

    assert payload["snapshot_count"] == 1
    assert payload["latest_snapshot_date"] == "2026-03-07"
    assert payload["previous_snapshot_date"] is None
    assert payload["has_historical_comparison"] is False
    assert payload["summary"]["leader"]["lenguaje"] == "python"
    assert payload["summary"]["highest_growth"] is None
    assert payload["summary"]["largest_drop"] is None


def test_build_so_volume_history_normalizes_csharp_and_cpp_aliases(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=06"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=07"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "csharp,100\n"
            "cpp,80\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "c#,110\n"
            "c++,90\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_volume_history(project_root, history_index)

    csharp_item = next(item for item in payload["latest_items"] if item["lenguaje"] == "c#")
    cpp_item = next(item for item in payload["latest_items"] if item["lenguaje"] == "c++")

    assert csharp_item["preguntas_prev"] == 100
    assert csharp_item["delta_preguntas"] == 10
    assert cpp_item["preguntas_prev"] == 80
    assert cpp_item["delta_preguntas"] == 10


def test_build_so_volume_summary_ignores_prev_zero_for_growth_badges(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=06"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "so_volumen" / "year=2026" / "month=03" / "day=07"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "python,100\n"
            "cpp,0\n"
            "csharp,0\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "so_volumen_preguntas.csv").write_text(
        (
            "lenguaje,preguntas_nuevas_2025\n"
            "python,90\n"
            "c++,50\n"
            "c#,40\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_volume_history(project_root, history_index)

    assert payload["summary"]["highest_growth"] is None
    assert payload["summary"]["largest_drop"]["lenguaje"] == "python"


def test_build_so_acceptance_history_adds_confidence_fields_and_summary(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_aceptacion" / "year=2026" / "month=03" / "day=07"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "so_aceptacion" / "year=2026" / "month=03" / "day=08"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_tasa_aceptacion.csv").write_text(
        (
            "tecnologia,total_preguntas,respuestas_aceptadas,tasa_aceptacion_pct\n"
            "svelte,10,8,80.0\n"
            "angular,1000,750,75.0\n"
            "reactjs,900,450,50.0\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "so_tasa_aceptacion.csv").write_text(
        (
            "tecnologia,total_preguntas,respuestas_aceptadas,tasa_aceptacion_pct\n"
            "svelte,10,9,90.0\n"
            "angular,1000,800,80.0\n"
            "reactjs,900,405,45.0\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_acceptance_history(project_root, history_index)

    assert payload["dataset"] == "so_tasa_aceptacion"
    assert payload["snapshot_count"] == 2
    assert payload["latest_snapshot_date"] == "2026-03-08"
    assert payload["previous_snapshot_date"] == "2026-03-07"
    assert payload["has_historical_comparison"] is True
    assert payload["item_count"] == 3

    svelte_item = next(item for item in payload["latest_items"] if item["tecnologia"] == "svelte")
    angular_item = next(item for item in payload["latest_items"] if item["tecnologia"] == "angular")
    react_item = next(item for item in payload["latest_items"] if item["tecnologia"] == "reactjs")

    assert svelte_item["raw_rank"] == 1
    assert svelte_item["sample_bucket"] == "baja"
    assert svelte_item["delta_tasa_pct"] == 10.0
    assert angular_item["confidence_rank"] == 1
    assert angular_item["sample_bucket"] == "alta"
    assert react_item["delta_tasa_pct"] == -5.0

    assert payload["summary"]["raw_leader"]["tecnologia"] == "svelte"
    assert payload["summary"]["confidence_leader"]["tecnologia"] == "angular"
    assert payload["summary"]["highest_improvement"]["tecnologia"] == "svelte"
    assert payload["summary"]["largest_drop"]["tecnologia"] == "reactjs"
    assert payload["summary"]["largest_sample"]["tecnologia"] == "angular"


def test_build_so_acceptance_history_handles_single_snapshot_cleanly(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_aceptacion" / "year=2026" / "month=03" / "day=08"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_tasa_aceptacion.csv").write_text(
        (
            "tecnologia,total_preguntas,respuestas_aceptadas,tasa_aceptacion_pct\n"
            "angular,1000,800,80.0\n"
            "svelte,10,9,90.0\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_acceptance_history(project_root, history_index)

    assert payload["snapshot_count"] == 1
    assert payload["latest_snapshot_date"] == "2026-03-08"
    assert payload["previous_snapshot_date"] is None
    assert payload["has_historical_comparison"] is False
    assert payload["summary"]["raw_leader"]["tecnologia"] == "svelte"
    assert payload["summary"]["confidence_leader"]["tecnologia"] == "angular"
    assert payload["summary"]["highest_improvement"] is None
    assert payload["summary"]["largest_drop"] is None


def test_build_so_trends_history_builds_structured_series_and_summary(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "so_tendencias" / "year=2026" / "month=03" / "day=07"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "so_tendencias" / "year=2026" / "month=03" / "day=08"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "so_tendencias_mensuales.csv").write_text(
        (
            "mes,python,javascript,typescript\n"
            "2025-03,100,80,60\n"
            "2025-04,90,70,45\n"
            "2025-05,80,50,30\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "so_tendencias_mensuales.csv").write_text(
        (
            "mes,python,javascript,typescript\n"
            "2025-03,120,100,70\n"
            "2025-04,100,65,40\n"
            "2025-05,90,40,21\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_trends_history(project_root, history_index)

    assert payload["dataset"] == "so_tendencias_mensuales"
    assert payload["source_mode"] == "history"
    assert payload["snapshot_count"] == 2
    assert payload["months"] == ["2025-03", "2025-04", "2025-05"]
    assert len(payload["series"]) == 3

    python_series = next(item for item in payload["series"] if item["tecnologia"] == "Python")
    javascript_series = next(item for item in payload["series"] if item["tecnologia"] == "JavaScript")
    typescript_series = next(item for item in payload["series"] if item["tecnologia"] == "TypeScript")

    assert python_series["points"] == [120, 100, 90]
    assert python_series["start_value"] == 120
    assert python_series["end_value"] == 90
    assert python_series["abs_delta"] == -30
    assert python_series["pct_delta"] == -25.0
    assert python_series["retention_pct"] == 75.0
    assert python_series["peak_month"] == "2025-03"
    assert python_series["peak_value"] == 120
    assert python_series["latest_rank"] == 1

    assert javascript_series["latest_rank"] == 2
    assert typescript_series["latest_rank"] == 3

    assert payload["summary"]["current_leader"]["tecnologia"] == "Python"
    assert payload["summary"]["best_retention"]["tecnologia"] == "Python"
    assert payload["summary"]["largest_relative_drop"]["tecnologia"] == "TypeScript"
    assert payload["summary"]["largest_absolute_drop"]["tecnologia"] == "JavaScript"


def test_build_so_trends_history_prefers_richer_metadata_source(tmp_path):
    project_root = tmp_path
    history_day = (
        project_root / "datos" / "history" / "so_tendencias" / "year=2026" / "month=03" / "day=08"
    )
    metadata_dir = project_root / "datos" / "metadata"
    history_day.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)

    (history_day / "so_tendencias_mensuales.csv").write_text(
        (
            "mes,python,javascript,typescript\n"
            "2025-03,120,100,70\n"
            "2025-04,100,65,40\n"
            "2025-05,90,40,21\n"
        ),
        encoding="utf-8",
    )
    (metadata_dir / "so_tendencias_series.json").write_text(
        json.dumps(
            {
                "generated_at_utc": "2026-03-08T00:00:00Z",
                "selection_mode": "top_n_by_cumulative_volume",
                "selection_basis": "last_12_complete_months",
                "top_n": 5,
                "months": ["2025-03", "2025-04", "2025-05"],
                "series": [
                    {"tecnologia": "python", "points": [120, 100, 90]},
                    {"tecnologia": "javascript", "points": [100, 65, 40]},
                    {"tecnologia": "typescript", "points": [70, 40, 21]},
                    {"tecnologia": "java", "points": [80, 75, 70]},
                    {"tecnologia": "go", "points": [60, 55, 50]},
                ],
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_so_trends_history(project_root, history_index)

    assert payload["source_mode"] == "history"
    assert payload["snapshot_count"] == 1
    assert payload["months"] == ["2025-03", "2025-04", "2025-05"]
    assert len(payload["series"]) == 5
    assert [item["tecnologia"] for item in payload["series"]] == [
        "Python",
        "Java",
        "Go",
        "JavaScript",
        "TypeScript",
    ]
    assert payload["summary"]["current_leader"]["tecnologia"] == "Python"
    assert payload["summary"]["best_retention"]["tecnologia"] == "Java"
    assert payload["summary"]["largest_relative_drop"]["tecnologia"] == "TypeScript"
    assert payload["summary"]["largest_absolute_drop"]["tecnologia"] == "JavaScript"


def test_build_reddit_topics_history_adds_growth_when_previous_snapshot_exists(tmp_path):
    project_root = tmp_path
    history_day_1 = project_root / "datos" / "history" / "reddit_temas_emergentes" / "year=2026" / "month=02" / "day=20"
    history_day_2 = project_root / "datos" / "history" / "reddit_temas_emergentes" / "year=2026" / "month=02" / "day=27"
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nAI/ML,100\nCloud,40\n",
        encoding="utf-8",
    )
    (history_day_2 / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nAI/ML,130\nCloud,20\n",
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_reddit_topics_history(project_root, history_index)

    assert payload["dataset"] == "reddit_temas_emergentes"
    assert payload["snapshot_count"] == 2
    assert payload["latest_snapshot_date"] == "2026-02-27"
    assert payload["previous_snapshot_date"] == "2026-02-20"
    assert payload["summary"]["leader_topic"]["tema"] == "AI/ML"
    assert payload["summary"]["highest_growth_topic"]["tema"] == "AI/ML"
    assert payload["summary"]["largest_drop_topic"]["tema"] == "Cloud"
    assert payload["latest_topics"][0]["tema"] == "AI/ML"
    assert payload["latest_topics"][0]["delta_menciones"] == 30
    assert payload["latest_topics"][0]["growth_pct"] == 30.0
    assert payload["latest_topics"][0]["trend_direction"] == "creciendo"


def test_build_reddit_sentiment_public_uses_latest_when_available(tmp_path):
    project_root = tmp_path
    latest_dir = project_root / "datos" / "latest"
    latest_dir.mkdir(parents=True, exist_ok=True)

    (latest_dir / "reddit_sentimiento_frameworks.csv").write_text(
        (
            "framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\n"
            "Django,9,8,0,1,88.89,0.0,11.11\n"
            "Laravel,25,21,0,4,84.0,0.0,16.0\n"
        ),
        encoding="utf-8",
    )

    payload = export_history_json.build_reddit_sentiment_public(project_root)

    assert payload["source_mode"] == "latest"
    assert payload["framework_count"] == 2
    assert payload["frameworks"][0]["framework"] == "Django"
    assert payload["frameworks"][0]["porcentaje_positivo"] == 88.89
    assert payload["summary"]["positive_leader"]["framework"] == "Django"
    assert payload["summary"]["largest_sample"]["framework"] == "Laravel"
    assert payload["summary"]["negative_leader"]["framework"] == "Laravel"


def test_build_github_languages_public_adds_summary(tmp_path):
    project_root = tmp_path
    latest_dir = project_root / "datos" / "latest"
    latest_dir.mkdir(parents=True, exist_ok=True)

    (latest_dir / "github_lenguajes.csv").write_text(
        (
            "lenguaje,repos_count,porcentaje\n"
            "Python,320,35.0\n"
            "TypeScript,250,27.0\n"
            "JavaScript,80,9.0\n"
        ),
        encoding="utf-8",
    )

    payload = export_history_json.build_github_languages_public(project_root)

    assert payload["source_mode"] == "latest"
    assert payload["language_count"] == 3
    assert payload["summary"]["leader"]["lenguaje"] == "Python"
    assert payload["summary"]["runner_up"]["lenguaje"] == "TypeScript"
    assert payload["summary"]["leader_gap_repos"] == 70
    assert payload["summary"]["leader_gap_share_pct"] == 8.0


def test_build_trend_score_history_falls_back_to_latest_when_history_missing(tmp_path):
    project_root = tmp_path
    latest_dir = project_root / "datos" / "latest"
    latest_dir.mkdir(parents=True, exist_ok=True)
    (project_root / "frontend" / "assets" / "data").mkdir(parents=True, exist_ok=True)

    (latest_dir / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,100,100,5.8,76.45,3\n"
            "2,TypeScript,70.7,17.7,1.0,34.74,3\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    trend_payload = export_history_json.build_trend_score_history(project_root, history_index)

    assert trend_payload["snapshot_count"] == 1
    assert trend_payload["snapshots"][0]["source_type"] == "latest"
    assert len(trend_payload["series"]) == 2


def test_build_trend_score_history_falls_back_to_latest_when_history_is_corrupted(tmp_path):
    project_root = tmp_path
    history_dir = project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=02" / "day=22"
    latest_dir = project_root / "datos" / "latest"

    history_dir.mkdir(parents=True, exist_ok=True)
    latest_dir.mkdir(parents=True, exist_ok=True)
    (project_root / "frontend" / "assets" / "data").mkdir(parents=True, exist_ok=True)

    # Corrupted history schema for trend snapshot (missing required columns).
    (history_dir / "trend_score.csv").write_text(
        "foo,bar\n1,2\n",
        encoding="utf-8",
    )
    (latest_dir / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,100,100,5.8,76.45,3\n"
            "2,TypeScript,70.7,17.7,1.0,34.74,3\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    trend_payload = export_history_json.build_trend_score_history(project_root, history_index)

    assert trend_payload["snapshot_count"] == 1
    assert trend_payload["snapshots"][0]["source_type"] == "latest"
    assert trend_payload["snapshots"][0]["top_10"][0]["tecnologia"] == "Python"


def test_build_trend_score_history_adds_source_scores_and_previous_deltas(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=03" / "day=08"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=03" / "day=09"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,40,30,10,80,3\n"
            "2,AI/ML,0,0,25,25,1\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,42,31,9,82,3\n"
            "2,AI/ML,0,0,24,24,1\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_trend_score_history(project_root, history_index)

    latest_top = payload["snapshots"][-1]["top_10"]
    python_item = next(item for item in latest_top if item["tecnologia"] == "Python")
    aiml_item = next(item for item in latest_top if item["tecnologia"] == "AI/ML")

    assert python_item["score_prev"] == 80.0
    assert python_item["delta_score"] == 2.0
    assert python_item["ranking_prev"] == 1
    assert python_item["delta_ranking"] == 0
    assert python_item["available_source_codes"] == ["GH", "SO", "RD"]
    assert aiml_item["slug"] == "ai-ml"
    assert aiml_item["available_source_codes"] == ["RD"]


def test_build_technology_profiles_adds_slug_source_history_and_insights(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=03" / "day=08"
    )
    history_day_2 = (
        project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=03" / "day=09"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,40,30,10,80,3\n"
            "2,C#,15,10,0,25,2\n"
            "3,AI/ML,0,0,24,24,1\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,42,31,9,82,3\n"
            "2,C#,13,11,0,24,2\n"
            "3,AI/ML,0,0,26,26,1\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_technology_profiles(project_root, history_index)

    assert payload["dataset"] == "technology_profiles"
    assert payload["latest_snapshot_date"] == "2026-03-09"
    assert payload["previous_snapshot_date"] == "2026-03-08"
    assert payload["profile_count"] == 3

    python_profile = next(item for item in payload["profiles"] if item["slug"] == "python")
    aiml_profile = next(item for item in payload["profiles"] if item["slug"] == "ai-ml")
    csharp_profile = next(item for item in payload["profiles"] if item["slug"] == "c-sharp")

    assert python_profile["trend_score_actual"] == 82.0
    assert python_profile["trend_score_prev"] == 80.0
    assert python_profile["delta_score"] == 2.0
    assert python_profile["sources_present"] == ["github", "stackoverflow", "reddit"]
    assert len(python_profile["source_history"]) == 2
    assert python_profile["github_summary"]["score_actual"] == 42.0
    assert python_profile["summary_insights"]["dominant_source"]["source"] == "github"
    assert "corrida previa" in python_profile["summary_insights"]["momentum"]["label"]

    assert aiml_profile["slug"] == "ai-ml"
    assert aiml_profile["sources_present"] == ["reddit"]
    assert aiml_profile["summary_insights"]["coverage"]["source_count"] == 1

    assert csharp_profile["display_name"] == "C#"
    assert csharp_profile["slug"] == "c-sharp"


def test_build_reddit_intersection_history_adds_delta_fields_when_previous_exists(tmp_path):
    project_root = tmp_path
    history_day_1 = project_root / "datos" / "history" / "interseccion" / "year=2026" / "month=02" / "day=20"
    history_day_2 = project_root / "datos" / "history" / "interseccion" / "year=2026" / "month=02" / "day=27"
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "interseccion_github_reddit.csv").write_text(
        (
            "tecnologia,tipo,ranking_github,ranking_reddit,diferencia\n"
            "Python,Lenguaje,1,6,5\n"
            "TypeScript,Lenguaje,2,9,7\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "interseccion_github_reddit.csv").write_text(
        (
            "tecnologia,tipo,ranking_github,ranking_reddit,diferencia\n"
            "Python,Lenguaje,1,4,3\n"
            "TypeScript,Lenguaje,2,10,8\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_reddit_intersection_history(project_root, history_index)

    assert payload["dataset"] == "interseccion_github_reddit"
    assert payload["snapshot_count"] == 2
    assert payload["latest_snapshot_date"] == "2026-02-27"
    assert payload["previous_snapshot_date"] == "2026-02-20"
    assert payload["summary"]["max_brecha_tecnologia"] == "TypeScript"
    assert payload["summary"]["closest_alignment"]["tecnologia"] == "Python"
    assert payload["summary"]["largest_gap_item"]["tecnologia"] == "TypeScript"

    latest_python = next(
        item for item in payload["latest_items"] if item["tecnologia"] == "Python"
    )
    assert latest_python["brecha_abs"] == 3
    assert latest_python["delta_gap"] == -2
    assert latest_python["trend_direction"] == "disminuyendo"


def test_build_github_frameworks_history_adds_growth_and_snapshot_dates(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root
        / "datos"
        / "history"
        / "github_commits"
        / "year=2026"
        / "month=03"
        / "day=03"
    )
    history_day_2 = (
        project_root
        / "datos"
        / "history"
        / "github_commits"
        / "year=2026"
        / "month=03"
        / "day=04"
    )
    monthly_latest_dir = project_root / "datos" / "latest"
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)
    monthly_latest_dir.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "github_commits_frameworks.csv").write_text(
        (
            "framework,repo,commits_2025,active_contributors,merged_prs,closed_issues,releases_count,ranking\n"
            "React,facebook/react,100,40,20,22,2,1\n"
            "Vue 3,vuejs/core,80,30,18,19,1,2\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "github_commits_frameworks.csv").write_text(
        (
            "framework,repo,commits_2025,active_contributors,merged_prs,closed_issues,releases_count,ranking\n"
            "React,facebook/react,130,45,24,28,3,1\n"
            "Vue 3,vuejs/core,70,29,15,17,1,2\n"
        ),
        encoding="utf-8",
    )
    (monthly_latest_dir / "github_commits_frameworks_monthly.csv").write_text(
        (
            "framework,repo,month,commits\n"
            "React,facebook/react,2026-02,55\n"
            "React,facebook/react,2026-03,75\n"
            "Vue 3,vuejs/core,2026-02,42\n"
            "Vue 3,vuejs/core,2026-03,28\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_github_frameworks_history(
        project_root,
        history_index,
    )

    assert payload["dataset"] == "github_commits_frameworks"
    assert payload["snapshot_count"] == 2
    assert payload["snapshot_date"] == "2026-03-04"
    assert payload["latest_snapshot_date"] == "2026-03-04"
    assert payload["previous_snapshot_date"] == "2026-03-03"
    assert payload["has_historical_comparison"] is True
    assert len(payload["latest_frameworks"]) == 2
    react = next(
        item for item in payload["latest_frameworks"] if item["framework"] == "React"
    )
    assert react["commits_prev"] == 100
    assert react["delta_commits"] == 30
    assert react["growth_pct"] == 30.0
    assert react["trend_direction"] == "creciendo"
    assert payload["summary"]["leader_framework"] == "React"
    assert payload["summary"]["leader"]["framework"] == "React"
    assert payload["summary"]["runner_up"]["framework"] == "Vue 3"
    assert payload["summary"]["leader_gap_commits"] == 60
    assert len(payload["series"]) == 2


def test_build_github_correlation_history_adds_summary_and_snapshot_dates(tmp_path):
    project_root = tmp_path
    history_day_1 = (
        project_root
        / "datos"
        / "history"
        / "github_correlacion"
        / "year=2026"
        / "month=03"
        / "day=05"
    )
    history_day_2 = (
        project_root
        / "datos"
        / "history"
        / "github_correlacion"
        / "year=2026"
        / "month=03"
        / "day=06"
    )
    history_day_1.mkdir(parents=True, exist_ok=True)
    history_day_2.mkdir(parents=True, exist_ok=True)

    (history_day_1 / "github_correlacion.csv").write_text(
        (
            "repo_name,stars,contributors,language\n"
            "vercel/next.js,4900,300,JavaScript\n"
            "angular/angular,4350,270,TypeScript\n"
            "facebook/react,1382,91,JavaScript\n"
        ),
        encoding="utf-8",
    )
    (history_day_2 / "github_correlacion.csv").write_text(
        (
            "repo_name,stars,contributors,language\n"
            "vercel/next.js,5000,304,JavaScript\n"
            "angular/angular,4333,274,TypeScript\n"
            "facebook/react,1380,90,JavaScript\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    payload = export_history_json.build_github_correlation_history(project_root, history_index)

    assert payload["dataset"] == "github_correlacion"
    assert payload["snapshot_count"] == 2
    assert payload["latest_snapshot_date"] == "2026-03-06"
    assert payload["previous_snapshot_date"] == "2026-03-05"
    assert payload["has_historical_comparison"] is True
    assert payload["summary"]["top_stars_repo"]["repo_name"] == "vercel/next.js"
    assert payload["summary"]["top_contributors_repo"]["repo_name"] == "vercel/next.js"
    assert payload["summary"]["correlation_value"] is not None

    latest_item = next(
        item for item in payload["latest_items"] if item["repo_name"] == "vercel/next.js"
    )
    assert latest_item["engagement_ratio"] > 0
    assert latest_item["contributors_per_1k_stars"] > 0
    assert latest_item["snapshot_date_utc"] == "2026-03-06"
    assert latest_item["trend_bucket"] in {"above_trend", "near_trend", "below_trend"}


def test_build_home_highlights_payload_selects_three_unique_highlights():
    payload = export_history_json.build_home_highlights_payload(
        github_languages_payload={
            "summary": {
                "leader": {"lenguaje": "Python", "repos_count": 320, "share_pct": 35.0},
                "leader_gap_repos": 70,
            }
        },
        github_frameworks_payload={
            "summary": {
                "leader": {"framework": "Next.js", "commits_2025": 5000},
                "leader_share_pct": 41.5,
                "leader_gap_commits": 705,
            }
        },
        github_correlation_payload={
            "summary": {
                "positive_outlier_repo": {
                    "repo_name": "Kilo-Org/kilocode",
                    "outlier_score": 6.3,
                    "contributors_per_1k_stars": 53.1,
                }
            }
        },
        reddit_sentiment_payload={
            "summary": {
                "positive_leader": {
                    "framework": "Django",
                    "total_menciones": 3,
                    "porcentaje_positivo": 100.0,
                }
            }
        },
        reddit_topics_payload={
            "summary": {
                "leader_topic": {
                    "tema": "IA/Machine Learning",
                    "menciones": 141,
                    "delta_menciones": 6,
                }
            }
        },
        reddit_intersection_payload={
            "summary": {
                "closest_alignment": {
                    "tecnologia": "Python",
                    "brecha_abs": 4,
                    "promedio_rank": 3.0,
                }
            }
        },
        so_volume_payload={
            "summary": {
                "leader": {"lenguaje": "python", "preguntas": 10817, "share_pct": 31.52}
            }
        },
        so_acceptance_payload={
            "summary": {
                "confidence_leader": {
                    "tecnologia": "svelte",
                    "total_preguntas": 146,
                    "confidence_score": 0.283089,
                }
            }
        },
        so_trends_payload={
            "summary": {
                "largest_relative_drop": {"tecnologia": "TypeScript", "pct_delta": -86.95}
            }
        },
    )

    assert payload["dataset"] == "home_highlights"
    assert payload["dashboard_signals"]["github"]["graph_1"]["signal"] == "leader"
    assert payload["dashboard_signals"]["reddit"]["graph_2"]["signal"] == "leader_topic"
    assert payload["dashboard_signals"]["stackoverflow"]["graph_3"]["signal"] == "largest_relative_drop"
    assert len(payload["highlights"]) == 3
    entities = {item["entity"] for item in payload["highlights"]}
    assert "Next.js" in entities
    assert "IA/Machine Learning" in entities
    assert "python" in entities or "Python" in entities
