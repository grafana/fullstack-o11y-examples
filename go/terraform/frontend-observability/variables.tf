variable "grafana_auth" {
  description = <<-EOT
    Grafana Cloud auth token for the wcalldemo stack, with alerting-rule
    write scope (needed to create grafana_rule_group / grafana_folder
    resources). Never set a default or write this to a file — supply it via
    the TF_VAR_grafana_auth environment variable at plan/apply time, e.g.:

      export TF_VAR_grafana_auth=$(grep '^GRAFANA_SERVICE_ACCOUNT_TOKEN=' \
        ../../docker-compose/.env.wcalldemo | cut -d= -f2-)
  EOT
  type        = string
  sensitive   = true
}

variable "faro_app_id" {
  description = "Bookstore FaroApp id in wcalldemo (gcx frontend apps list --context wcalldemo)."
  type        = string
  default     = "4852"
}

variable "faro_app_name" {
  description = <<-EOT
    Bookstore FaroApp name in wcalldemo. Matches the `service_name` Loki
    label on Faro logs and the `client` / `asserts_relation_src_service`
    label on the traces_service_graph_request_total metric.
  EOT
  type        = string
  default     = "Bookstore"
}
