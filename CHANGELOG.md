# CHANGELOG

## [1.0.1] - 2025-09-29

### Fixed

- Correction du bug nginx avec `proxy_set_header Host $host;` remplaçant la logique complexe commentée pour améliorer la stabilité du reverse proxy

## [1.0.0] - 2025-09-19

### Added

- Script d'installation automatisé VPS (`install-vps.sh`) pour gestion des templates
- Système de templates dynamiques avec `template.info`
- Template Debian 12 + Docker + Webmin + Nginx + Portainer + Fail2ban (OVH)
- Script `vhost-manager.sh` pour gestion des domaines (reverse proxy)
- Mot de passe Portainer sécurisé (hash bcrypt)
- Nettoyage automatique des fichiers temporaires
- Support SSL Let's Encrypt et certificats personnalisés
- Détection automatique et scan des templates disponibles

### Changed

- N/A

### Removed

- N/A
