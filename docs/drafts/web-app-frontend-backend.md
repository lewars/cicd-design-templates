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

#### A. Hierarchical Taskfile Structure (Strategy C)

We utilize a root `Taskfile.yml` that includes child Taskfiles from the `/backend` and `/frontend` directories.  This ensures that domain-specific logic (like Python's `pytest` or Node's `npm`) stays encapsulated while the root manages the deployment context.

```yaml
# /Taskfile.yml
includes:
  backend:
    taskfile: ./backend/Taskfile.yml
    dir: ./backend
  frontend:
    taskfile: ./frontend/Taskfile.yml
    dir: ./frontend

```

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
