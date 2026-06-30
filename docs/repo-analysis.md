# Analyse du dépôt et axes de structuration

## État actuel

Le dépôt contient deux familles de contenu:

- `clusters/`: provisionnement de clusters Kubernetes managés, aujourd'hui Azure AKS et Scaleway Kapsule, avec modules partagés pour cert-manager, Grafana/Prometheus et kubeseal.
- `demos/`: scénarios applicatifs, principalement autour de Kong, Gateway API, echo-server et kubeception.

Les ateliers existants ressemblent davantage à des notes de déploiement qu'à des supports pédagogiques complets. Ils contiennent les commandes essentielles, mais peu de contexte, de critères de réussite, de diagnostic, de débrief ou de nettoyage.

## Risques identifiés

- Absence de README racine pour expliquer le but du dépôt.
- Absence d'instructions communes pour agents IA.
- Ateliers difficiles à rejouer sans connaissance implicite du contexte OCTO.
- Peu de séparation entre démonstration technique et parcours d'apprentissage.
- Risque de secrets ou fichiers locaux: `.env`, `terraform.tfvars`, états Terraform/OpenTofu, kubeconfigs.
- Commandes cloud potentiellement coûteuses si elles sont exécutées sans garde-fou.

## Structure proposée

Chaque nouveau scénario devrait être autonome:

```text
demos/<theme>/<scenario>/
  README.md
  helmfile.yaml | kustomization.yaml | manifests/
  values.yaml
  values.example.yaml
```

Pour les ateliers qui nécessitent un cluster spécifique:

```text
clusters/<provider-or-runtime>/
  README.md
  providers.tf
  main.tf
  variables.tf
  outputs.tf
  terraform.tfvars.example
```

Les supports transverses restent dans `docs/`:

- template d'atelier;
- checklist qualité;
- workflows de collaboration avec agents;
- analyses et décisions de structuration.

## Conventions recommandées

- Un atelier = un objectif pédagogique principal.
- Les commandes doivent être copiables et accompagnées du résultat attendu.
- Les namespaces doivent être dédiés au scénario pour faciliter le nettoyage.
- Les dépendances externes doivent être versionnées quand c'est raisonnable.
- Les ressources cloud doivent avoir une procédure de destruction explicite.
- Les valeurs propres à un participant doivent passer par `.env.example`, `values.example.yaml` ou variables documentées.
- Les agents ne doivent pas exécuter `tofu apply`, `tofu destroy`, `helmfile apply` ou des suppressions Kubernetes larges sans confirmation.

## Backlog pédagogique possible

Ateliers découverte:

- déployer une application simple et l'exposer avec Service puis Ingress;
- comprendre ConfigMap, Secret et variables d'environnement;
- observer un rollout et revenir à une version précédente;
- diagnostiquer un Pod en `CrashLoopBackOff`.

Ateliers intermédiaires:

- Gateway API avec Traefik ou Kong;
- certificats automatiques avec cert-manager;
- observabilité de base avec Prometheus/Grafana;
- autoscaling HPA et limites de ressources;
- NetworkPolicy et segmentation simple.

Ateliers avancés:

- debug DNS, CoreDNS et résolution de services;
- GitOps avec Argo CD ou Flux;
- politiques d'admission avec Kyverno ou Gatekeeper;
- sécurité supply chain et images;
- multi-cluster ou cluster API;
- patterns de migration Ingress vers Gateway API.

## Prochaine amélioration utile

Le prochain pas le plus rentable serait de transformer un atelier existant, par exemple `demos/kong-as-S3-gateway`, en atelier complet en suivant `docs/workshop-template.md`. Cela permettra de valider le template sur un cas réel et d'ajuster les conventions avant de créer beaucoup de nouveaux contenus.
