# Home Server Infrastructure & Lab Linux

Infrastructure personnelle auto-hébergée sur Raspberry Pi (Ubuntu Server), utilisée comme laboratoire
d'administration système, d'automatisation et de sécurité sur des services réels.

> **Principe directeur : zero trust.** Aucun service d'administration n'est joignable sans passer par
> le réseau privé Tailscale. Le réseau local n'est pas considéré comme sûr.

---

## Architecture

```
            Internet
               │
         [ Box / NAT ]  ── (aucune redirection, sauf exception documentée)
               │
        Réseau local (non fiable)
               │ eth0
     ┌─────────┴──────────────────────────────────────────┐
     │  Raspberry Pi — Ubuntu Server                       │
     │                                                     │
     │  tailscale0 (100.x) ◄── seul point d'entrée admin   │
     │     │                                               │
     │     ├─ SSH :2222          (clé uniquement)          │
     │     ├─ Caddy :8443 (TLS) ──► Vaultwarden (interne)   │
     │     ├─ Nextcloud :8080 ──► MariaDB (interne)        │
     │     ├─ Pi-hole :53 / :8081                          │
     │     └─ Uptime Kuma :3001                            │
     │                                                     │
     │  Minecraft (Paper) :25565                           │
     └─────────────────────────────────────────────────────┘
```

| Service | Rôle | Exposition |
|---|---|---|
| **Caddy** | Reverse proxy TLS (certificats Tailscale) | Tailscale uniquement |
| **Vaultwarden** | Gestionnaire de mots de passe | **Aucun port publié** : joignable seulement via Caddy, sur le réseau Docker interne |
| **Nextcloud** + MariaDB | Stockage personnel | Tailscale uniquement ; base de données non exposée |
| **Pi-hole** | DNS filtrant du réseau Tailscale | Tailscale uniquement |
| **Uptime Kuma** | Supervision et alertes | Tailscale uniquement |
| **Minecraft** (itzg/minecraft-server, Paper) | Serveur de jeu | Voir *Risques résiduels* |

---

## Modèle de menace

| | |
|---|---|
| **Actifs protégés** | Mots de passe (Vaultwarden), fichiers personnels (Nextcloud), historique DNS (vie privée), accès d'administration (SSH), disponibilité des services |
| **Adversaires considérés** | Robots qui scannent Internet ; appareil compromis du réseau local ; appareil compromis ou oublié du réseau Tailscale |
| **Surface d'exposition** | Interface Tailscale (`tailscale0`) pour l'administration ; port de jeu Minecraft |
| **Hors périmètre** | Accès physique au Pi ; compromission du compte Tailscale lui-même |

---

## Contrôles de sécurité

### Accès réseau
- **Tailscale** (réseau maillé chiffré, basé sur WireGuard) comme unique accès d'administration, avec **ACL** limitant le SSH à mon poste de travail.
- **ufw** en refus par défaut ; SSH autorisé **uniquement sur `tailscale0`**, avec limitation de débit (`LIMIT`).
- **Ports Docker liés à l'adresse Tailscale** (`<TAILSCALE_IP>:port:port`) et non à `0.0.0.0`.
  Docker écrit ses propres règles réseau, qui passent **avant** celles d'ufw : une règle ufw ne suffit donc pas à protéger un conteneur (voir l'[audit](docs/security-audit-2026-11.md)).
- `net.ipv4.ip_nonlocal_bind = 1` pour que les conteneurs démarrent même si Tailscale n'est pas encore lancé au boot.

### SSH
Fichier `/etc/ssh/sshd_config.d/00-hardening.conf`, lu **avant** le `50-cloud-init.conf` d'Ubuntu (la première valeur lue l'emporte) :
```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
X11Forwarding no
```
Vérification de la configuration réellement appliquée : `sudo sshd -T`.

### Services
- **Vaultwarden** n'est jamais exposé directement : seul Caddy, en TLS, y accède par le réseau Docker interne.
- **RCON Minecraft** non publié : la console reste accessible localement via `docker exec -i <conteneur> rcon-cli`.
- Bases de données sans port publié.

---

## Scripts d'administration (`scripts/`)

| Script | Rôle |
|---|---|
| `backup_project.sh` | Sauvegarde à chaud des volumes (arrêt du conteneur, archive datée `.tar.gz`, redémarrage, rotation sur 7 jours) |
| `dockermaster.sh` | `start` / `stop` / `status` / `build` sur l'ensemble des projets Docker |
| `rpi_health_report.sh` | Température CPU, RAM, disque, 5 processus les plus gourmands |
| `update_system.sh` | Mises à jour du système et nettoyage des dépendances |

---

## Vérifier l'exposition

```bash
# Ce qui écoute sur toutes les interfaces (doit être réduit au strict minimum)
sudo ss -tulpn | grep -E '0\.0\.0\.0|\[::\]'

# Règles du pare-feu
sudo ufw status verbose

# Ports publiés par Docker
docker ps --format "table {{.Names}}\t{{.Ports}}"
```
Depuis un poste du réseau Tailscale : `nmap -Pn -p <ports> <TAILSCALE_IP>`.

---

## Risques résiduels et améliorations prévues

| Risque | Statut |
|---|---|
| Port Minecraft 25565 publié sur toutes les interfaces | À trancher : public volontaire (seul service exposé) ou Tailscale uniquement |
| Images en `:latest` (Vaultwarden) et build Paper automatique | Épingler les versions pour des mises à jour maîtrisées |
| Certificats Tailscale (~90 jours) | Automatiser le renouvellement |
| Isolation Wi-Fi de la box utilisée comme protection implicite | Ne plus en dépendre : les services sont désormais liés à Tailscale |
| Sauvegardes stockées sur le même appareil | Ajouter une copie hors site chiffrée |

---

## Historique

- **2026-11** — [Audit de sécurité](docs/security-audit-2026-11.md) : 5 failles identifiées et corrigées (SSH, Docker/ufw, Vaultwarden, RCON).
