# syntax=docker/dockerfile:1

# Étape de build exécutée NATIVEMENT sur la machine du participant
# (--platform=$BUILDPLATFORM) : aucune émulation QEMU/Rosetta, même pour les
# images amd64 construites depuis un Mac arm64 — uv résout les dépendances
# POUR l'architecture cible (voir --python-platform plus bas). Debian 12
# obligatoire : même Python 3.11 que l'image distroless finale.
FROM --platform=$BUILDPLATFORM debian:12-slim AS build
ARG TARGETARCH

# uv remplace pip + venv + hatch : plus rapide et sans venv de build intermédiaire.
COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /usr/local/bin/uv

RUN --mount=type=cache,target=/var/lib/apt/lists \
    --mount=type=cache,target=/var/cache/apt \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && apt-get install --no-install-recommends --yes python3

# Don't write .pyc bytecode files. These speed up imports when the program is
# loaded. There's no point doing that in a container where they'll never be
# persisted across restarts.
ENV PYTHONDONTWRITEBYTECODE=true
# Le venv doit utiliser le python3 de Debian 12, présent dans l'image distroless
# (un Python managé par uv n'existerait pas dans l'image finale).
ENV UV_PYTHON_DOWNLOADS=never
# Le cache monté est sur un autre filesystem : copier plutôt que hardlinker.
ENV UV_LINK_MODE=copy

# uv build invoque le backend hatchling déclaré dans pyproject.toml — plus
# besoin d'installer hatch ni de créer un venv de build. Le wheel est pur
# Python, donc indépendant de l'architecture.
WORKDIR /build
RUN --mount=target=. \
    --mount=type=cache,target=/root/.cache/uv \
    uv build --wheel --out-dir /whl

# Create a fresh venv and install only the function wheel into it.
# --python-platform force la résolution des wheels natifs (grpcio…) pour
# l'architecture CIBLE ; manylinux_2_36 = glibc de Debian 12.
RUN --mount=type=cache,target=/root/.cache/uv \
    case "$TARGETARCH" in \
      amd64) UV_ARCH=x86_64 ;; \
      arm64) UV_ARCH=aarch64 ;; \
      *) echo "TARGETARCH non géré : $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && uv venv --python /usr/bin/python3 /venv/fn \
    && uv pip install --python /venv/fn/bin/python \
       --python-platform "$UV_ARCH-manylinux_2_36" \
       /whl/*.whl

# Copy the function venv to our runtime stage. It's important that the path be
# the same as in the build stage, to avoid shebang paths and symlinks breaking.
FROM gcr.io/distroless/python3-debian12 AS image
WORKDIR /
COPY --from=build /venv/fn /venv/fn
EXPOSE 9443
USER nonroot:nonroot
ENTRYPOINT ["/venv/fn/bin/function"]
