# Bookstore Frontend Observability → Knowledge Graph recording rules

Provisions the Grafana-managed recording rules that make Grafana Cloud's
Knowledge Graph discover a `Frontend` entity for the Bookstore FaroApp in
`wcalldemo`, and let its CALLS edge to the backend services resolve. See
comments in `recording_rules.tf` for how each rule was adapted from the
working reference example.

## Usage

⚠️ **The folder and rule group below already exist in `wcalldemo`** (see "What
this creates"). `terraform.tfstate` is gitignored on purpose — state files can
carry sensitive data and shouldn't live in git — but that means a fresh clone
has no record of them, and a naive `plan`/`apply` here will try to create
duplicates. Import the existing resources into your local state first:

```sh
cd python/terraform/frontend-observability
terraform init
terraform validate

# Auth: a Grafana Cloud token for wcalldemo with alerting-rule write scope.
# Never write this to a file — export it for this shell session only:
export TF_VAR_grafana_auth=$(grep '^GRAFANA_SERVICE_ACCOUNT_TOKEN=' ../../docker-compose/.env.wcalldemo | cut -d= -f2-)

# First time in a fresh checkout: adopt the existing folder + rule group into
# your local state instead of creating new ones.
FOLDER_UID=$(curl -fsS -H "Authorization: Bearer $TF_VAR_grafana_auth" \
  https://wcalldemo.grafana.net/api/folders \
  | jq -r '.[] | select(.title=="bookstore-frontend-observability-asserts") | .uid')
terraform import grafana_folder.frontend_observability_asserts "$FOLDER_UID"
terraform import grafana_rule_group.frontend_observability_asserts "$FOLDER_UID:frontend-observability-asserts"

terraform plan -out=tfplan   # should show "No changes." once imported —
                              # if it wants to add/change/destroy something,
                              # stop and figure out why before applying
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
