# python / k8s — Observable Bookstore

Kubernetes manifests for the same stack as [`../docker-compose`](../docker-compose):
React frontend, products/checkout/shipping services, MySQL, PostgreSQL, and
Grafana Alloy → Grafana Cloud.

## Prerequisites

1. **Build & push the images** (there is no in-cluster build):

   ```bash
   cd ../docker-compose
   docker build -t <registry>/bookstore/products:latest -f services/products/Dockerfile services
   docker build -t <registry>/bookstore/checkout:latest -f services/checkout/Dockerfile services
   docker build -t <registry>/bookstore/shipping:latest -f services/shipping/Dockerfile services
   docker build -t <registry>/bookstore/frontend:latest \
     --build-arg VITE_FARO_ENDPOINT=... frontend
   docker push <registry>/bookstore/{products,checkout,shipping,frontend}:latest
   ```

   Then update the `image:` fields in `services/backends.yaml` and
   `frontend/deployment.yaml` to your registry. (For kind/minikube you can load
   images locally instead of pushing.)

2. **Fill in credentials** in [`00-namespace-config.yaml`](00-namespace-config.yaml):
   the `bookstore-db` Secret (DB passwords) and the `grafana-cloud` Secret
   (Grafana Cloud URLs/usernames + one Cloud Access Policy token as each password).

## Apply

```bash
kubectl apply -f 00-namespace-config.yaml
kubectl apply -f mysql/ -f postgres/ -f alloy/ -f services/ -f frontend/
```

Access the storefront:

```bash
kubectl -n bookstore port-forward svc/frontend 8080:80   # http://localhost:8080
```

## Notes

- `mysql/configmap-init.yaml` and `postgres/configmap-init.yaml` and
  `alloy/configmap.yaml` are generated from the docker-compose sources. If you
  change the SQL or Alloy config, regenerate them:

  ```bash
  # Keys are ordered so the seed runs before the DB o11y user script.
  kubectl create configmap mysql-init -n bookstore \
    --from-file=01-init.sql=../docker-compose/databases/mysql/init.sql \
    --from-file=02-dbo11y-user.sql=../docker-compose/databases/mysql/dbo11y-user.sql \
    --dry-run=client -o yaml > mysql/configmap-init.yaml

  # MySQL server config (performance_schema tuning):
  kubectl create configmap mysql-tuning -n bookstore \
    --from-file=dbo11y.cnf=../docker-compose/databases/mysql/dbo11y.cnf \
    --dry-run=client -o yaml > mysql/configmap-tuning.yaml

  # Postgres init (seed + the include script) and server config. The k8s
  # postgresql.conf is a stderr variant (no logging_collector) so pod logs still
  # flow to loki.source.kubernetes; 00-dbo11y-include.sh appends an `include` of it
  # to $PGDATA/postgresql.conf on first init.
  # Keys are ordered so the seed runs before the DB o11y user script.
  kubectl create configmap postgres-init -n bookstore \
    --from-file=00-dbo11y-include.sh=../docker-compose/databases/postgres/dbo11y-include.sh \
    --from-file=01-init.sql=../docker-compose/databases/postgres/init.sql \
    --from-file=02-dbo11y-user.sql=../docker-compose/databases/postgres/dbo11y-user.sql \
    --dry-run=client -o yaml > postgres/configmap-init.yaml
  # (edit postgres/configmap-config.yaml by hand — it's the stderr variant, not a
  #  copy of the compose postgresql.conf which enables logging_collector)
  ```

- **DB o11y Postgres log capture** is the one place the k8s Alloy config diverges
  from docker-compose: instead of the compose `discovery.docker` + `loki.source.docker`
  block, `alloy/configmap.yaml` uses `discovery.kubernetes` (pods labeled
  `app=postgres` in `bookstore`) + `loki.source.kubernetes` to stream the Postgres
  pod's logs into the DB o11y "logs" collector. Reading pod logs requires RBAC —
  `alloy/rbac.yaml` grants Alloy a `ServiceAccount` + `ClusterRole`
  (`pods`, `pods/log`: get/list/watch) and the Deployment runs as that
  `serviceAccountName`.

- The DB init scripts only run on an **empty** data volume (first start), same
  as the container images' entrypoint behavior.
- Databases use `StatefulSet` + `volumeClaimTemplates`; your cluster needs a
  default `StorageClass`.

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
