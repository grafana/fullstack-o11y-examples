# Bookstore Frontend Observability → Knowledge Graph recording rules

> **⚠️ Shared resource** — all 5 language stacks point their frontend at the
> same `wcalldemo` FaroApp ("Bookstore", id 4852); this Terraform has already
> been applied from
> [`python/terraform/frontend-observability/`](../../../python/terraform/frontend-observability/).
> This copy is here for consistency with this repo's per-language-folder
> convention — do not `terraform apply` it as-is alongside that one; see the
> warning at the top of `main.tf`.


Provisions the Grafana-managed recording rules that make Grafana Cloud's
Knowledge Graph discover a `Frontend` entity for the Bookstore FaroApp in
`wcalldemo`, and let its CALLS edge to the backend services resolve. See
comments in `recording_rules.tf` for how each rule was adapted from the
working reference example.

## Usage

This copy is read-only reference — the real apply happens from
[`python/terraform/frontend-observability/`](../../../python/terraform/frontend-observability/)
(see the warning above). It has no local state of its own, so running
`terraform plan` or `terraform apply` here would try to create the folder
and rule group again instead of showing drift against the real ones — don't
run either from this copy. This is as far as it goes:

```sh
cd go/terraform/frontend-observability
terraform init
terraform validate
```

If you actually need to check for drift or make a change, use
[python's copy](../../../python/terraform/frontend-observability/README.md#usage),
which has the state-adoption (`terraform import`) steps this one is missing.

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
