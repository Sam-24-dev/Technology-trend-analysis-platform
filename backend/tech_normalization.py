"""Utilidades compartidas para normalizar nombres de tecnologías.

Centraliza mapeos usados por ETLs para evitar drift entre módulos.
"""

from __future__ import annotations


TECH_DISPLAY_MAP = {
    "python": "Python",
    "javascript": "JavaScript",
    "typescript": "TypeScript",
    "java": "Java",
    "go": "Go",
    "rust": "Rust",
    "c#": "C#",
    "c++": "C++",
    "ruby": "Ruby",
    "php": "PHP",
    "swift": "Swift",
    "kotlin": "Kotlin",
    "reactjs": "React",
    "react": "React",
    "vue.js": "Vue.js",
    "vue 3": "Vue.js",
    "angular": "Angular",
    "next.js": "Next.js",
    "svelte": "Svelte",
    "django": "Django",
    "fastapi": "FastAPI",
    "express": "Express",
    "spring": "Spring",
    "laravel": "Laravel",
    "ia/machine learning": "AI/ML",
    "cloud": "Cloud",
    "devops": "DevOps",
    "microservicios": "Microservices",
    "testing": "Testing",
    "performance": "Performance",
    "seguridad": "Security",
    "web3/blockchain": "Web3",
}


MATCH_ALIASES = {
    "python": ["python"],
    "javascript": ["javascript", "js", "web"],
    "typescript": ["typescript", "ts"],
    "go": ["golang", "go"],
    "rust": ["rust"],
    "react": ["react"],
    "angular": ["angular"],
    "vue 3": ["vue"],
    "java": ["java", "spring"],
    "c#": ["c#", "csharp", "dotnet", "asp.net"],
}


def normalize_technology_name(name: str) -> str:
    """Normaliza nombre a etiqueta legible consistente."""
    text = str(name or "").strip()
    if not text:
        return ""
    return TECH_DISPLAY_MAP.get(text.lower(), text.title())


def normalize_for_match(name: str) -> str:
    """Normaliza nombre para comparación flexible cross-source."""
    raw = str(name or "").strip().lower()
    if not raw:
        return ""

    for canonical, aliases in MATCH_ALIASES.items():
        if raw == canonical or any(alias in raw for alias in aliases):
            return canonical
    return raw
