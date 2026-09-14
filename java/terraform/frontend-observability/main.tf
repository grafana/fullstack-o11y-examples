# ⚠️  SHARED RESOURCE — READ BEFORE RUNNING TERRAFORM HERE.
# All 5 language stacks (go, java, nodejs, python, ruby) point their frontend
# at the SAME wcalldemo FaroApp ("Bookstore", id 4852) — the Frontend/RUM
# identity is not per-language. This directory is an identical copy of
# python/terraform/frontend-observability/, kept here only for consistency
# with this repo's convention that each language folder is self-contained.
#
# This is enforced structurally, not just by convention: the backend block
# below points this copy's state at python/terraform/frontend-observability's
# state file, so this directory and python's share the exact same state.
# Running init/plan/apply from here operates on the same one folder + rule
# group as python's copy — there is no second state to accidentally create a
# duplicate resource in. python/'s copy remains the one to use for the actual
# apply workflow (see its README), but this one is safe, not just discouraged.
#
# Provisions Grafana-managed recording rules that let Grafana Cloud's
# Knowledge Graph (Asserts) discover a `Frontend` entity for the Bookstore
# FaroApp in the `wcalldemo` stack, and (once that entity exists) resolve its
# CALLS edge to the backend services it talks to.
#
# The Bookstore FaroApp is already correctly registered and already sends
# correctly-propagated distributed traces to the backend (confirmed live via
# gcx), but no `Frontend`-typed entity is ever created because nothing
# produces a metric tagged `asserts_entity_type = "Frontend"` for it. This
# module is that missing piece, adapted from the working reference example
# in field-eng-appenv-workspace's frontend_o11y_recording_rules.tf.

terraform {
  required_version = ">= 1.9"

  backend "local" {
    path = "../../../python/terraform/frontend-observability/terraform.tfstate"
  }

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
