# aws-hardening — Attaquer et défendre mon propre cloud

Construire un environnement AWS sécurisé comme en entreprise, y déployer une application volontairement
vulnérable (**OWASP Juice Shop**), puis l'attaquer moi-même et mesurer ce que ma défense détecte et bloque.

Guide principal : *Cloud Native Security Cookbook* (J. Armitage, O'Reilly), recettes AWS.

## Feuille de route

| Étape | Contenu | Recettes | État |
|---|---|---|---|
| **1. Fondations** | Poste d'administration, sécurité du compte, organisation multi-comptes, identités | 11.2 · 2.2 · 2.5 · 2.8 | 🟡 En cours |
| **2. Tout en code** | Infrastructure Terraform versionnée, analyse de sécurité du code | 6.2 · 6.8 · 6.11 | ⬜ |
| **3. Réseau et données** | VPC privé, pare-feu applicatif (WAF), chiffrement | 5.x · 4.2 · 4.8 | ⬜ |
| **4. Détection** | Journaux centralisés, alertes, conformité automatique | 3.2 · 3.5 · 3.8 · 7.x | ⬜ |
| **5. Attaque** | Analyse puis attaque de Juice Shop, bilan défense | 9.5 | ⬜ |

## Structure

```
organization/   Organisation multi-comptes (OU + comptes) — jamais détruite
docs/           Journal de chaque étape : ce que j'ai fait, pourquoi, ce qui a coincé
```

## Journal

- [Étape 1 — Fondations](docs/01-fondations.md)

## Règles du projet

- **Aucune clé d'accès permanente** : identifiants temporaires uniquement (IAM Identity Center).
- **Alerte de budget à zéro dépense** active en permanence.
- **`terraform destroy` à la fin de chaque séance** dès que des ressources payantes existent (jamais sur `organization/`).
- **Chaque `terraform apply` applique un plan enregistré et relu** (`plan -out` puis `apply tfplan`).
- **Tests d'attaque uniquement sur mes propres ressources**, dans le respect de la politique de tests d'intrusion d'AWS.
- **Aucun identifiant de compte, aucune clé, aucun nom de domaine privé** dans ce dépôt.
