# Docker VPS Setup

Installe et configure automatiquement SSH, Nginx en reverse proxy pour les conteneurs Docker, avec un script de gestion des virtual hosts et l'intégration de SSL/Certbot, ainsi que Webmin et Portainer sur un VPS OVH avec Docker préinstallé, en plus de fail2ban et de la configuration de tous les ports et paramètres de sécurité.

## Installation

```bash
git clone https://github.com/padcmoi/docker-vps-ovh-setup.git
cd docker-vps-ovh-setup
sudo ./install-vps.sh
```

## Gestion des virtual hosts avec Vhost Manager

Le script `vhost-manager.sh` fournit une interface graphique pour configurer des reverse proxy Nginx :

Sur le VPS en ligne de commande:

```bash
vhost-manager.sh
```

Fonctionnalités :

- **Ajouter/Modifier/Supprimer** des reverse proxy
- **Activer/Désactiver** des domaines
- **Lister** la configuration existante

Configuration reverse proxy :

- **Domaine** : example.fr
- **Backend** : http://127.0.0.1:8888 (8888 etant un container Docker http) ou autre comme par exemple https://google.fr (site externe)

Options SSL :

- Let's Encrypt automatique
- Certificat personnalisé
- HTTP uniquement
- Redirection forcée HTTP → HTTPS (optionnelle)

## Demo

youtube lien soon

## Support

[Signaler un problème](https://github.com/padcmoi/docker-vps-ovh-setup/issues/new)
