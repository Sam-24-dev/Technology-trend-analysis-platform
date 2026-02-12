"""
Custom exceptions for the ETL pipeline.

Provides specific error types to distinguish between
extraction failures (API issues) and validation failures
(data quality issues).
"""


class ETLExtractionError(Exception):
    """Raised when data extraction from an API fails."""
    pass


class ETLValidationError(Exception):
    """Raised when extracted data fails validation checks."""
    pass
