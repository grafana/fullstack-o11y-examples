# nodejs / k8s — Observable Bookstore

Kubernetes manifests for the Node.js stack (same app as [`../docker-compose`](../docker-compose)):
React frontend, products/checkout/shipping services, MySQL, PostgreSQL, and
Grafana Alloy → Grafana Cloud. Structurally identical to the
[Python k8s reference](../../python/k8s); images are tagged `bookstore-nodejs/*`
to avoid colliding with the other language images.

## Prerequisites

1. **Build & push the images** (no in-cluster build):

   ```bash
   cd ../docker-compose
   docker build -t <registry>/bookstore-nodejs/products:latest -f services/products/Dockerfile services
   docker build -t <registry>/bookstore-nodejs/checkout:latest -f services/checkout/Dockerfile services
   docker build -t <registry>/bookstore-nodejs/shipping:latest -f services/shipping/Dockerfile services
   docker build -t <registry>/bookstore-nodejs/frontend:latest \
     --build-arg VITE_FARO_ENDPOINT=... --build-arg VITE_ASSERTS_ENV=dev frontend
   docker push <registry>/bookstore-nodejs/{products,checkout,shipping,frontend}:latest
   ```

   Then update the `image:` fields in `services/backends.yaml` and
   `frontend/deployment.yaml` to your registry. (For kind/minikube, load the
   images locally instead of pushing.)

2. **Fill in credentials** in [`00-namespace-config.yaml`](00-namespace-config.yaml):
   the `bookstore-db` and `grafana-cloud` Secrets.

## Apply

```bash
kubectl apply -f 00-namespace-config.yaml
kubectl apply -f mysql/ -f postgres/ -f alloy/ -f services/ -f frontend/
kubectl -n bookstore port-forward svc/frontend 8080:80   # http://localhost:8080
```

## Notes

- The `bookstore` namespace matches the Python reference, so deploy **one
  language at a time** into a cluster (or edit the namespace to run side by side).
- `mysql/configmap-init.yaml`, `postgres/configmap-init.yaml`, and
  `alloy/configmap.yaml` are generated from the docker-compose sources — see the
  [Python k8s README](../../python/k8s/README.md#notes) for the regenerate commands.
- **DB o11y Postgres log capture** diverges from docker-compose: `alloy/configmap.yaml`
  uses `discovery.kubernetes` + `loki.source.kubernetes` (not the compose
  `loki.source.docker`) to stream the Postgres pod's logs into the DB o11y "logs"
  collector, and `alloy/rbac.yaml` grants Alloy a `ServiceAccount` + `ClusterRole`
  (`pods`, `pods/log`) to read them. See the
  [Python k8s README](../../python/k8s/README.md#notes) for details.
- Databases use `StatefulSet` + `volumeClaimTemplates`; the init scripts run only
  on an empty data volume (first start).
- The postgres StatefulSet mounts its volume at `/var/lib/postgresql` (not
  `/var/lib/postgresql/data`) with no `PGDATA` override, matching postgres:18.

## Layout

```
k8s/
├── 00-namespace-config.yaml   # Namespace, ConfigMap, Secrets
├── mysql/       {configmap-init, configmap-tuning, statefulset}.yaml
├── postgres/    {configmap-init, configmap-config, statefulset}.yaml
├── alloy/       {configmap, deployment, rbac}.yaml
├── services/    backends.yaml   (products + checkout + shipping)
└── frontend/    deployment.yaml (Deployment + Service + Ingress)
```
