# Frontend Observability -> Knowledge Graph recording rules for the Bookstore
# FaroApp (wcalldemo, app id var.faro_app_id, name var.faro_app_name).
#
# Adapted from field-eng-appenv-workspace's frontend_o11y_recording_rules.tf.
# Unlike that reference, Bookstore's Loki stream already carries `service_name`
# and `deployment_environment` as native indexed labels (confirmed live via
# `gcx logs query '{kind="measurement"}' --context wcalldemo`), so these
# rules group on those directly instead of extracting `app` /
# `resource_deployment_environment` from the log body via logfmt.
#
# Each rule converts raw Faro RUM logs (kind=measurement/event/exception) into
# an `asserts:feo11y_*` / `feo11y:*` Prometheus series tagged
# `asserts_entity_type = "Frontend"`, which is what makes Asserts discover a
# Frontend-typed Knowledge Graph entity for Bookstore in the first place.

resource "grafana_folder" "frontend_observability_asserts" {
  title = "bookstore-frontend-observability-asserts"
}

resource "grafana_rule_group" "frontend_observability_asserts" {
  name             = "frontend-observability-asserts"
  folder_uid       = grafana_folder.frontend_observability_asserts.uid
  interval_seconds = 60

  # Every rule shares this same shape (ref_id, query_type, relative_time_range,
  # datasource_uid, is_paused, record.from/target_datasource_uid); only
  # name/model/labels/metric vary, so those live in local.feo11y_rules
  # (feo11y_rules.tf) and get rendered here via one dynamic block instead of
  # 17 near-identical static ones.
  dynamic "rule" {
    for_each = local.feo11y_rules
    content {
      name = rule.value.name

      data {
        ref_id     = "A"
        query_type = "instant"

        relative_time_range {
          from = 300
          to   = 0
        }

        datasource_uid = "grafanacloud-logs"
        model          = rule.value.model
      }

      labels    = rule.value.labels
      is_paused = false

      record {
        metric                = rule.value.metric
        from                  = "A"
        target_datasource_uid = "grafanacloud-prom"
      }
    }
  }
}
