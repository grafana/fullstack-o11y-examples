#!/bin/sh
# Append an `include` of the mounted DB o11y server config to the freshly
# initialized postgresql.conf (idempotent). Runs once during initdb; the include
# persists in PGDATA and is read on every subsequent server start. No `set -e`:
# in k8s this is sourced (ConfigMap files aren't executable), so a failing guard
# must not abort the entrypoint — the `||` append handles the one command itself.
CONF="$PGDATA/postgresql.conf"
LINE="include = '/etc/postgresql/postgresql.conf'"
grep -qF "$LINE" "$CONF" || printf '\n# Grafana Database Observability settings\n%s\n' "$LINE" >> "$CONF"
