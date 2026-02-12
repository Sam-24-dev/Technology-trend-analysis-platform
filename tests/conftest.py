"""
Pytest configuration for the Technology Trend Analysis Platform tests.

Adds the backend directory to sys.path so tests can import
ETL modules directly.
"""
import sys
from pathlib import Path

# Add backend directory to path so imports work the same as running from backend/
backend_dir = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_dir))
