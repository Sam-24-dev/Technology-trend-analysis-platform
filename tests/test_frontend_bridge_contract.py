from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_SERVICE_PATH = PROJECT_ROOT / "frontend" / "lib" / "services" / "csv_service.dart"
FEATURE_FLAGS_PATH = PROJECT_ROOT / "frontend" / "lib" / "config" / "feature_flags.dart"


def test_feature_flag_defaults_to_bridge_behavior():
    content = FEATURE_FLAGS_PATH.read_text(encoding="utf-8")
    assert "USE_HISTORY_BRIDGE_JSON" in content
    assert "defaultValue: true" in content


def test_csv_service_declares_bridge_json_fallback_paths():
    content = CSV_SERVICE_PATH.read_text(encoding="utf-8")

    assert "loadTrendTemporalView" in content
    assert "'source': 'bridge_json'" in content
    assert "'source': 'csv_fallback'" in content
    assert "Bridge JSON fallback to CSV" in content
