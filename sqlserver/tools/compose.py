"""Compose swaps reuse each language's base model without resolving secrets."""
import copy
import json
import os
import subprocess
from pathlib import Path

from common import (
    ALLOY_IMAGE,
    ROOT,
    build_spec,
    generated_directory,
    render_alloy,
    selected_databases,
    selected_services,
    write_json,
)


def sqlserver_environment():
    return {
        "MSSQL_HOST": "${MSSQL_HOST:?Set MSSQL_HOST in your env file}",
        "MSSQL_PORT": "${MSSQL_PORT:-1433}",
        "MSSQL_USER": "${MSSQL_USER:-bookstore_app}",
        "MSSQL_PASSWORD": "${MSSQL_PASSWORD:?Set MSSQL_PASSWORD in your env file}",
        "MSSQL_BOOKSTORE_DB": "${MSSQL_BOOKSTORE_DB:-bookstore}",
        "MSSQL_SHIPPING_DB": "${MSSQL_SHIPPING_DB:-shipping}",
        "MSSQL_TRUST_SERVER_CERTIFICATE": "false",
    }


def replace_app(service, language, name, replacement):
    service["build"] = build_spec(language, name, replacement)
    environment = service.setdefault("environment", {})
    for key in list(environment):
        if key.startswith(("MYSQL_", "POSTGRES_")):
            del environment[key]
    environment.update(sqlserver_environment())
    if language == "java":
        environment["OTEL_INSTRUMENTATION_COMMON_PEER_SERVICE_MAPPING"] = (
            "${MSSQL_HOST}:${MSSQL_PORT:-1433}=rds-sqlserver")


def replace_alloy(alloy, directory, replacement):
    original = Path(next(v["source"] for v in alloy["volumes"]
                         if v["target"] == "/etc/alloy/config.alloy")).read_text()
    config = directory / "config.alloy"
    config.write_text(render_alloy(original, replacement))
    os.chmod(config, 0o644)
    for volume in alloy["volumes"]:
        if volume["target"] == "/etc/alloy/config.alloy":
            volume["source"] = str(config)
    alloy["build"] = {"context": str(ROOT / "sqlserver/alloy"),
                      "args": {"ALLOY_IMAGE": ALLOY_IMAGE}}
    alloy["image"] = "bookstore-sqlserver-alloy:local"
    environment = alloy.setdefault("environment", {})
    metadata = sqlserver_environment()
    for key in ("MSSQL_USER", "MSSQL_PASSWORD", "MSSQL_TRUST_SERVER_CERTIFICATE"):
        del metadata[key]
    environment.update(metadata)
    environment["RDS_ARN"] = "${RDS_ARN:?Set RDS_ARN in your env file}"
    for database in selected_databases(replacement):
        key = f"MSSQL_{database.upper()}_DSN"
        environment[key] = "${" + key + ":?Set the URL-encoded collector DSN}"


def swap_model(original, language, replacement, directory):
    model = copy.deepcopy(original)
    services = model["services"]
    # Compose 2.15 emits null defaults that its own input schema rejects.
    for service in services.values():
        for key in ("command", "entrypoint"):
            if service.get(key) is None:
                service.pop(key, None)
    for name in selected_services(replacement):
        replace_app(services[name], language, name, replacement)
    replace_alloy(services["alloy"], directory, replacement)
    engines = ("mysql", "postgres") if replacement == "both" else (replacement,)
    for engine in engines:
        services.pop(engine)
        model.get("volumes", {}).pop(f"{engine}_data", None)
        for service in services.values():
            service.get("depends_on", {}).pop(engine, None)
        environment = services["alloy"]["environment"]
        for key in list(environment):
            if key.startswith(engine.upper() + "_"):
                del environment[key]
    if "postgres" in engines:
        services["alloy"]["volumes"] = [v for v in services["alloy"]["volumes"]
                                          if v["target"] != "/var/lib/postgresql"]
    return model


def run_compose(args):
    stack = ROOT / args.language / "docker-compose"
    command = ["docker", "compose", "--project-directory", str(stack)]
    if args.env_file:
        command.extend(("--env-file", str(Path(args.env_file).resolve())))
    base = command + ["-f", str(stack / "docker-compose.yml")]
    result = subprocess.run(base + ["config", "--no-interpolate", "--format", "json"],
                            check=True, text=True, capture_output=True)
    directory = generated_directory(args.language, args.replacement, "compose")
    model = swap_model(json.loads(result.stdout), args.language, args.replacement, directory)
    path = directory / "compose.json"
    write_json(path, model)
    action = args.command or ["up", "--build", "-d"]
    if action[0] == "--":
        action = action[1:]
    return subprocess.call(command + ["-f", str(path)] + action, cwd=stack)
