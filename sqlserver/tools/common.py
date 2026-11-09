"""Shared database selection, image names, and Alloy composition."""
import json
import os
import re
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LANGUAGES = ("python", "go", "nodejs", "java", "ruby")
REPLACEMENTS = ("mysql", "postgres", "both")
ALLOY_IMAGE = "grafana/alloy:v1.21.3@sha256:8ab871206bd2d8f89277f53abffee5f452a293980788d52f85fa183a87a505a4"


def selected_services(replacement):
    services = []
    if replacement in ("mysql", "both"):
        services.extend(("products", "checkout"))
    if replacement in ("postgres", "both"):
        services.append("shipping")
    return services


def selected_databases(replacement):
    return ["bookstore" if s == "products" else "shipping"
            for s in selected_services(replacement) if s != "checkout"]


def build_spec(language, service, replacement):
    if service in selected_services(replacement):
        return {"context": str(ROOT / "sqlserver/stacks" / language / "services"),
                "dockerfile": "Dockerfile", "args": {"SERVICE": service}}
    context = ROOT / language / "docker-compose"
    if service == "frontend":
        return {"context": str(context / "frontend"), "dockerfile": "Dockerfile"}
    if language == "java":
        return {"context": str(context / "services" / service), "dockerfile": "Dockerfile"}
    return {"context": str(context / "services"), "dockerfile": f"{service}/Dockerfile"}


def image_name(language, service, registry="", tag="sqlserver"):
    prefix = f"{registry.rstrip('/')}/" if registry else ""
    return f"{prefix}bookstore-{language}/{service}:{tag}"


def render_alloy(original, replacement):
    mysql = re.search(r"^// ── MySQL .*?$", original, re.MULTILINE)
    postgres = re.search(r"^// ── PostgreSQL .*?$", original, re.MULTILINE)
    if not mysql or not postgres:
        raise ValueError("Expected MySQL and PostgreSQL sections in the base Alloy config")
    header = original[:mysql.start()]
    sections = []
    if replacement == "postgres":
        sections.append(original[mysql.start():postgres.start()])
    if replacement == "mysql":
        sections.append(original[postgres.start():])
    template = (ROOT / "sqlserver/alloy/database.alloy").read_text()
    for database in selected_databases(replacement):
        sections.append(template.replace("DATABASE_UPPER", database.upper())
                        .replace("DATABASE", database))
    return header + "\n".join(sections)


def kubernetes_alloy(language, replacement):
    config = (ROOT / language / "k8s/alloy/configmap.yaml").read_text()
    marker = "  config.alloy: |\n"
    if marker not in config:
        raise ValueError("Expected config.alloy block in the base ConfigMap")
    return render_alloy(textwrap.dedent(config.split(marker, 1)[1]), replacement)


def generated_directory(language, replacement, deployment):
    directory = ROOT / ".sqlserver" / language / replacement / deployment
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")
    os.chmod(path, 0o600)
