# Docker VPS Setup

Installe et configure automatiquement SSH, Nginx en reverse proxy pour les conteneurs Docker, avec un script de gestion des virtual hosts et l’intégration de SSL/Certbot, ainsi que Webmin et Portainer sur un VPS OVH avec Docker préinstallé, en plus de fail2ban et de la configuration de tous les ports et paramètres de sécurité.

## Installation

**Depuis votre machine locale :**

```bash
# Script automatique (recommandé)
wget https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/connect-vps.sh
chmod +x connect-vps.sh
./connect-vps.sh
```

Le script configure automatiquement :

- Connexion SSH avec IP/port personnalisés
- Installation optionnelle de votre clé SSH (recommandé)
- Test de connexion sans mot de passe
- Connexion automatique au VPS

**Sur le VPS :**

```bash
git clone https://github.com/padcmoi/docker-vps-ovh-setup.git
cd docker-vps-ovh-setup
sudo ./setup-debian12-docker-ovh.sh
```

## Support

[Signaler un problème](https://github.com/padcmoi/docker-vps-ovh-setup/issues/new)
