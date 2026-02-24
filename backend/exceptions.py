"""
Excepciones personalizadas para el pipeline ETL.

Proporciona tipos de error especificos para distinguir entre
fallos de extraccion (problemas de API) y fallos de validacion
(problemas de calidad de datos).
"""


class ETLExtractionError(Exception):
    """Se lanza cuando la extraccion de datos desde una API falla."""

    def __init__(self, message, critical=False):
        super().__init__(message)
        self.critical = critical


class ETLValidationError(Exception):
    """Se lanza cuando los datos extraidos no superan las validaciones establecidas."""

