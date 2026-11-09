"""Check every language/selection against the real Compose and Kubernetes inputs."""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sqlserver/tools"))
from cli import parser
from common import LANGUAGES, REPLACEMENTS, selected_databases, selected_services
from compose import swap_model
from kubernetes import render_kubernetes


class SwapTests(unittest.TestCase):
    def test_compose_matrix(self):
        for language in LANGUAGES:
            result = subprocess.run([
                "docker", "compose", "-f", str(ROOT / language / "docker-compose/docker-compose.yml"),
                "config", "--no-interpolate", "--format", "json"],
                check=True, capture_output=True, text=True)
            original = json.loads(result.stdout)
            for replacement in REPLACEMENTS:
                with self.subTest(language=language, replacement=replacement):
                    self.check_compose(original, language, replacement)

    def check_compose(self, original, language, replacement):
        with tempfile.TemporaryDirectory() as directory:
            model = swap_model(original, language, replacement, Path(directory))
            services = model["services"]
            self.assertEqual("mysql" in services, replacement == "postgres")
            self.assertEqual("postgres" in services, replacement == "mysql")
            for name in ("products", "checkout", "shipping"):
                expected = name in selected_services(replacement)
                self.assertEqual("sqlserver/stacks" in services[name]["build"]["context"], expected)
                self.assertTrue(set(services[name].get("depends_on", {})) <= set(services))
                if expected:
                    self.assertIn("${MSSQL_PASSWORD:", services[name]["environment"]["MSSQL_PASSWORD"])
            for key in ("build", "ports", "depends_on", "environment"):
                self.assertEqual(services["frontend"].get(key), original["services"]["frontend"].get(key))
            text = (Path(directory) / "config.alloy").read_text()
            self.check_collectors(text, replacement)
            self.assertNotIn("MSSQL_PASSWORD", services["alloy"]["environment"])
            path = Path(directory) / "compose.json"
            path.write_text(json.dumps(model))
            subprocess.run(["docker", "compose", "-f", str(path), "config",
                            "--no-interpolate", "--quiet"], check=True, capture_output=True)

    def check_collectors(self, text, replacement):
        self.assertEqual('database_observability.mysql "' in text, replacement == "postgres")
        self.assertEqual('database_observability.postgres "' in text, replacement == "mysql")
        for database in ("bookstore", "shipping"):
            self.assertEqual(f'database_observability.sql_server "sqlserver_{database}"' in text,
                             database in selected_databases(replacement))
        self.assertEqual('loki.source.' in text and '"postgres_logs"' in text,
                         replacement == "mysql")

    def test_kubernetes_matrix(self):
        for language in LANGUAGES:
            for replacement in REPLACEMENTS:
                with self.subTest(language=language, replacement=replacement):
                    self.check_kubernetes(language, replacement)

    def check_kubernetes(self, language, replacement):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "deployment.yaml"
            args = argparse.Namespace(language=language, replacement=replacement,
                                      registry="example.invalid/demo", tag="test", output=str(path))
            render_kubernetes(args)
            documents = list(yaml.safe_load_all(path.read_text()))
            self.assertFalse(any(d["kind"] in ("Namespace", "Secret") for d in documents))
            statefulsets = {d["metadata"]["name"] for d in documents if d["kind"] == "StatefulSet"}
            self.assertEqual("mysql" in statefulsets, replacement == "postgres")
            self.assertEqual("postgres" in statefulsets, replacement == "mysql")
            for document in documents:
                if document["kind"] == "Deployment":
                    self.check_deployment(document, language, replacement)
                if document["kind"] == "ConfigMap" and document["metadata"]["name"] == "alloy-config":
                    self.check_collectors(document["data"]["config.alloy"], replacement)

    def check_deployment(self, document, language, replacement):
        name = document["metadata"]["name"]
        container = document["spec"]["template"]["spec"]["containers"][0]
        if name == "alloy":
            self.assertEqual(container["image"], "example.invalid/demo/bookstore-sqlserver/alloy:test")
        else:
            self.assertEqual(container["image"], f"example.invalid/demo/bookstore-{language}/{name}:test")
        secret_names = {v["secretRef"]["name"] for v in container.get("envFrom", []) if "secretRef" in v}
        secret_names.update(v["valueFrom"]["secretKeyRef"]["name"]
                            for v in container.get("env", [])
                            if "secretKeyRef" in v.get("valueFrom", {}))
        self.assertEqual("bookstore-sqlserver" in secret_names,
                         name == "alloy" or name in selected_services(replacement))
        keys = {v["name"] for v in container.get("env", [])}
        if name == "alloy":
            self.assertNotIn("MSSQL_PASSWORD", keys)
        elif name in selected_services(replacement):
            self.assertFalse(any(key.endswith("_DSN") for key in keys))

    def test_custom_env_file_and_compose_arguments(self):
        args = parser().parse_args(["compose", "--env-file", "/tmp/test.env", "go", "postgres",
                                    "up", "--build", "-d"])
        self.assertEqual(args.env_file, "/tmp/test.env")
        self.assertEqual(args.command, ["up", "--build", "-d"])

    def test_invalid_selection_rejected(self):
        with self.assertRaises(SystemExit):
            parser().parse_args(["compose", "go", "arbitrary-path"])

    def test_shared_env_file_default(self):
        with patch.dict(os.environ, {"BOOKSTORE_ENV_FILE": "/tmp/shared.env"}):
            args = parser().parse_args(["compose", "ruby", "mysql", "up"])
            self.assertEqual(args.env_file, "/tmp/shared.env")

    def test_launcher_preserves_passwords_without_saving_them_in_generated_json(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.env"
            template = (ROOT / "sqlserver/compose/.env.example").read_text()
            password = "literal$credential#123"
            template = template.replace("MSSQL_PASSWORD=REPLACE_WITH_APP_PASSWORD",
                                        f"MSSQL_PASSWORD='{password}'")
            path.write_text(template)
            environment = dict(os.environ, BOOKSTORE_ENV_FILE=str(path))
            result = subprocess.run([
                str(ROOT / "scripts/swap-db"), "compose", "go", "both", "config",
                "--format", "json"], env=environment, capture_output=True, text=True, check=True)
            model = json.loads(result.stdout)
            # Compose config escapes literal dollars as $$ when serializing for reuse.
            serialized = model["services"]["products"]["environment"]["MSSQL_PASSWORD"]
            self.assertEqual(serialized.replace("$$", "$"), password)
            generated = ROOT / ".sqlserver/go/both/compose/compose.json"
            self.assertNotIn(password, generated.read_text())


if __name__ == "__main__":
    unittest.main()
