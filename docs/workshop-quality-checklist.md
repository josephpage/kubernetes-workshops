# Checklist qualité d'un atelier

Utiliser cette checklist avant de proposer un nouvel atelier ou une évolution importante.

## Pédagogie

- L'objectif de l'atelier est explicite en moins de cinq lignes.
- Le niveau et la durée cible sont indiqués.
- Les concepts manipulés sont listés.
- Chaque étape a une intention pédagogique claire.
- Le participant sait quoi observer après chaque commande importante.
- Des questions de débrief sont présentes.
- La section "Pour aller plus loin" propose une suite naturelle.

## Reproductibilité

- Les prérequis locaux sont listés avec des commandes de vérification.
- Les versions importantes sont fixées ou documentées.
- Les fichiers d'exemple sont présents pour les variables locales.
- Les commandes sont copiables depuis un shell standard.
- Les namespaces et noms de ressources sont cohérents.
- Le chemin nominal fonctionne depuis un clone propre du dépôt.

## Sécurité

- Aucun secret réel n'est présent.
- Aucun kubeconfig réel n'est présent.
- Aucun état Terraform/OpenTofu réel n'est présent.
- Les endpoints publics et domaines utilisés sont explicités.
- Les permissions Kubernetes nécessaires sont minimales ou justifiées.
- Les commandes destructrices sont limitées au périmètre de l'atelier.

## Validation

- Une section `Validation` existe.
- Les commandes de validation produisent un résultat observable.
- Les erreurs fréquentes sont documentées.
- Le nettoyage est testé ou au moins relu.
- Les liens relatifs fonctionnent.

## Maintenance par agents IA

- Le README de l'atelier suit le template du dépôt.
- Les choix non évidents sont expliqués brièvement.
- Les fichiers générés ou dépendances externes sont identifiables.
- Les instructions ne supposent pas un contexte local implicite.
- Les limites connues sont documentées.
