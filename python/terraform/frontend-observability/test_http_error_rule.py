import ast
import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LANGS = ("go", "java", "nodejs", "python", "ruby")
COMBINED_STATUS_FILTER = "event_data_http.status_code=(0|4[0-9][0-9]|5[0-9][0-9])"


def load_http_errors_expr(lang):
    path = ROOT / lang / "terraform/frontend-observability/feo11y_rules.tf"
    text = path.read_text()
    match = re.search(
        r'name\s+= "asserts:feo11y_error:ratio_5m - Frontend/http_errors"'
        r'\s+model = ("(?:\\.|[^"\\])*")',
        text,
    )
    if match is None:
        raise AssertionError(f"http_errors rule not found in {path}")
    return json.loads(ast.literal_eval(match.group(1)))["expr"]


def load_pair_fixtures():
    path = Path(__file__).with_name("fixtures") / "http_error_pairs.json"
    return json.loads(path.read_text())


def ratio_for(case):
    errors = case["network"] + case["client"] + case["server"]
    return errors / case["total"]


class HttpErrorRuleTest(unittest.TestCase):
    def test_http_error_rule_uses_one_combined_status_count(self):
        for lang in LANGS:
            with self.subTest(lang=lang):
                expr = load_http_errors_expr(lang)
                self.assertIn(COMBINED_STATUS_FILTER, expr)
                self.assertNotIn("status_code=0", expr)
                self.assertNotIn("status_code=4[0-9][0-9]", expr)
                self.assertNotIn("status_code=5[0-9][0-9]", expr)

    def test_fixtures_cover_every_pair_of_http_error_categories(self):
        fixture_names = {case["name"] for case in load_pair_fixtures()}
        self.assertEqual(
            fixture_names,
            {"network_and_client", "network_and_server", "client_and_server"},
        )

    def test_pair_fixtures_sum_all_observed_categories(self):
        for case in load_pair_fixtures():
            with self.subTest(case=case["name"]):
                self.assertAlmostEqual(ratio_for(case), case["expected_ratio"])


if __name__ == "__main__":
    unittest.main()
