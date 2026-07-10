#!/usr/bin/env sh
# Build et publication des images OCI des deux Composition Functions custom.
#
# Chaque session de l'atelier a son propre registre (créé par Terraform, public
# et détruit avec le reste de l'infra par `tofu destroy` — voir terraform/main.tf,
# ressource scaleway_registry_namespace.functions). Ce script est donc à lancer
# par CHAQUE participant, juste après `tofu apply` :
#   REGISTRY="$(tofu output -raw functions_registry)" ./build-and-push-functions.sh
# Terraform a déjà appliqué platform/functions.rendered.yaml pointant vers ce
# registre ; tant que les images n'y sont pas poussées, les 2 Functions custom
# restent HEALTHY=False (Crossplane retente le pull automatiquement, aucune
# ré-application n'est nécessaire une fois le push terminé).
#
# Prérequis :
#   - docker (avec buildx) et le CLI crossplane ;
#   - être connecté au registre :
#       printf '%s' "$SCW_SECRET_KEY" | docker login rg.fr-par.scw.cloud -u nologin --password-stdin
#
# Note : le push passe par `docker load` + `docker push` + `docker manifest`
# plutôt que `crossplane xpkg push`, car le registre Scaleway rejette l'upload
# streamé de go-containerregistry (erreur DIGEST_INVALID, vérifiée). Le .xpkg
# étant une archive docker standard, le résultat est équivalent.
#
# Usage :
#   REGISTRY="$(tofu output -raw functions_registry)" ./build-and-push-functions.sh
#   PUSH=false ./build-and-push-functions.sh   # build seul (validation locale)
#   REGISTRY=... TAG=v0.2.0 ./build-and-push-functions.sh
set -eu

REGISTRY="${REGISTRY:-rg.fr-par.scw.cloud/kubernetes-workshops}"
TAG="${TAG:-v0.1.0}"
# Kapsule tourne sur amd64 ; arm64 permet le développement local sur Mac.
ARCHS="${ARCHS:-amd64 arm64}"
PUSH="${PUSH:-true}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FUNCTIONS_DIR="$SCRIPT_DIR/../functions"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

for fn in ticket-gate namespace-secret; do
  dir="$FUNCTIONS_DIR/$fn"
  image="$REGISTRY/function-$fn:$TAG"
  arch_tags=""

  for arch in $ARCHS; do
    runtime_tag="function-$fn-runtime:$arch"
    echo "==> Build du runtime $runtime_tag (linux/$arch)"
    docker buildx build --platform "linux/$arch" --load -t "$runtime_tag" "$dir"

    xpkg_file="$BUILD_DIR/function-$fn-$arch.xpkg"
    echo "==> Empaquetage xpkg $xpkg_file"
    crossplane xpkg build \
      --package-root="$dir/package" \
      --embed-runtime-image="$runtime_tag" \
      --package-file="$xpkg_file"

    image_id="$(docker load -i "$xpkg_file" | sed 's/Loaded image ID: //')"
    docker tag "$image_id" "$image-$arch"
    arch_tags="$arch_tags $image-$arch"
  done

  if [ "$PUSH" = "true" ]; then
    for t in $arch_tags; do
      echo "==> Push de $t"
      docker push -q "$t"
    done
    echo "==> Manifest multi-arch $image"
    docker manifest rm "$image" 2>/dev/null || true
    # shellcheck disable=SC2086
    docker manifest create "$image" $arch_tags
    docker manifest push "$image"
  else
    echo "==> PUSH=false : $image non poussé (tags locaux :$arch_tags)"
  fi
done

echo "Terminé."
