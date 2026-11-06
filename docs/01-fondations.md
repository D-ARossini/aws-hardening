# Étape 1 — Fondations

**Objectif :** pouvoir administrer AWS depuis un poste dédié, sans jamais utiliser le compte root
ni stocker de clé d'accès permanente, et sans risque de facture imprévue.

---

## 1.1 Le poste d'administration : un Raspberry Pi joignable uniquement par Tailscale

**Ce que j'ai fait**
- Installé **Terraform** (dépôt officiel HashiCorp, paquet `linux_arm64`) et l'**AWS CLI v2** (version `aarch64`).
- Mis à jour le système et redémarré sur le nouveau noyau, puis vérifié que tous les services repartaient seuls.

**Pourquoi un poste dédié**
- Il sépare l'administration du cloud de mon ordinateur personnel.
- Il n'est joignable que par mon réseau Tailscale, en SSH par clé uniquement
  (voir l'[audit de sécurité du serveur](https://github.com/D-ARossini/home-server-infrastructure/blob/main/docs/security-audit-2026-11.md)).

**Ce qui a coincé**
- Première installation de Terraform en échec : `NO_PUBKEY` au moment de `apt update`.
  La saisie du mot de passe `sudo` avait été interrompue pendant l'enregistrement de la clé de signature du dépôt :
  le fichier de clé était vide. Relancer la commande d'import a suffi.
  **Leçon :** un dépôt dont la signature n'est pas vérifiable est refusé par `apt`, et c'est le comportement voulu.

---

## 1.2 Sécuriser le compte avant d'y toucher

| Mesure | Pourquoi |
|---|---|
| **MFA sur le compte root** | Le compte root a tous les droits, y compris supprimer le compte. Sans MFA, un mot de passe volé suffit. |
| **Aucune clé d'accès sur le compte root** | Le compte root ne doit jamais être utilisé depuis un terminal ni un script. |
| **Budget « zéro dépense »** | Alerte par e-mail dès le premier centime : la protection contre les oublis pendant tout le projet. |

---

## 1.3 Organisation et identités (démarrage manuel)

Le livre suppose que Terraform peut déjà s'authentifier (recette 11.2) : ce démarrage a donc été fait à la main dans la console.

**Ce que j'ai fait**
- Activé **AWS Organizations** : le compte existant devient le compte de gestion.
- Activé **IAM Identity Center** en **instance d'organisation à région unique**, région principale **eu-west-3 (Paris)**.
- Créé mon utilisateur (mot de passe + MFA) et un **ensemble d'autorisations** `AdministratorAccess` (sessions d'une heure), attribué sur le compte de gestion.
- Connecté le Pi avec **`aws configure sso --use-device-code`** : profil `admin`, identifiants temporaires.

**Vérification**
```bash
aws sts get-caller-identity --profile admin
# "Arn": "arn:aws:sts::<ACCOUNT_ID>:assumed-role/AWSReservedSSO_AdministratorAccess_.../<utilisateur>"
```
Le rôle `AWSReservedSSO_…` confirme des identifiants **temporaires** : aucune clé d'accès n'est stockée sur le Pi.

**Modernisé par rapport au livre**
- La recette 2.8 crée des **utilisateurs IAM** dans un compte dédié. J'utilise **IAM Identity Center** (anciennement AWS SSO), la pratique recommandée aujourd'hui : un seul annuaire, MFA, sessions courtes.

**Ce qui a coincé**
- **La console proposait par défaut la région `us-east-1`**, et la région principale d'Identity Center **n'est plus modifiable** ensuite. Il faut changer de région *avant* l'activation.
- **L'option « multirégionale » crée une clé KMS gérée par le client, payante.** Choix : instance à région unique, sans frais.
- **Activer AWS Organizations fait passer le compte du forfait gratuit au forfait payant** (nouvelle offre gratuite d'AWS). Aucun coût pour Organizations ni Identity Center, mais l'alerte de budget devient la protection principale.
- **En SSH, la connexion par navigateur échoue** : la CLI attend un retour sur `127.0.0.1` *du Pi*, alors que le navigateur est sur le PC. Solution : `--use-device-code`.

---

## 1.4 Organisation multi-comptes en Terraform (recette 2.2, adaptée)

Code : [`organization/`](../organization/)

**Structure créée**
```
Root
├── OU security   → compte security    (outils de sécurité : journaux, détection)
└── OU workloads  → compte juice-shop  (l'application volontairement vulnérable)
```

**Pourquoi séparer en comptes**
- Un compte AWS est la **frontière d'isolation la plus forte** : si le compte Juice Shop est compromis,
  l'attaquant n'a aucun droit sur le compte sécurité, qui contient justement les journaux de l'attaque.
- Les **OU** permettront d'appliquer des règles différentes par famille de comptes (recette 2.5 : SCP).

**Adapté par rapport au livre**
- Le livre crée **4 comptes** (production, préproduction, développement, partagé) dans une OU par équipe.
  Je n'en crée que **2** : chaque compte doit avoir un usage réel, car un compte créé est quasi définitif
  (fermeture en 90 jours, adresse e-mail jamais réutilisable).
- **`close_on_deletion = true`** : si un compte est retiré du code, il est **fermé**. Avec la valeur par défaut (`false`),
  Terraform essaierait seulement de le sortir de l'organisation, ce qui laisse un compte orphelin.

**Organisation du code**

| Fichier | Rôle | Publié ? |
|---|---|---|
| `provider.tf` | Fournisseur AWS et région | Oui |
| `main.tf` | Ressources : 2 OU, 2 comptes | Oui |
| `variables.tf` | Déclaration des variables (nom, type, description) | Oui |
| `terraform.tfvars` | Valeurs réelles : id de la racine, adresses e-mail | **Non** (`.gitignore`) |
| `terraform.tfstate` | État réel : id des comptes | **Non** (`.gitignore`) |

Valeur en dur quand elle fait partie de la conception (`name = "juice-shop"`, `close_on_deletion`),
variable quand elle est personnelle ou propre à chaque déploiement (adresses e-mail, id de la racine).

**Exécution**
```bash
aws sso login --profile admin --use-device-code
terraform fmt && terraform validate
terraform plan -out=tfplan     # relu avant application
terraform apply tfplan         # applique exactement le plan relu
```
Résultat : `Apply complete! Resources: 4 added, 0 changed, 0 destroyed.`
Terraform a créé les OU **avant** les comptes sans qu'on le lui dise : les `parent_id` référencent
`aws_organizations_organizational_unit.<nom>.id`, ce qui crée une **dépendance implicite**.

**Ce qui a coincé**
- **Le code du livre ne déclare pas `organizational_unit_parent_id`** : `validate` échoue tant qu'on ne l'ajoute pas dans `variables.tf`.
- **Un guillemet manquant** dans une description a produit des dizaines d'erreurs en cascade.
  **Leçon :** lire seulement la première erreur, la corriger, relancer.
- **`No valid credential sources found` au moment du `plan`** : la session SSO (une heure) avait expiré.
  C'est le comportement voulu d'identifiants temporaires. Réflexe : `aws sso login` en début de séance.

**Règle :** ce dossier ne se détruit **jamais** avec `terraform destroy`. Le `destroy` de fin de séance
concerne uniquement les dossiers qui contiennent des ressources payantes.

---

## 1.5 À venir dans cette étape

- [ ] **Limitation des régions** par SCP (recette 2.5).
- [ ] **Droits par compte** dans Identity Center, gérés en Terraform (recette 2.8, modernisée).

---

## Ce que je retiens

- La première mesure de sécurité dans le cloud n'est pas technique : c'est **limiter qui peut agir et combien ça peut coûter**.
- Un poste d'administration est un actif sensible : sa propre sécurité conditionne celle de tout le reste.
- En infrastructure, **ce qui est créé est plus difficile à défaire qu'à faire** : on relit le plan avant chaque application.
