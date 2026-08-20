# ⚠️  SHARED RESOURCE — READ BEFORE RUNNING TERRAFORM HERE.
# All 5 language stacks (go, java, nodejs, python, ruby) point their frontend
# at the SAME wcalldemo FaroApp ("Bookstore", id 4852) — the Frontend/RUM
# identity is not per-language. This directory is an identical copy of
# python/terraform/frontend-observability/, kept here only for consistency
# with this repo's convention that each language folder is self-contained.
#
# The folder + rule group these files describe have ALREADY been applied
# from python/terraform/frontend-observability/ against wcalldemo. Do NOT
# run `terraform apply` from more than one language folder — each has its
# own local state, so a second apply will try to create a second folder with
# the same title/rule group name and fail (or, if names were changed,
# produce genuinely duplicate/conflicting rules). If you need to manage this
# from a different folder than python/, first remove/rename
# python/terraform/frontend-observability/'s local state or `terraform state
# mv`/import the existing resources into this directory before applying.
#
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
