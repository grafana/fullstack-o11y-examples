# Swap a database with SQL Server RDS

Use SQL Server RDS for the bookstore database, shipping database, or both in any
of the Python, Go, Node.js, Java, and Ruby examples. The storefront, HTTP APIs,
trace propagation, profiling, and native backend for the other database come
from the existing language stack. SQL Server services use the same seed data and
API contracts, with SQL Server drivers and SQL syntax.

| Selection | Products and checkout | Shipping |
| --- | --- | --- |
| `mysql` | SQL Server RDS / bookstore | PostgreSQL |
| `postgres` | MySQL | SQL Server RDS / shipping |
| `both` | SQL Server RDS / bookstore | SQL Server RDS / shipping |

`scripts/swap-db` renders the selected Compose configuration or Kubernetes
manifests. It omits the replaced database and its collectors. Generated files
live in `.sqlserver/` and are ignored by Git. Python 3.10+ is required; Compose
rendering uses Docker Compose v2, and Kubernetes rendering uses `kubectl kustomize`.

## Prepare SQL Server RDS

Use an existing SQL Server 2022 RDS endpoint, or provision one with the
[Terraform module](../terraform/rds-sqlserver/README.md). When reusing the RDS
instance from another checkout, continue managing it with that checkout's
Terraform state. Do not provision a second instance with the same identifier or
have two Terraform states manage the same resources.

Allow the application's and Alloy's outbound IP addresses to reach RDS on TCP
1433. For Kubernetes, this is the cluster's egress address rather than your
laptop's public IP. The sample Terraform creates a public demo endpoint with
ingress restricted to your chosen CIDR.

Connect as the RDS master user and run these scripts in order. The SQLCMD
password placeholders require passwords without single quotes:

1. `setup.sql` in SQLCMD mode: replace the two password placeholders first. It
   creates bookstore/shipping, enables Query Store, and grants separate app and
   database monitoring logins the permissions they need.
2. `bookstore.sql`: create and seed the catalog, customers, and orders.
3. `shipping.sql`: create and seed warehouses and shipments.
4. `verify.sql`: check the schema and Query Store configuration.

The seed scripts initialize fresh databases; they do not migrate data between
engines. Use the application login for services and the monitoring login for
Alloy. Keep credentials out of version control.

## Docker Compose

Configure one shared Compose env file for all five languages:

```sh
cp sqlserver/compose/.env.example sqlserver/compose/.env
# Edit sqlserver/compose/.env with RDS and Grafana Cloud settings.
export BOOKSTORE_ENV_FILE="$PWD/sqlserver/compose/.env"
```

Set `MSSQL_HOST`, the app password, `RDS_ARN`, and both monitoring DSNs. The DSNs
use the monitoring login and must URL-encode special characters in its password.
Quote Compose `.env` passwords containing `$` with single quotes to prevent
interpolation. Keep TLS verification enabled: the service images and Alloy image
include the AWS RDS CA bundle from the official AWS truststore.

The shared file includes the normal MySQL/PostgreSQL settings needed for mixed
deployments. If you prefer each language's existing `.env`, leave
`BOOKSTORE_ENV_FILE` unset and append the RDS block from `sqlserver/.env.example`
to that language's file.

Run a swap from the repository root:

```sh
./scripts/swap-db compose go postgres up --build -d
./scripts/swap-db compose go postgres logs -f
./scripts/swap-db compose go postgres down

# Products and checkout on RDS, PostgreSQL shipping:
./scripts/swap-db compose python mysql up --build -d

# All three backend services on RDS:
./scripts/swap-db compose nodejs both up --build -d
```

Replace the language with `java` or `ruby` as needed. Pass `--env-file` before
the language to use another env file:

```sh
./scripts/swap-db compose --env-file /path/to/demo.env java both up --build -d
```

Open http://localhost:8080. Stop the current stack before changing selections or
languages; the stacks share ports and container names. Use the same language and
selection with `down`. Then start the next choice with `up --build -d`; Compose
recreates the affected services. Database volumes survive a normal `down`.
Return to the native stack with `docker compose up --build -d` from the
language's `docker-compose` directory. RDS data remains in RDS when you switch.

On Apple Silicon, an older container VM can make the native Python/MySQL
services exit with `SIGILL` while importing `cryptography`. Update the container
runtime and VM before changing application dependencies. The
[upstream report](https://github.com/pyca/cryptography/issues/14764) describes the
same failure during module import.

## Kubernetes

Configure the normal database and Grafana Secrets in the language's
`k8s/00-namespace-config.yaml`, as described in its Kubernetes README. Run only
one language/selection in the `bookstore` namespace at a time.

Build and push images for the selected combination (use a registry accessible
to the cluster). This builds the selected SQL Server services, the retained
native services, the existing frontend, and Alloy with the RDS CA bundle:

```sh
./scripts/swap-db build go postgres --registry ghcr.io/YOUR_ORG --tag rds-postgres-v1 --push
./scripts/swap-db kubernetes go postgres --registry ghcr.io/YOUR_ORG \
  --tag rds-postgres-v1 --output /tmp/bookstore-go-rds.yaml
```

Default image tags include the selection, such as `sqlserver-postgres`. Use a
new `--tag` for each revision you push to a cluster to avoid cached images.

The build uses `VITE_FARO_ENDPOINT`, `VITE_ASSERTS_ENV`, and `VITE_SESSION_REPLAY`
from your shell when set, so use the same frontend telemetry settings as the
normal image build. For kind/minikube, omit the registry and load the images
into the cluster instead of pushing them.

Create the RDS Secret from a local file based on `sqlserver/.env.example`.
`kubectl --from-env-file` expects unquoted literal values, not shell exports or
Compose interpolation. The rendering command leaves this Secret external:

```sh
kubectl apply -f go/k8s/00-namespace-config.yaml
kubectl -n bookstore create secret generic bookstore-sqlserver \
  --from-env-file=sqlserver/.env --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f /tmp/bookstore-go-rds.yaml
kubectl -n bookstore rollout status deployment/products
kubectl -n bookstore rollout status deployment/checkout
kubectl -n bookstore rollout status deployment/shipping
kubectl -n bookstore port-forward svc/frontend 8080:80
```

Applying a different selection does not delete resources omitted from its
manifest. When switching an existing Kubernetes deployment, delete the old
selection's rendered manifest first, then apply the new one and recreate the
external SQL Server Secret if necessary. The same applies when switching from
the normal manifests: delete the old Deployments/Services and replaced database
StatefulSets before applying the selection. Keep PVCs if you want to retain the
native seed data. Never use `kubectl delete namespace bookstore` to switch.

## Observability and verification

Alloy receives the existing app traces, metrics, logs, Faro telemetry, and
profiles. It keeps collectors for the native database and adds a SQL Server
collector for each selected database. The `query_samples` collector is disabled
because the monitoring user has database-scoped grants. Query metrics, details,
schema details, and Query Store explain plans remain available. The SQL Server
component is experimental and the configurations enable experimental stability.
See the [SQL Server component reference](https://grafana.com/docs/alloy/latest/reference/components/database_observability/database_observability.sql_server/).

Run the shared HTTP contract check against a running stack; it checks catalog
reads, a checkout, order lookup, and shipment lookup. It creates one demo order:

```sh
python3 sqlserver/tests/smoke.py --url http://localhost:8080
```

Render tests cover all five languages and three selections for both Compose
and Kubernetes. No cloud credentials or running databases are needed:

```sh
python3 -m pip install -r sqlserver/tests/requirements.txt
python3 -m unittest discover -s sqlserver/tests -p 'test_*.py'
```

Stop Compose with the same `swap-db ... down` command or delete the rendered
Kubernetes manifest. These operations leave RDS running. Manage RDS cleanup from
the Terraform checkout/state that owns it. RDS and snapshot storage may incur
AWS charges.

## Blocking and error scenarios

Two optional scripts in `sqlserver/scenarios/` generate lock waits and query
errors for the Database Observability views. Run them as the application
login; they change no data.

- `blocking.sql` holds a row lock in one sqlcmd session so a second session
  waits on it (`LCK_M_U`), with a bounded variant that fails with error 1222.
  Run it in two interactive sqlcmd windows; the file explains each step.
- `errors.sql` triggers constraint, conversion, overflow, permission, and
  custom errors in `bookstore` and `shipping`, none of them divide by zero:

```sh
sqlcmd -S <rds-endpoint>,1433 -U bookstore_app -C -i sqlserver/scenarios/errors.sql
```
