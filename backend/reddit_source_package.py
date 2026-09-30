"""Read-only validation for the optional, aggregate-only Reddit source package."""

import csv
import hashlib
import io
import json
import math
from datetime import datetime, timezone
from pathlib import Path


REDDIT_SCOPE = ("webdev", "programming", "learnprogramming", "Python", "javascript",
                "typescript", "reactjs", "node", "devops", "MachineLearning")
SCHEMAS = {
    "reddit_sentimiento_frameworks.csv": (
        "framework", "total_menciones", "positivos", "neutros", "negativos",
        "% positivo", "% neutro", "% negativo",
    ),
    "reddit_temas_emergentes.csv": ("tema", "menciones"),
}


def _unique_json_keys(pairs):
    values = dict(pairs)
    if len(values) != len(pairs):
        raise ValueError("Duplicate Reddit receipt key")
    return values


def validate_reddit_source_package(project_root, aggregate_date_utc, *, now=None):
    """Return verified provenance; never copy, select, or publish package files."""
    root = Path(project_root) / "datos"
    receipt_path = root / "source_packages" / "reddit" / "receipt.json"
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"), object_pairs_hook=_unique_json_keys)
        if not isinstance(receipt, dict) or set(receipt) != {
            "source", "reference_date_utc", "source_date_utc", "extraction_started_at_utc",
            "extraction_finished_at_utc", "scope", "posts_count", "outputs",
        }:
            raise ValueError("Receipt schema is invalid")
        start = datetime.strptime(receipt["extraction_started_at_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        finish = datetime.strptime(receipt["extraction_finished_at_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        reference_date = datetime.strptime(receipt["reference_date_utc"], "%Y-%m-%d").date().isoformat()
        source_date = datetime.strptime(receipt["source_date_utc"], "%Y-%m-%d").date().isoformat()
        current = now if now is not None else datetime.now(timezone.utc)
        if current.tzinfo is None:
            raise ValueError("Current time must be UTC-aware")
        current = current.astimezone(timezone.utc)
        if not (
            receipt["source"] == "reddit"
            and receipt["scope"] == list(REDDIT_SCOPE)
            and type(receipt["posts_count"]) is int and receipt["posts_count"] > 0
            and start <= finish <= current
            and (current - finish).total_seconds() <= 192 * 3600
            and start.date().isoformat() == finish.date().isoformat() == reference_date == source_date == aggregate_date_utc
            and receipt["reference_date_utc"] == reference_date and receipt["source_date_utc"] == source_date
            and set(receipt["outputs"]) == set(SCHEMAS)
        ):
            raise ValueError("Reddit source package provenance is ineligible")

        for name, schema in SCHEMAS.items():
            data = (root / name).read_bytes()
            rows_reader = csv.DictReader(io.StringIO(data.decode("utf-8"), newline=""), strict=True)
            rows = list(rows_reader)
            if not rows or rows_reader.fieldnames != list(schema) or any(
                None in row or any(not value or not value.strip() for value in row.values()) for row in rows
            ):
                raise ValueError(f"Invalid Reddit aggregate schema or rows: {name}")
            count_field = "menciones" if name.startswith("reddit_temas") else "total_menciones"
            meta = receipt["outputs"][name]
            if not isinstance(meta, dict) or set(meta) != ({"rows", "sha256", "mentions_total"} if count_field == "menciones" else {"rows", "sha256"}):
                raise ValueError(f"Invalid Reddit aggregate receipt schema: {name}")
            if type(meta["rows"]) is not int or meta["rows"] != len(rows) or meta["sha256"] != hashlib.sha256(data).hexdigest():
                raise ValueError(f"Reddit aggregate identity mismatch: {name}")
            totals = [int(row[count_field]) for row in rows]
            if any(count <= 0 for count in totals):
                raise ValueError(f"Invalid Reddit aggregate counts: {name}")
            if count_field == "menciones":
                if type(meta["mentions_total"]) is not int or meta["mentions_total"] != sum(totals):
                    raise ValueError("Reddit topic mentions total mismatch")
            else:
                for row, total in zip(rows, totals):
                    counts = [int(row[key]) for key in ("positivos", "neutros", "negativos")]
                    percentages = [float(row[key]) for key in ("% positivo", "% neutro", "% negativo")]
                    if sum(counts) != total or any(count < 0 for count in counts) or any(
                        not math.isfinite(pct) or abs(pct - count * 100 / total) > 0.011
                        for count, pct in zip(counts, percentages)
                    ):
                        raise ValueError("Invalid Reddit sentiment counts or percentages")
    except (OSError, UnicodeError, json.JSONDecodeError, csv.Error, KeyError, TypeError, ValueError) as exc:
        raise ValueError("Invalid Reddit source package") from exc
    return {
        "source_date_utc": source_date,
        "extraction_finished_at_utc": receipt["extraction_finished_at_utc"],
        "posts_count": receipt["posts_count"],  # A positive claim; aggregates cannot prove raw post count.
    }
