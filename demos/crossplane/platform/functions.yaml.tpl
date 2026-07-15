# Les Composition Functions utilisées par les quatre exercices.
#
# Contrairement aux pipelines Kratix (Jobs éphémères lancés à chaque changement),
# chaque Function est un Deployment permanent dans crossplane-system, appelé en
# gRPC par Crossplane à chaque réconciliation des XRs.
#
# Fichier gabarit (templatefile) : Terraform le rend et l'applique automatiquement
# (cf. terraform/main.tf, ressource local_file.platform_functions_rendered et
# null_resource.platform_functions) avec le registre individuel de la session.
# Ne pas appliquer ce .tpl directement — voir platform/functions.rendered.yaml
# généré par `tofu apply`.
#
# Attendre qu'elles soient saines avant de continuer :
#   kubectl wait functions.pkg.crossplane.io --all --for=condition=Healthy --timeout=300s
---
# Composition "pure" déclarative (exercice 1) : patches et transforms sans code.
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-patch-and-transform:v0.10.7
---
# Marque la XR Ready quand toutes ses ressources composées le sont (exercices 1 à 4).
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-auto-ready
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-auto-ready:v0.7.0
---
# Exercice 4 : seule function communautaire déclarant la capability `operation`,
# utilisée dans le pipeline de l'Operation de flush (script Python inline).
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-python
spec:
  package: xpkg.crossplane.io/crossplane-contrib/function-python:v0.5.0
---
# Function custom de l'exercice 2 : crée le ticket auprès du service de ticketing,
# suit son approbation, puis compose Namespace + ResourceQuota.
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-ticket-gate
spec:
  package: ${registry}/function-ticket-gate:v0.1.0
---
# Function custom de l'exercice 3 : lit la TicketRequest (extra resources) et
# compose un Secret dans le namespace approuvé.
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-namespace-secret
spec:
  package: ${registry}/function-namespace-secret:v0.1.0
