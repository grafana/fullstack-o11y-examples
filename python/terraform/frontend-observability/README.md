# Bookstore Frontend Observability → Knowledge Graph recording rules

Provisions the Grafana-managed recording rules that make Grafana Cloud's
Knowledge Graph discover a `Frontend` entity for the Bookstore FaroApp in
`wcalldemo`, and let its CALLS edge to the backend services resolve. See
comments in `recording_rules.tf` for how each rule was adapted from the
working reference example.

## Usage

⚠️ **The folder and rule group below may already exist in `wcalldemo`** (see
"What this creates"). `terraform.tfstate` is gitignored on purpose — state
files can carry sensitive data and shouldn't live in git — but that means a
fresh clone has no record of existing resources. Use this flow so Terraform
imports them when they exist, or creates them when the folder is genuinely
missing:

```sh
cd python/terraform/frontend-observability
terraform init
terraform validate

# Auth: a Grafana Cloud token for wcalldemo with alerting-rule write scope.
# Never write this to a file — export it for this shell session only:
export TF_VAR_grafana_auth=$(grep '^GRAFANA_SERVICE_ACCOUNT_TOKEN=' ../../docker-compose/.env.wcalldemo | cut -d= -f2-)

if [ -z "$TF_VAR_grafana_auth" ]; then
  echo "TF_VAR_grafana_auth is empty; check ../../docker-compose/.env.wcalldemo"
  exit 1
fi

# First time in a fresh checkout: adopt the existing folder + rule group into
# your local state instead of creating new ones. If the folder is not found,
# Terraform will create both resources during apply.
FOLDERS_JSON=$(curl -fsS -H "Authorization: Bearer $TF_VAR_grafana_auth" \
  https://wcalldemo.grafana.net/api/folders) || {
  echo "Folder lookup failed; check that the token is valid for wcalldemo."
  exit 1
}

FOLDER_UID=$(printf '%s\n' "$FOLDERS_JSON" \
  | jq -r '.[]? | objects | select(.title=="bookstore-frontend-observability-asserts") | .uid')

if [ -n "$FOLDER_UID" ]; then
  terraform import grafana_folder.frontend_observability_asserts "$FOLDER_UID"
  terraform import grafana_rule_group.frontend_observability_asserts "$FOLDER_UID:frontend-observability-asserts"
else
  echo "Folder not found; Terraform will create the folder and rule group."
fi

terraform plan -out=tfplan   # if importing, this should show "No changes.";
                              # if creating, this should show only the missing
                              # resources from "What this creates"
terraform apply tfplan       # only if plan shows a real, intended change
```

## What this creates

- One `grafana_folder`: `bookstore-frontend-observability-asserts`
- One `grafana_rule_group`: `frontend-observability-asserts`, containing 17
  Grafana-managed recording rules (Loki → Prometheus), covering:
  - `asserts:feo11y_latency:p75` for ttfb / lcp / fcp / inp / cls / navigation / user_action / resource
  - `asserts:feo11y_error:ratio_5m` for user_action_errors / page_errors / http_client_errors / http_network_errors / http_server_errors / http_errors (combined)
  - `asserts:kpi:feo11y_navigation:rate_5m` and `asserts:kpi:feo11y_latency:p75` (lcp)
  - `feo11y:error_count`

## Verifying it worked

After `apply`, wait 5-15 minutes for recording-rule evaluation and KG entity
refresh lag, then:

```sh
gcx kg entities list --type Frontend --context wcalldemo
gcx kg entities query "MATCH (f:Frontend {name:\"Bookstore\"})-[r]-(x) RETURN f, r, x" --context wcalldemo
```

A `Frontend` entity named `Bookstore` should now exist, and (if the CALLS
edge resolves as expected) show a relationship to `checkout-service` /
`products-service` / `shipping-service`.
