"""Pin the source section boundaries used when composing Alloy collectors."""
import sys
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sqlserver/tools"))
from common import LANGUAGES, REPLACEMENTS, render_alloy


def source_configurations():
    for language in LANGUAGES:
        path = Path(language) / "docker-compose/alloy/config.alloy"
        yield path, (ROOT / path).read_text()
        path = Path(language) / "k8s/alloy/configmap.yaml"
        yield path, yaml.safe_load((ROOT / path).read_text())["data"]["config.alloy"]


class AlloySectionMarkerTests(unittest.TestCase):
    def test_source_markers_are_unique_ordered_and_bound_matching_collectors(self):
        for path, config in source_configurations():
            with self.subTest(path=str(path)):
                lines = config.splitlines()
                positions = {}
                for engine in ("MySQL", "PostgreSQL"):
                    marker = f"// ── {engine} "
                    matches = [index for index, line in enumerate(lines)
                               if line.startswith(marker)]
                    self.assertEqual(len(matches), 1, f"{path}: expected one {marker!r} marker")
                    positions[engine] = matches[0]
                mysql, postgres = positions["MySQL"], positions["PostgreSQL"]
                self.assertLess(mysql, postgres, f"{path}: MySQL must precede PostgreSQL")
                self.assertIn('database_observability.mysql "', "\n".join(lines[mysql:postgres]))
                self.assertIn('database_observability.postgres "', "\n".join(lines[postgres:]))

    def test_renderer_rejects_renamed_source_markers(self):
        for path, config in source_configurations():
            for engine in ("MySQL", "PostgreSQL"):
                edited = config.replace(f"// ── {engine} ", f"// Renamed {engine} ")
                for replacement in REPLACEMENTS:
                    with (
                        self.subTest(path=str(path), engine=engine, replacement=replacement),
                        self.assertRaisesRegex(ValueError, "Expected MySQL and PostgreSQL sections"),
                    ):
                        render_alloy(edited, replacement)


if __name__ == "__main__":
    unittest.main()
