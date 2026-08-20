# Provisions Grafana-managed recording rules that let Grafana Cloud's
# Knowledge Graph (Asserts) discover a `Frontend` entity for the Bookstore
# FaroApp in the `wcalldemo` stack, and (once that entity exists) resolve its
# CALLS edge to the backend services it talks to.
#
# See ../../../docs/kg-validation.md for the investigation that led here:
# the Bookstore FaroApp is already correctly registered and already sends
# correctly-propagated distributed traces to the backend (confirmed live via
# gcx), but no `Frontend`-typed entity is ever created because nothing
# produces a metric tagged `asserts_entity_type = "Frontend"` for it. This
# module is that missing piece, adapted from the working reference example
# in field-eng-appenv-workspace's frontend_o11y_recording_rules.tf.

terraform {
  required_version = ">= 1.9"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
  }
}

provider "grafana" {
  url  = "https://wcalldemo.grafana.net/"
  auth = var.grafana_auth
}
