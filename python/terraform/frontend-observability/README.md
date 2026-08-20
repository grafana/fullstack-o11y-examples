# Bookstore Frontend Observability → Knowledge Graph recording rules

Provisions the Grafana-managed recording rules that make Grafana Cloud's
Knowledge Graph discover a `Frontend` entity for the Bookstore FaroApp in
`wcalldemo`, and let its CALLS edge to the backend services resolve. See
comments in `recording_rules.tf` for how each rule was adapted from the
working reference example.

## Usage

```sh
cd python/terraform/frontend-observability
terraform init
terraform validate

# Auth: a Grafana Cloud token for wcalldemo with alerting-rule write scope.
# Never write this to a file — export it for this shell session only:
export TF_VAR_grafana_auth=$(grep '^GRAFANA_CLOUD_API_KEY=' ../../docker-compose/.env.wcalldemo | cut -d= -f2)

terraform plan -out=tfplan   # review what would be created
terraform apply tfplan       # only after reviewing the plan
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
