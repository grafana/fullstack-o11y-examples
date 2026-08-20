# Data for the 17 Frontend Observability -> Knowledge Graph recording rules
# (see recording_rules.tf for the resource that renders these). Split out
# here because every rule shares the same ref_id/query_type/
# relative_time_range/datasource/is_paused/record shape (see
# recording_rules.tf's dynamic "rule" block) -- only name/model/labels/metric
# actually vary per rule, which is all that lives here.

locals {
  feo11y_rules = [
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/ttfb"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"ttfb\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap ttfb [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "ttfb"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/lcp"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"lcp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap lcp [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "lcp"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:kpi:feo11y_latency:p75 - Frontend/lcp"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"lcp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap lcp [5m]) by (service_name, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "lcp"
        asserts_source       = "feo11y"
      }
      metric = "asserts:kpi:feo11y_latency:p75"
    },
    {
      name  = "asserts:kpi:feo11y_navigation:rate_5m - Frontend/navigation"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(sum(rate({kind=\\\"event\\\"} |= \\\"event_name=faro.performance.navigation\\\" | logfmt [5m])) by (service_name, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "navigation"
        asserts_source       = "feo11y"
      }
      metric = "asserts:kpi:feo11y_navigation:rate_5m"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/fcp"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"fcp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap fcp [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "fcp"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:feo11y_error:ratio_5m - Frontend/user_action/user_action_errors"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((((sum(count_over_time({kind=\\\"exception\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment, action_name) + sum(count_over_time({kind=\\\"event\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=(0|4[0-9][0-9]|5[0-9][0-9])\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment, action_name)) or sum(count_over_time({kind=\\\"exception\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment, action_name) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"action_name=\\\" != \\\"event_name=faro.user.action\\\" |~ \\\"action_parent_id=\\\" |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=(0|4[0-9][0-9]|5[0-9][0-9])\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment, action_name))) / (sum(count_over_time({kind=\\\"event\\\"} |= \\\"event_name=faro.user.action\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment, action_name) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_error_type   = "user_action_errors"
        asserts_request_type = "user_action"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_error:ratio_5m"
    },
    {
      name  = "asserts:feo11y_error:ratio_5m - Frontend/page_errors"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(sum(rate({kind=\\\"exception\\\"} | logfmt [5m])) by (service_name, page_id, deployment_environment) / sum(rate({kind=\\\"event\\\"} |= \\\"event_name=faro.performance.navigation\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type = "Frontend"
        asserts_error_type  = "page_errors"
        asserts_source      = "feo11y"
      }
      metric = "asserts:feo11y_error:ratio_5m"
    },
    {
      name  = "asserts:feo11y_error:ratio_5m - Frontend/http_client_errors"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=4[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or vector(0)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type = "Frontend"
        asserts_error_type  = "http_client_errors"
        asserts_source      = "feo11y"
      }
      metric = "asserts:feo11y_error:ratio_5m"
    },
    {
      name  = "asserts:feo11y_error:ratio_5m - Frontend/http_network_errors"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |= \\\"event_data_http.status_code=0\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or vector(0)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type = "Frontend"
        asserts_error_type  = "http_network_errors"
        asserts_source      = "feo11y"
      }
      metric = "asserts:feo11y_error:ratio_5m"
    },
    {
      name  = "asserts:feo11y_error:ratio_5m - Frontend/http_server_errors"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=5[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or vector(0)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type = "Frontend"
        asserts_error_type  = "http_server_errors"
        asserts_source      = "feo11y"
      }
      metric = "asserts:feo11y_error:ratio_5m"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/inp"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"inp\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap inp [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "inp"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/cls"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"measurement\\\"} |= \\\"cls\\\" |= \\\"type=web-vitals\\\" | logfmt | unwrap cls [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "cls"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/navigation"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"event\\\"} |= \\\"event_name=faro.performance.navigation\\\" | logfmt | unwrap event_data_duration [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "navigation"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/user_action"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"event\\\"} |= \\\"event_name=faro.user.action\\\" | logfmt | unwrap event_data_userActionDuration [5m]) by (service_name, page_id, deployment_environment, action_name), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "user_action"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name  = "asserts:feo11y_latency:p75 - Frontend/resource"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(quantile_over_time(0.75, {kind=\\\"event\\\"} |= \\\"event_name=faro.performance.resource\\\" |~ \\\"event_data_initiatorType=fetch|event_data_initiatorType=xmlhttprequest\\\" | logfmt | unwrap event_data_duration [5m]) by (service_name, page_id, deployment_environment), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type  = "Frontend"
        asserts_request_type = "resource"
        asserts_source       = "feo11y"
      }
      metric = "asserts:feo11y_latency:p75"
    },
    {
      name   = "feo11y:error_count"
      model  = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"count(count_over_time({kind=\\\"exception\\\", app_id=\\\"${var.faro_app_id}\\\"} | logfmt [5m])) by (service_name, value_template, attribute_value_template, type, hash, attribute_hash)\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {}
      metric = "feo11y:error_count"
    },
    {
      name  = "asserts:feo11y_error:ratio_5m - Frontend/http_errors"
      model = "{\"datasource\":{\"type\":\"loki\",\"uid\":\"grafanacloud-logs\"},\"expr\":\"label_replace(label_replace(((sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |= \\\"event_data_http.status_code=0\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) + sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=4[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) + sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=5[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment)) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |= \\\"event_data_http.status_code=0\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=4[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment) or sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=5[0-9][0-9]\\\" | logfmt [5m])) by (service_name, page_id, deployment_environment)) / (sum(count_over_time({kind=\\\"event\\\"} |~ \\\"event_name=faro.tracing.fetch|event_name=faro.tracing.xml-http-request\\\" |~ \\\"event_data_http.status_code=\\\" | logfmt [5m] )) by (service_name, page_id, deployment_environment) or vector(1)), \\\"service\\\", \\\"$1\\\", \\\"service_name\\\", \\\"(.+)\\\"), \\\"asserts_request_context\\\", \\\"$1\\\", \\\"page_id\\\", \\\"(.+)\\\")\",\"intervalMs\":1800000,\"maxDataPoints\":50000,\"queryType\":\"instant\",\"refId\":\"A\"}"
      labels = {
        asserts_entity_type = "Frontend"
        asserts_error_type  = "http_errors"
        asserts_source      = "feo11y"
      }
      metric = "asserts:feo11y_error:ratio_5m"
    },
  ]
}
