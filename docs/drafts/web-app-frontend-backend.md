# Design Doc: Polyglot CI/CD Pipeline for FastAPI & Node.js

**Author:** Alistair Y. Lewars

**Date:** 2026-02-24

**Status:** DRAFT

**Tags:** #design #platform #devops #kubernetes

---

## 1. Status

| Field | Value |
| --- | --- |
| **Status** | DRAFT

 |
| **Owner** | Alistair Y. Lewars

 |
| **Reviewers** | Platform Engineering Team

 |
| **Updated** | 2026-02-24

 |

---

## 2. Abstract

This document outlines the architecture for an automated, production-grade CI/CD pipeline supporting a monorepo containing a FastAPI backend and a Node.js frontend. The solution focuses on standardizing the developer experience through hierarchical Taskfiles and ensuring high-integrity deployments to an on-prem Kubernetes cluster via GitHub Actions.

---

## 3. Background

The current state of development requires a more robust automation strategy to handle polyglot applications. This proposal addresses the need for repeatable local builds, ephemeral testing environments for pull requests, and a secure, signed path to production that integrates observability from day one.

---

## 4. Goals & Non-Goals

### Goals

* **Unified Task Execution:** Use a root-level Taskfile to orchestrate sub-projects (backend/frontend) while maintaining local execution parity.


* **Ephemeral Environments:** Automatically deploy feature branches to unique Kubernetes namespaces based on PR ID.


* **Continuous Deployment:** Enable automatic deployment to production upon merging to the `main` branch.


* **Security Shift-Left:** Integrate image scanning (Trivy) and cryptographic signing (Cosign) into the build process.
* **Native Observability:** Implement auto-instrumentation for tracing and metrics using the OpenTelemetry Operator.

### Non-Goals

* Migration of legacy Jenkins workloads.


* Support for multi-cloud deployments; the initial target is the on-prem environment only.


* Implementing a pull-based GitOps model (ArgoCD/Flux) in this initial phase.

---

## 5. Proposed Architecture

The pipeline utilizes **GitHub Actions** as the orchestrator and **Task** as the execution engine. The core logic is decoupled from the CI provider, allowing developers to run the exact same pipeline stages locally.

### Technical Specification

The following expanded **Technical Specification** provides the implementation-level details for the polyglot CI/CD architecture. It integrates the hierarchical task management, container strategy, security gates, and deployment mechanics discussed. 

---

### 5.1 Hierarchical Task Orchestration (Strategy C)

The project utilizes a root `Taskfile.yml` to act as the primary interface for GitHub Actions, while delegating local build and test logic to sub-project Taskfiles. 

#### Root `Taskfile.yml`

```yaml
version: '3'

vars:
  REGISTRY: '{{default "ghcr.io/your-org" .REGISTRY}}'
  TAG: '{{default "latest" .TAG}}'
  CLUSTER_DOMAIN: '{{default "dev.local" .CLUSTER_DOMAIN}}'

includes:
  backend: 
    taskfile: ./backend/Taskfile.yml
    dir: ./backend
  frontend: 
    taskfile: ./frontend/Taskfile.yml
    dir: ./frontend

tasks:
  deploy:ephemeral:
    desc: Deploy PR-specific environment
    vars:
      NS: pr-{{.PR_NUM}}
    cmds:
      - |
        helm upgrade --install {{.NS}} ./charts/app \
          --namespace {{.NS}} --create-namespace \
          --set backend.image.tag={{.TAG}} \
          --set frontend.image.tag={{.TAG}} \
          --set ingress.host={{.NS}}.{{.CLUSTER_DOMAIN}}

  scan:
    desc: Vulnerability scanning for all artifacts
    cmds:
      - trivy image --severity CRITICAL --exit-code 1 {{.REGISTRY}}/backend:{{.TAG}}
      - trivy image --severity CRITICAL --exit-code 1 {{.REGISTRY}}/frontend:{{.TAG}}

```

#### Backend `backend/Taskfile.yml`

```yaml
version: '3'
tasks:
  test:
    cmds:
      - pytest tests/unit
  build:
    cmds:
      - docker build -t {{.REGISTRY}}/backend:{{.TAG}} .

```

---

### 5.2 Container Strategy: Multi-Stage & Non-Root

To ensure minimal image size and maximum security, both applications utilize multi-stage Dockerfiles. 

**Example Backend `Dockerfile`:**

```dockerfile
# Stage 1: Build
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim
RUN useradd -u 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY . .
USER 10001
CMD ["python", "main.py"]

```

---

### 5.3 GitHub Actions Workflow (Push-Based CD)

The pipeline manages the lifecycle from pull request to production deployment. 

```yaml
# .github/workflows/pipeline.yml
name: Polyglot CD
on:
  push:
    branches: [main]
  pull_request:
    types: [opened, synchronize, closed]

jobs:
  build-and-deploy:
    runs-on: self-hosted
    permissions:
      id-token: write
      packages: write
    steps:
      - uses: actions/checkout@v4
      - name: Build and Push
        run: task build:all push TAG=${{ github.sha }}
      
      - name: Security Scan
        run: task scan TAG=${{ github.sha }}

      - name: Deploy Ephemeral
        if: github.event_name == 'pull_request' && github.event.action != 'closed'
        run: task deploy:ephemeral PR_NUM=${{ github.event.number }} TAG=${{ github.sha }}

      - name: Deploy Production
        if: github.ref == 'refs/heads/main'
        run: task deploy:prod TAG=${{ github.sha }}

```

---

### 5.4 Observability: OTel Instrumentation

The system leverages the OpenTelemetry Operator to automate tracing and metrics. 

**OTel Instrumentation Manifest:**

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: polyglot-autoinstrumentation
spec:
  exporter:
    endpoint: http://otel-collector.monitoring.svc.cluster.local:4317
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest

```

Application pods are instrumented by adding the annotation `instrumentation.opentelemetry.io/inject-python: "true"` to the deployment metadata. 

---

### 5.5 Security: Signing and Scanning

1. **Vulnerability Scanning:** Trivy runs as a gate in the pipeline, failing the build on `CRITICAL` findings. 


2. **Image Signing:** Production images are signed via **Cosign** using keyless mode. 


* **Logic:** `cosign sign --yes <image-digest>` 


* **Verification:** On-prem clusters verify the signature against the GitHub OIDC issuer before pull. 

---

### 5.6 Deployment Messaging (MS Teams)

Real-time feedback is provided to the engineering team via MS Teams webhooks. 

**Task Implementation:**

```yaml
notify:teams:
  cmds:
    - |
      curl -H "Content-Type: application/json" \
      -d '{
        "summary": "Deployment: {{.NAMESPACE}}",
        "themeColor": "{{if eq .STATUS "Success"}}00FF00{{else}}FF0000{{end}}",
        "sections": [{
          "activityTitle": "Environment: {{.NAMESPACE}}",
          "facts": [{"name": "Tag", "value": "{{.TAG}}"}]
        }]
      }' "{{.TEAMS_WEBHOOK}}"

```

---

#### B. Deployment Lifecycle

1. **Continuous Integration (CI):** Triggered on PR. Includes Linting, Unit Testing, and Docker building.
2. **Ephemeral Deployment:** The app is deployed to a `pr-<number>` namespace. Hostnames are generated dynamically (e.g., `pr-42.dev.local`).
3. **Security Gate:** Every image is scanned by **Trivy**. If "CRITICAL" vulnerabilities exist, the build fails.
4. **Continuous Deployment (CD):** Upon merge to `main`, images are pushed to **GHCR**, signed with **Cosign**, and deployed to the `production` namespace.

---

## 6. Cross-Cutting Concerns

### Security & Compliance

* **Image Integrity:** Images are signed using Cosign's keyless mode, leveraging GitHub's OIDC provider.
* **Runtime Security:** All containers run as non-root users (UID 10001).


* **Secret Management:** For this phase, secrets are injected via GitHub Secrets into the Helm deployment.



### Observability

* **OpenTelemetry:** We deploy an `Instrumentation` CRD via the OTel Operator to automatically inject tracing libraries into the Python and Node.js pods.


* **Standardized Probes:** Every component must implement `/health` endpoints for Kubernetes Liveness and Readiness checks.



### Scalability

* **Resource Management:** Production deployments use `values-prod.yaml` to define Horizontal Pod Autoscalers (HPA) and resource limits (512MiB/500m CPU for backend).


* **Multi-Stage Dockerfiles:** Drastic reduction in image size by separating build dependencies from the final runtime environment.

---

## 7. Implementation Plan

1. **Phase 1:** Setup hierarchical Taskfiles and multi-stage Dockerfiles.


2. **Phase 2:** Configure GitHub Actions for ephemeral PR environments and namespace cleanup.


3. **Phase 3:** Integrate Trivy scanning, Cosign signing, and MS Teams notification tasks.


4. **Phase 4:** Deploy OpenTelemetry Operator and configure auto-instrumentation.



---

## 8. Alternatives Considered

* **Raw Manifests vs. Helm:** Raw manifests were rejected because they do not support the dynamic logic required for ephemeral subdomains and namespace-based configuration.


* **Monolithic Taskfile:** Rejected because it becomes unmaintainable as the backend and frontend teams grow and require different build tools.

---

## 9. Discussion & Feedback

* **On-Prem Connectivity:** This design assumes the self-hosted GitHub Runner has `cluster-admin` (or scoped namespace-admin) access to the local K8s cluster.
* **Notification Hook:** The MS Teams webhook URL must be stored as a GitHub Secret to prevent unauthorized channel spamming.
