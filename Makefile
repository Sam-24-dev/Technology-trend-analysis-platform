.PHONY: help install etl test sync security clean all

help:
	@echo "Tech Trends 2025 - Comandos"
	@echo ""
	@echo "  make install   Instalar dependencias"
	@echo "  make etl       Ejecutar pipeline ETL"
	@echo "  make test      Ejecutar tests"
	@echo "  make security  Auditar vulnerabilidades de dependencias"
	@echo "  make sync      Sincronizar CSVs al frontend"
	@echo "  make all       Pipeline completo (install + etl + sync)"
	@echo "  make clean     Limpiar temporales"

install:
	pip install -r backend/requirements.txt

all: install etl sync

etl:
	python backend/github_etl.py
	python backend/stackoverflow_etl.py
	python backend/reddit_etl.py
	python backend/trend_score.py

test:
	python -m pytest tests/ -v

security:
	pip install --upgrade pip pip-audit
	pip-audit -r backend/requirements.txt

sync:
	python backend/sync_assets.py

clean:
	@echo "Limpiando..."
	@python -c "from pathlib import Path; import shutil; paths=[Path('__pycache__'), Path('.pytest_cache'), Path('backend/__pycache__'), Path('tests/__pycache__')]; [shutil.rmtree(p, ignore_errors=True) for p in paths]"
	@echo "Listo."
