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

## 1.3 À venir dans cette étape

- [ ] **Organisation AWS multi-comptes** (recette 2.2) : un compte pour la sécurité et les journaux, un pour l'application.
- [ ] **Limitation des régions** utilisables (recette 2.5).
- [ ] **IAM Identity Center** avec MFA (recette 2.8).
- [ ] **Connexion du Pi par identifiants temporaires** : `aws configure sso`, puis `aws sso login` (recette 11.2).

---

## Ce que je retiens

- La première mesure de sécurité dans le cloud n'est pas technique : c'est **limiter qui peut agir et combien ça peut coûter**.
- Un poste d'administration est un actif sensible : sa propre sécurité conditionne celle de tout le reste.
