# syntax=docker/dockerfile:1.7
#
# Image des sandboxes de l'atelier : le runner d'AX (PID 1, contrat décrit dans
# google/ax docs/runner.md) + l'agent de code OpenCode + Python et pytest.
#
# Construite par scripts/30-build-agent-image.sh avec le clone d'AX comme
# contexte nommé « ax ». Toutes les étapes lourdes s'exécutent sur
# l'architecture de la machine de build ($BUILDPLATFORM) : l'étape finale ne
# contient que des COPY, donc aucune émulation QEMU même depuis un Mac ARM.

ARG PYTHON_IMAGE=python:3.12-bookworm

# 1. Runner AX compilé en croisé (Go).
FROM --platform=$BUILDPLATFORM golang:1.27-bookworm AS runner
ARG TARGETOS TARGETARCH
WORKDIR /src
COPY --from=ax go.mod go.sum ./
RUN go mod download
COPY --from=ax . .
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/ax-task-runner ./cmd/ax-task-runner

# 2. OpenCode et dépendances Python, téléchargés pour l'architecture cible.
FROM --platform=$BUILDPLATFORM ${PYTHON_IMAGE} AS deps
ARG TARGETARCH
ARG OPENCODE_VERSION
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) oc=x64-baseline; plat=x86_64 ;; \
      arm64) oc=arm64; plat=aarch64 ;; \
      *) echo "architecture non supportée : ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/opencode/bin; \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/${OPENCODE_VERSION}/opencode-linux-${oc}.tar.gz" \
      | tar -xz -C /opt/opencode/bin; \
    pip install --no-cache-dir --target /opt/python --only-binary=:all: \
      --python-version 3.12 --implementation cp \
      --platform "manylinux_2_17_${plat}" --platform "manylinux2014_${plat}" --platform "manylinux_2_28_${plat}" \
      google-antigravity pytest

# 3. Image finale : uniquement des COPY.
# python:3.12-bookworm fournit déjà git, curl, openssh-client et procps.
FROM ${PYTHON_IMAGE}
ENV PYTHONPATH=/opt/python \
    PATH=/opt/python/bin:/opt/opencode/bin:${PATH} \
    OPENCODE_CONFIG=/etc/opencode/opencode.json \
    OPENCODE_DISABLE_AUTOUPDATE=true \
    LLM_GATEWAY_URL=http://litellm.llm-gateway.svc.cluster.local:4000/v1
COPY --from=runner /out/ax-task-runner /usr/local/bin/ax-task-runner
COPY --from=ax cmd/ax-task-runner/antigravity_bootstrap.py /usr/local/bin/antigravity_bootstrap.py
COPY --from=deps /opt/opencode /opt/opencode
COPY --from=deps /opt/python /opt/python
COPY opencode.json /etc/opencode/opencode.json
ENTRYPOINT ["/usr/local/bin/ax-task-runner"]
