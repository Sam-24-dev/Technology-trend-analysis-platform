.PHONY: help install etl test sync clean

help:  ## Mostrar comandos disponibles
	@echo "============================================"
	@echo " Tech Trends 2025 - Comandos Disponibles"
	@echo "============================================"
	@echo ""
	@echo "  make install   - Instalar dependencias Python"
	@echo "  make etl       - Ejecutar pipeline ETL completo"
	@echo "  make test      - Ejecutar tests con pytest"
	@echo "  make sync      - Sincronizar CSVs al frontend"
	@echo "  make clean     - Limpiar archivos temporales"
	@echo ""

install:  ## Instalar dependencias Python
	pip install -r backend/requirements.txt

etl:  ## Ejecutar pipeline ETL completo
	python backend/github_etl.py
	python backend/stackoverflow_etl.py
	python backend/reddit_etl.py

test:  ## Ejecutar tests con pytest
	python -m pytest tests/ -v

sync:  ## Sincronizar CSVs de datos/ a frontend/assets/data/
	python backend/sync_assets.py

clean:  ## Limpiar archivos temporales
	@echo "Limpiando archivos temporales..."
	@if exist __pycache__ rmdir /s /q __pycache__
	@if exist .pytest_cache rmdir /s /q .pytest_cache
	@if exist backend\__pycache__ rmdir /s /q backend\__pycache__
	@if exist tests\__pycache__ rmdir /s /q tests\__pycache__
	@echo "Limpieza completada."
