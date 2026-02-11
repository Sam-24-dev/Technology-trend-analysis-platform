.PHONY: help install etl test sync clean

help:
	@echo "Tech Trends 2025 - Comandos"
	@echo ""
	@echo "  make install   Instalar dependencias Python"
	@echo "  make etl       Ejecutar pipeline ETL completo"
	@echo "  make test      Ejecutar tests con pytest"
	@echo "  make sync      Sincronizar CSVs al frontend"
	@echo "  make clean     Limpiar archivos temporales"

install:
	pip install -r backend/requirements.txt

etl:
	python backend/github_etl.py
	python backend/stackoverflow_etl.py
	python backend/reddit_etl.py

test:
	python -m pytest tests/ -v

sync:
	python backend/sync_assets.py

clean:
	@echo "Limpiando..."
	@if exist __pycache__ rmdir /s /q __pycache__
	@if exist .pytest_cache rmdir /s /q .pytest_cache
	@if exist backend\__pycache__ rmdir /s /q backend\__pycache__
	@if exist tests\__pycache__ rmdir /s /q tests\__pycache__
	@echo "Listo."
