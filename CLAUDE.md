# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A teaching/demo project that evolves the **same simple banking app** through progressively more
"real-world" infrastructure, one numbered phase at a time. It is not one deployable system — it is
a series of snapshots. Each `phaseN-*/` directory is largely self-contained and has its own
`PHASEN.md` (mostly written in Vietnamese) explaining that phase's goal. When working in this repo,
first figure out **which phase/version** a file belongs to — code, Helm values, and CI logic are
deliberately duplicated across phases rather than shared, so a fix in one phase does not
automatically apply to another.

Rough phase map:

| Path | Phase | What it adds |
|---|---|---|
| `services/`, `frontend/`, `common/`, `k8s/`, `kong/`, `docker-compose.yml` | V1 (baseline) | Plain FastAPI microservices behind Kong, run via Docker Compose or raw K8s manifests (`k8s/`) |
| `phase1-docker-to-k8s/` | Phase 1 | Same V1 app as raw Kubernetes manifests (Postgres/Redis as StatefulSets, HAProxy Ingress) |
| `phase2-helm-chart/` | Phase 2 | V1 app packaged as a Helm chart (`helm-quickstart/`) instead of raw manifests; ArgoCD app-of-apps intro |
| `phase3-monitoring-keda/` | Phase 3 | Prometheus/Grafana, Loki/Promtail, OTel/Tempo, KEDA autoscaling, k6 load tests |
| `phase4-application-v2/` | Phase 4 | **App v2**: login by phone number + generated account number, tuned DB pool, Redis Sentinel support, structured JSON logging (`common/logging_utils.py`) |
| `phase5-architecture-refactor/` | Phase 5 | Splits Kong/Redis/Postgres into their own namespaces and Helm charts; Kong moves to DB-backed mode |
| `phase6-deployment-strategies/` | Phase 6 | Blue-green and canary rollout patterns on top of the Phase 2 chart |
| `phase7-security-reliability/` | Phase 7 | JWT/session hardening, Kong security plugins, WAF, SLOs; also the CI file `devsecops-pr.yml` |
| `phase8-application-v3/` | Phase 8 | **App v3**: adds `producer/` (API Producer) + RabbitMQ, i.e. HTTP → MQ → worker instead of direct HTTP-to-service calls; masks amounts/account numbers in logs |
| `phase9-gitops-platform/` | Phase 9 | Full GitOps platform: Jenkins (Kaniko builds) → Harbor registry → ArgoCD; Vault + External Secrets |
| `helm/` (root) | current | Consolidated/latest Helm chart, split per-service under `helm/charts/*`; values wired for ArgoCD (`argcd/application.yaml`-style `valueFiles`) |
| `aws/` | — | Terraform for an EKS cluster + supporting VPC/IAM/EC2 modules (has real `terraform.tfstate` — treat as live state) |
| `ibm-cloud-deployment/` | — | Deployment guides for running the demo on IBM Cloud (TechZone/IKS/OpenShift); mostly docs |
| `k8s-chatbot/` | — | **Unrelated side project**: a natural-language Kubernetes ops chatbot (FastAPI backend + Vite/React frontend) used to query pods/logs/metrics via k8s API, Loki, Prometheus, with an LLM parser and Chroma-based RAG. Independent of the banking app. |

When a task only mentions "the app" without a phase, assume the **root-level V1** app
(`services/`, `frontend/`, `common/`) unless context (a phaseN path, an app v2/v3 feature) says
otherwise.

## Core application architecture (all versions)

Four Python FastAPI microservices + a React frontend, fronted by Kong, sharing one Postgres DB and
one Redis instance:

- **auth-service** (`/api/auth`, container port 8001) — register/login, bcrypt password hashing
  (`common/auth.py`), issues an opaque session token stored in Redis (`common/redis_utils.py`).
- **account-service** (`/api/account`, port 8002) — reads the caller's profile/balance.
- **transfer-service** (`/api/transfer`, port 8003) — moves money between users inside one DB
  transaction using `SELECT ... FOR UPDATE` on both rows to avoid race conditions, then publishes a
  Redis pub/sub notification.
- **notification-service** (`/api/notifications`, `/ws`, port 8004) — lists notifications and pushes
  them over a WebSocket by subscribing to the Redis channel transfer-service publishes to; also
  tracks presence via a TTL'd Redis key.

Shared code lives in `common/` (or the phase-specific copy, e.g. `phase4-application-v2/common/`)
and is **copied into each service's Docker image at build time** (see each service's Dockerfile) —
it is not an installed package. There is no service-to-service HTTP or gRPC; the only two shared
resources are Postgres (SQLAlchemy models in `common/models.py`: `User`, `Transfer`,
`Notification`) and Redis (sessions, pub/sub, presence).

Auth model: the frontend gets a session id from `/login` and sends it back as the `X-Session`
header (see `frontend/src/api.js`); services resolve it to a user id via
`common.redis_utils.get_user_id_from_session`. There is no JWT in the baseline app (Phase 7 adds
JWT/refresh-token hardening on top of this).

Every service wires up the same three cross-cutting pieces via `common/observability.py`:
OpenTelemetry tracing (only if `OTEL_EXPORTER_OTLP_ENDPOINT` is set), Prometheus metrics at
`/metrics`, and a `/health` endpoint that pings both Postgres and Redis. Keep new endpoints
consistent with that pattern — call `instrument_fastapi(app, "<service-name>")` in `lifespan`.

Kong (`kong/kong.yml` for V1, declarative mode) maps `/api/auth`, `/api/account`, `/api/transfer`,
`/api/notifications`, and `/ws` to the four services, stripping the path prefix and applying CORS.
The frontend calls everything through Kong at the same origin (`frontend/src/api.js` uses a
relative `API = ""`).

In app v2 (`phase4-application-v2`), `User` gains `phone` (login identifier) and a generated unique
`account_number`; `username` becomes display-only. In app v3 (`phase8-application-v3`), requests
flow through a new `api-producer` service that publishes to RabbitMQ and awaits a reply via Redis
(`common/rabbitmq_utils.py`) instead of the frontend/Kong calling the FastAPI services directly for
those routes — check `phase8-application-v3/producer/main.py` before assuming a Phase-8 request
takes the V1 path.

## Common commands

Run the baseline (V1) stack locally with Docker Compose:

```sh
docker compose up -d --build
```

- Frontend: http://localhost:3000
- API through Kong: http://localhost:8000
- Kong Admin API: http://localhost:8001

Frontend dev loop (`frontend/`, plain CRA + Tailwind — same commands apply under
`phase4-application-v2/frontend`):

```sh
npm install
npm start        # dev server
npm run build    # production build
```

Python services have no local venv/tooling config beyond `common/requirements.txt`
(`phase4-application-v2/requirements-dev.txt` adds `pytest`, `httpx`, `ruff` for that phase). From
repo root:

```sh
pip install -r common/requirements.txt
pip install -r phase4-application-v2/requirements-dev.txt   # for lint/test tooling

ruff check common services --ignore E501                    # lint V1
ruff check phase4-application-v2/common phase4-application-v2/services --ignore E501

python -m compileall common services                        # syntax-check V1/V2/V3 trees
pytest -q phase4-application-v2/tests                        # only phase4 has real tests
pytest -q phase4-application-v2/tests/test_api_contracts.py -k account_service   # single test
```

`phase4-application-v2/tests/test_api_contracts.py` loads each service's `main.py` directly (no
package install) with `DATABASE_URL=sqlite+pysqlite:///:memory:`, so a service must still boot
against SQLite for these contract tests to pass — avoid introducing Postgres-only SQL there.

There is no root-level `Makefile`/npm script that runs everything; use the commands above per
component. CI (`.github/workflows/ci.yml`) is the source of truth for exact lint/test/build
invocations if a command here goes stale — it only lints/tests, ignoring failures on lint
(`|| true`) and treating tests as advisory (`|| true`) except for the actual pytest run.

## CI/CD shape (don't assume GitHub-native)

- `.github/workflows/ci.yml` runs on push to `main`/`develop` (or manual dispatch choosing
  `v1`/`v2`/`v3` + service). It detects which services changed via path filters, lints, tests
  (Phase 4 only), builds Docker images for the matching version's Dockerfiles, and **pushes to a
  GitLab container registry** (`registry.gitlab.com`), not GHCR — despite `docker-compose.yml`
  referencing `ghcr.io/...` images. After a push to `main` it also auto-commits updated image tags
  into `phase2-helm-chart/banking-demo/charts/*/values.yaml` for GitOps, and runs a Trivy scan.
- `.github/workflows/devsecops-pr.yml` is the pipeline that actually runs on pull requests into
  `main` (the CI workflow above explicitly does not trigger on PRs).
- `.github/workflows/k8s-chatbot-ci.yml` is separate and only concerns `k8s-chatbot/`.
- Editing Helm values/K8s manifests alone does not trigger `ci.yml` (path filters exclude them) —
  only `common/`, `services/`, `frontend/`, and `phase8-application-v3/` do.

## Working conventions specific to this repo

- Comments, commit messages in some workflows, and several `PHASEN.md`/`README.md` docs are written
  in Vietnamese; match the existing language when editing those files rather than translating them.
- When changing shared logic (`common/*.py`), check whether the same fix is needed in the
  phase-specific copies (`phase4-application-v2/common/`, `phase8-application-v3/common/`) — they
  have diverged (different pooling, Redis Sentinel support, masking helpers, RabbitMQ) and are not
  kept in sync automatically.
- Multiple independent Helm charts exist for the "same" app at different phases
  (`phase2-helm-chart/helm-quickstart`, `phase6-deployment-strategies/helm-deployment-strategies`,
  `helm/` at root). Confirm which one a request refers to before editing values/templates.
- `aws/terraform.tfstate` is committed in-repo — treat `aws/` Terraform changes as touching real
  state, not just example code.
