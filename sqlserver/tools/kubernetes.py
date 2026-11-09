"""Render swaps through Kustomize; never apply to a cluster automatically."""
import subprocess
from pathlib import Path

from common import (
    ROOT,
    generated_directory,
    image_name,
    kubernetes_alloy,
    selected_databases,
    selected_services,
    write_json,
)


def deployment_patch(name, container):
    return {"apiVersion": "apps/v1", "kind": "Deployment",
            "metadata": {"name": name, "namespace": "bookstore"},
            "spec": {"template": {"spec": {"containers": [container]}}}}


def secret_env(keys):
    return [{"name": key, "valueFrom": {"secretKeyRef": {
        "name": "bookstore-sqlserver", "key": key}}} for key in keys]


def render_kubernetes(args):
    base = ROOT / args.language / "k8s"
    directory = generated_directory(args.language, args.replacement, "kubernetes")
    excluded = {"00-namespace-config.yaml", "alloy/configmap.yaml"}
    engines = ("mysql", "postgres") if args.replacement == "both" else (args.replacement,)
    resources = [str(p) for p in sorted(base.rglob("*.yaml"))
                 if p.relative_to(base).parts[0] not in engines
                 and str(p.relative_to(base)) not in excluded]
    configmap = {"apiVersion": "v1", "kind": "ConfigMap",
                 "metadata": {"name": "alloy-config", "namespace": "bookstore"},
                 "data": {"config.alloy": kubernetes_alloy(args.language, args.replacement)}}
    write_json(directory / "alloy-config.json", configmap)
    resources.append("alloy-config.json")
    patches = make_patches(args, directory)
    base_image = "bookstore" if args.language == "python" else f"bookstore-{args.language}"
    images = [{"name": f"{base_image}/{name}",
               "newName": image_name(args.language, name, args.registry, args.tag).rsplit(":", 1)[0],
               "newTag": args.tag} for name in ("products", "checkout", "shipping", "frontend")]
    write_json(directory / "kustomization.yaml", {
        "apiVersion": "kustomize.config.k8s.io/v1beta1", "kind": "Kustomization",
        "resources": resources, "patches": [{"path": path} for path in patches], "images": images})
    result = subprocess.run(["kubectl", "kustomize", "--load-restrictor",
                             "LoadRestrictionsNone", str(directory)], check=True,
                            capture_output=True, text=True)
    if args.output:
        Path(args.output).write_text(result.stdout)
    else:
        print(result.stdout, end="")
    return 0


def make_patches(args, directory):
    patches = []
    for name in selected_services(args.replacement):
        keys = ["MSSQL_HOST", "MSSQL_PORT", "MSSQL_USER", "MSSQL_PASSWORD",
                "MSSQL_BOOKSTORE_DB", "MSSQL_SHIPPING_DB"]
        container = {"name": name, "envFrom": [{"configMapRef": {"name": "bookstore-config"}}],
                     "env": secret_env(keys) + [{"name": "MSSQL_TRUST_SERVER_CERTIFICATE",
                                                  "value": "false"}]}
        if args.language == "java":
            container["env"].append({"name": "OTEL_INSTRUMENTATION_COMMON_PEER_SERVICE_MAPPING",
                                     "value": "$(MSSQL_HOST):$(MSSQL_PORT)=rds-sqlserver"})
        filename = f"{name}-patch.json"
        write_json(directory / filename, deployment_patch(name, container))
        patches.append(filename)
    keys = ["MSSQL_HOST", "MSSQL_PORT", "RDS_ARN"]
    for database in selected_databases(args.replacement):
        keys.extend((f"MSSQL_{database.upper()}_DB", f"MSSQL_{database.upper()}_DSN"))
    sources = [{"secretRef": {"name": "grafana-cloud"}}]
    if args.replacement != "both":
        sources.append({"secretRef": {"name": "bookstore-db"}})
    container = {"name": "alloy", "image": alloy_image(args),
                 "env": secret_env(keys), "envFrom": sources}
    write_json(directory / "alloy-patch.json", deployment_patch("alloy", container))
    return patches + ["alloy-patch.json"]


def alloy_image(args):
    prefix = f"{args.registry.rstrip('/')}/" if args.registry else ""
    return f"{prefix}bookstore-sqlserver/alloy:{args.tag}"
