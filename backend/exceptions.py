"""
Excepciones personalizadas para el pipeline ETL.

Proporciona tipos de error específicos para distinguir entre
fallos de extracción (problemas de API) y fallos de validación
(problemas de calidad de datos).
"""


class ETLExtractionError(Exception):
    """Se lanza cuando la extracción de datos desde una API falla."""

    def __init__(self, message, critical=False):
        super().__init__(message)
        self.critical = critical


class ETLValidationError(Exception):
    """Se lanza cuando los datos extraídos no superan las validaciones establecidas.
"""
