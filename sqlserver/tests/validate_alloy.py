"""Validate all rendered collector configurations using the pinned Alloy image."""
import io
import re
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sqlserver/tools"))
from common import ALLOY_IMAGE, LANGUAGES, REPLACEMENTS, kubernetes_alloy, render_alloy


def configurations():
    for language in LANGUAGES:
        original = (ROOT / language / "docker-compose/alloy/config.alloy").read_text()
        for replacement in REPLACEMENTS:
            yield f"{language}-{replacement}-compose.alloy", render_alloy(original, replacement)
            yield f"{language}-{replacement}-kubernetes.alloy", kubernetes_alloy(language, replacement)


def test_environment(text):
    values = {key: "test" for key in re.findall(r'sys.env\("([^"]+)"\)', text)}
    for key in values:
        if key.endswith(("_URL", "_ENDPOINT")):
            values[key] = "http://127.0.0.1:9000/test"
    values.update({
        "MYSQL_DSN": "test:test@tcp(mysql:3306)/",
        "MYSQL_EXPORTER_DSN": "test:test@(mysql:3306)/",
        "POSTGRES_DSN": "postgres://test:test@postgres:5432/shipping?sslmode=disable",
        "MSSQL_BOOKSTORE_DSN": "sqlserver://test:test@rds.example:1433?database=bookstore",
        "MSSQL_SHIPPING_DSN": "sqlserver://test:test@rds.example:1433?database=shipping",
        "RDS_ARN": "arn:aws:rds:us-west-1:123456789012:db:test",
    })
    return values


def main():
    configs = list(configurations())
    archive = io.BytesIO()
    with tarfile.open(fileobj=archive, mode="w") as output:
        for name, text in configs:
            data = text.encode()
            info = tarfile.TarInfo(name)
            info.size, info.mode = len(data), 0o644
            output.addfile(info, io.BytesIO(data))
    command = ["docker", "run", "--rm", "-i", "--entrypoint", "/bin/sh"]
    for key, value in test_environment("\n".join(text for _, text in configs)).items():
        command.extend(("-e", f"{key}={value}"))
    script = ("mkdir /tmp/configs && tar xf - -C /tmp/configs && "
              "for f in /tmp/configs/*.alloy; do "
              "/bin/alloy validate --stability.level=experimental \"$f\" || exit 1; done")
    subprocess.run(command + [ALLOY_IMAGE, "-c", script], input=archive.getvalue(), check=True)
    print(f"Validated {len(configs)} Alloy configurations")


if __name__ == "__main__":
    main()
