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

  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/ttfb"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"ttfb\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap ttfb [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "ttfb"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/lcp"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"lcp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap lcp [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "lcp"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:kpi:feo11y_latency:p75 - Frontend/lcp"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"lcp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap lcp [5m]) by (service_name, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "lcp"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:kpi:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:kpi:feo11y_navigation:rate_5m - Frontend/navigation"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(sum(rate({kind=\\\"event\\\"} |= \\\"event_name=faro.performance.navigation\\\" | logfmt [5m])) by (service_name, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "navigation"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:kpi:feo11y_navigation:rate_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/fcp"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"fcp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap fcp [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "fcp"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_error:ratio_5m - Frontend/user_action/user_action_errors"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((((sum(count_over_time({kind=\\\"exception\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment, action_name) + sum(count_over_time({kind=\\\"event\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=(0|4[0-9][0-9]|5[0-9][0-9])\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment, action_name)) or sum(count_over_time({kind=\\\"exception\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment, action_name) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=(0|4[0-9][0-9]|5[0-9][0-9])\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment, action_name))) / (sum(count_over_time({kind=\\\"event\\\"} |= \\\"event_name=faro.user.action\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment, action_name) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_error_type   = "user_action_errors"
      asserts_request_type = "user_action"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_error:ratio_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_error:ratio_5m - Frontend/page_errors"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(sum(rate({kind=\\\"exception\\\"} | logfmt [5m])) by (service_name, page_id, deployment_environment) / sum(rate({kind=\\\"event\\\"} |= \\\"event_name=faro.performance.navigation\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type = "Frontend"
      asserts_error_type  = "page_errors"
      asserts_source      = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_error:ratio_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_error:ratio_5m - Frontend/http_client_errors"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=4[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or vector(0)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type = "Frontend"
      asserts_error_type  = "http_client_errors"
      asserts_source      = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_error:ratio_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_error:ratio_5m - Frontend/http_network_errors"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |= \\\"event_data_http.status_code=0\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or vector(0)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type = "Frontend"
      asserts_error_type  = "http_network_errors"
      asserts_source      = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_error:ratio_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_error:ratio_5m - Frontend/http_server_errors"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=5[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or vector(0)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type = "Frontend"
      asserts_error_type  = "http_server_errors"
      asserts_source      = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_error:ratio_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/inp"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"inp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap inp [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "inp"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/cls"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"cls\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap cls [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "cls"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/navigation"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"event\\\"} |= \\\"event_name=faro.performance.navigation\\\" | logfmt | unwrap event_data_duration [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "navigation"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/user_action"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"event\\\"} |= \\\"event_name=faro.user.action\\\" | logfmt | unwrap event_data_userActionDuration [5m]) by (service_name, page_id, deployment_environment, action_name), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "user_action"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_latency:p75 - Frontend/resource"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"event\\\"} |= \\\"event_name=faro.performance.resource\\\" |~ \\\"event_data_initiatorType=fetch|event_data_initiatorType=xmlhttprequest\\\" | logfmt | unwrap event_data_duration [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type  = "Frontend"
      asserts_request_type = "resource"
      asserts_source       = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_latency:p75"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "feo11y:error_count"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"count(count_over_time({kind=\\\"exception\\\", app_id=\\\"${var.faro_app_id}\\\"} | logfmt [5m])) by (service_name, value_template, attribute_value_template, type, hash, attribute_hash)\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels    = {}
    is_paused = false

    record {
      metric                = "feo11y:error_count"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
  rule {
    name = "asserts:feo11y_error:ratio_5m - Frontend/http_errors"

    data {
      ref_id     = "A"
      query_type = "instant"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = "grafanacloud-logs"
      model          = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |= \\\"event_data_http.status_code=0\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) + sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=4[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) + sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=5[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment)) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |= \\\"event_data_http.status_code=0\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=4[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=5[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
    }

    labels = {
      asserts_entity_type = "Frontend"
      asserts_error_type  = "http_errors"
      asserts_source      = "feo11y"
    }
    is_paused = false

    record {
      metric                = "asserts:feo11y_error:ratio_5m"
      from                  = "A"
      target_datasource_uid = "grafanacloud-prom"
    }
  }
}
