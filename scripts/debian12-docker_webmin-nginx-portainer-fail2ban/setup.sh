#!/bin/bash

# =============================================================================
# Script de configuration automatique - OVH Debian 12 + Docker
# Automatise le setup complet d'un nouveau serveur VPS OVH
# =============================================================================
# 
# Prérequis : VPS OVH avec Debian 12 + Docker (option OVH)
# Usage : ./setup.sh
# 
# Services installés automatiquement :
# • Webmin (interface administration)  
# • SSH sécurisé (port + utilisateurs personnalisés)
# • Nginx + Certbot (serveur web + SSL)
# • Portainer (gestion containers Docker)  
# • Fail2ban (protection SSH anti-bots)
# • Scripts de gestion vhost Nginx
#
# =============================================================================

set -euo pipefail

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates/debian12-docker_webmin-nginx-portainer-fail2ban"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts/debian12-docker_webmin-nginx-portainer-fail2ban"

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

print_banner() {
    echo ""
    echo "=================================================================="
    echo "Déploiement automatique serveur OVH"
    echo "Debian 12 + Docker → Configuration complète"
    echo "=================================================================="
    echo "Services qui seront installés et configurés :"
    echo "• Webmin (administration serveur)"
    echo "• SSH sécurisé (port personnalisé + utilisateurs limités)"  
    echo "• Nginx + Certbot (serveur web + SSL automatique)"
    echo "• Portainer (interface Docker)"
    echo "• Fail2ban (protection anti-bots SSH)"
    echo "• Scripts de gestion domaines/vhosts"
    echo "=================================================================="
    echo ""
}

print_step() {
    echo ""
    echo "[ÉTAPE] $1"
}

print_success() {
    echo "OK: $1"
}

print_warning() {
    echo "ATTENTION: $1"
}

print_error() {
    echo "ERREUR: $1"
}

# Validation des ports
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

# Demander confirmation
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ $default == "y" ]]; then
            echo -n "$question [O/n]: "
        else
            echo -n "$question [o/N]: "
        fi
        
        read -n1 yn
        echo  # Pour aller à la ligne après la saisie
        
        case $yn in
            [OoYy] ) return 0;;
            [Nn] ) return 1;;
            "" ) 
                # Touche Entrée = valeur par défaut
                if [[ $default == "y" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            * ) echo "Répondez SEULEMENT par 'o' pour oui ou 'n' pour non.";;
        esac
    done
}

# Détecter l'IP publique du serveur
get_server_ip() {
    local ip
    # Essayer plusieurs services pour détecter l'IP publique
    ip=$(curl -s --connect-timeout 5 ipinfo.io/ip 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s --connect-timeout 5 icanhazip.com 2>/dev/null) || \
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null) || \
    ip="<ADRESSE_IP_SERVEUR>"
    
    echo "$ip"
}

# =============================================================================
# CONFIGURATION INTERACTIVE
# =============================================================================

print_header() {
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

interactive_config() {
    echo ""
    echo "Configuration personnalisée de votre serveur"
    echo ""
    
    # Initialiser les variables par défaut
    SSH_PORT="22"
    WEBMIN_PORT="10000"
    PORTAINER_PORT="9000"
    PORTAINER_PASSWORD=""
    SSH_ALLOWED_USERS="debian root"
    FAIL2BAN_MAXRETRY="5"
    FAIL2BAN_BANTIME="3600"
    INSTALL_PORTAINER=true
    REMOVE_EXIM4=true
    
    print_header "CONFIGURATION DES PORTS"
    
    # Port SSH
    while true; do
        read -e -p "Port SSH : " -i "$SSH_PORT" SSH_PORT
        if validate_port "$SSH_PORT"; then
            echo "✓ Port SSH: $SSH_PORT"
            break
        else
            echo "ERREUR: Port invalide (1-65535)"
        fi
    done
    
    # Port Webmin  
    while true; do
        read -e -p "Port Webmin : " -i "$WEBMIN_PORT" WEBMIN_PORT
        if validate_port "$WEBMIN_PORT" && [ "$WEBMIN_PORT" != "$SSH_PORT" ]; then
            echo "✓ Port Webmin: $WEBMIN_PORT"
            break
        else
            echo "ERREUR: Port invalide ou identique au SSH ($SSH_PORT)"
        fi
    done
    
    # Port Portainer
    while true; do
        read -e -p "Port Portainer : " -i "$PORTAINER_PORT" PORTAINER_PORT
        if validate_port "$PORTAINER_PORT" && [ "$PORTAINER_PORT" != "$SSH_PORT" ] && [ "$PORTAINER_PORT" != "$WEBMIN_PORT" ]; then
            echo "✓ Port Portainer: $PORTAINER_PORT"
            break
        else
            echo "ERREUR: Port invalide ou déjà pris (SSH=$SSH_PORT, Webmin=$WEBMIN_PORT)"
        fi
    done
    
    echo ""
    print_header "CONFIGURATION SSH ET SÉCURITÉ"
    
    # Utilisateurs SSH autorisés
    read -e -p "Utilisateurs SSH autorisés : " -i "$SSH_ALLOWED_USERS" SSH_ALLOWED_USERS
    echo "✓ Utilisateurs SSH: $SSH_ALLOWED_USERS"
    
    # Configuration Fail2ban - avec explications claires
    echo ""
    echo "FAIL2BAN - Protection contre les attaques SSH par force brute"
    echo "Bloque automatiquement les IP qui font trop de tentatives de connexion"
    echo ""
    read -e -p "Nombre max tentatives avant blocage : " -i "$FAIL2BAN_MAXRETRY" FAIL2BAN_MAXRETRY
    read -e -p "Durée de blocage en secondes : " -i "$FAIL2BAN_BANTIME" FAIL2BAN_BANTIME
    
    echo "✓ Fail2ban: $FAIL2BAN_MAXRETRY tentatives max, blocage $FAIL2BAN_BANTIME secondes"
    
    # Configuration mot de passe Portainer
    echo ""
    echo "CONFIGURATION PORTAINER - Mot de passe administrateur"
    echo "Définissez un mot de passe sécurisé pour l'accès admin à Portainer"
    echo ""
    
    while true; do
        read -p "Mot de passe admin Portainer : " PORTAINER_PASSWORD
        if [[ ${#PORTAINER_PASSWORD} -ge 12 ]]; then
            echo "✓ Mot de passe accepté (${#PORTAINER_PASSWORD} caractères)"
            break
        else
            echo "ERREUR: Le mot de passe doit contenir au moins 12 caractères (exigence Portainer)"
        fi
    done
    
    # Services optionnels
    echo ""
    print_header "SERVICES OPTIONNELS"
    
    # Portainer est obligatoire
    INSTALL_PORTAINER=true
    echo "✓ Portainer sera installé (obligatoire)"
    echo "⚠️  IMPORTANT: Définissez le mot de passe admin dès le 1er accès"
    echo "   Tant qu'aucun admin n'est créé, n'importe qui peut le faire !"
    
    # Exim4 sera supprimé automatiquement
    REMOVE_EXIM4=true
    echo "✓ Exim4 sera supprimé (pas utile pour un serveur web)"
    
    # Afficher un résumé
    echo ""
    echo "=================================================================="
    echo "RÉSUMÉ DE LA CONFIGURATION"
    echo "=================================================================="
    echo "PORTS:"
    echo "  • SSH: $SSH_PORT (utilisateurs: $SSH_ALLOWED_USERS)"
    echo "  • Webmin: $WEBMIN_PORT"
    echo "  • Portainer: $PORTAINER_PORT"
    echo "  • Web (Nginx): 80, 443"
    echo ""
    echo "SÉCURITÉ:"
    echo "  • Fail2ban: $FAIL2BAN_MAXRETRY tentatives max, blocage ${FAIL2BAN_BANTIME}s"
    echo "  • Portainer: Utilisateur admin, mot de passe sécurisé défini"
    echo ""
    echo "SERVICES:"
    echo "  • Portainer: Oui (obligatoire)"
    echo "  • Exim4: Supprimé (automatique)"
    echo "=================================================================="
    echo ""
    
    if ! ask_yes_no "CONFIRMER et lancer l'installation ?" "y"; then
        echo "Installation annulée"
        exit 0
    fi
}

# =============================================================================
# INSTALLATION DES COMPOSANTS
# =============================================================================

check_prerequisites() {
    print_step "Vérification de l'environnement OVH"
    
    # Vérifier si root
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo ./setup.sh"
        exit 1
    fi
    
    # Vérifier Debian 12
    if ! grep -q "bookworm" /etc/os-release 2>/dev/null; then
        print_error "Ce script est conçu pour Debian 12 (bookworm)"
        echo "ATTENTION: Distribution détectée: $(lsb_release -d 2>/dev/null || echo 'Inconnue')"
        if ! ask_yes_no "Continuer malgré tout ?" "n"; then
            exit 1
        fi
    else
        print_success "Debian 12 (bookworm) détecté"
    fi
    
    # Vérifier Docker (pré-installé par OVH)
    if command -v docker &> /dev/null; then
        print_success "Docker détecté"
        docker --version | head -1
    else
        echo "ATTENTION: Docker non détecté, il sera installé automatiquement"
    fi
    
    # Vérifier les templates et scripts
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        print_error "Dossier templates/ non trouvé dans $TEMPLATES_DIR"
        echo "Assurez-vous d'avoir cloné le projet complet"
        exit 1
    fi
    
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        print_error "Dossier scripts/ non trouvé dans $SCRIPTS_DIR"
        echo "Assurez-vous d'avoir cloné le projet complet"
        exit 1
    fi
    
    # Vérifier connexion internet
    if ! ping -c 1 google.com &> /dev/null; then
        print_error "Pas de connexion internet détectée"
        exit 1
    fi
    
    print_success "Environnement OVH vérifié et prêt"
}

install_common_packages() {
    print_step "Installation des paquets de base"
    
    apt update
    apt install -y wget apt-transport-https software-properties-common curl
    
    print_success "Paquets de base installés"
}

install_webmin() {
    print_step "Installation de Webmin"
    
    # Ajouter la clé et le dépôt
    wget -qO - http://www.webmin.com/jcameron-key.asc | apt-key add -
    echo "deb http://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    
    apt update
    apt install -y webmin
    
    # Configuration avec le template
    echo "Configuration de Webmin sur le port $WEBMIN_PORT"
    sed "s/__WEBMIN_PORT__/$WEBMIN_PORT/g" "$TEMPLATES_DIR/miniserv.conf" > /etc/webmin/miniserv.conf
    
    systemctl restart webmin
    systemctl enable webmin
    
    print_success "Webmin installé et configuré"
}

configure_ssh() {
    print_step "Configuration sécurisée de SSH"
    
    # Sauvegarde (comme dans l'ancien script)
    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup.$(date +%F-%H%M)"
    
    # Configuration SSH (logique identique à l'ancien script)
    sed -i 's/^Port /#Port /' /etc/ssh/sshd_config
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    echo "AllowUsers $SSH_ALLOWED_USERS" >> /etc/ssh/sshd_config
    
    # Test et redémarrage (comme l'ancien script)
    if sshd -t; then
        systemctl restart ssh
        print_success "SSH configuré sur le port $SSH_PORT"
        
        # Vérification finale (comme dans l'ancien script)
        ss -tlnp | grep sshd | head -3
    else
        print_error "Configuration SSH invalide, restauration de la sauvegarde"
        cp "/etc/ssh/sshd_config.backup.$(date +%F-%H%M)" /etc/ssh/sshd_config
        exit 1
    fi
}

install_fail2ban() {
    print_step "Installation et configuration de Fail2ban"
    
    apt install -y fail2ban
    
    # Configuration avec template (respecte la logique de l'ancien script)
    echo "Configuration Fail2ban: port $SSH_PORT, $FAIL2BAN_MAXRETRY tentatives max, ban $FAIL2BAN_BANTIME s"
    sed -e "s/__SSH_PORT__/$SSH_PORT/g" \
        -e "s/__MAX_RETRY__/$FAIL2BAN_MAXRETRY/g" \
        -e "s/__BAN_TIME__/$FAIL2BAN_BANTIME/g" \
        "$TEMPLATES_DIR/fail2ban-jail.local" > /etc/fail2ban/jail.local
    
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    print_success "Fail2ban configuré (port $SSH_PORT, $FAIL2BAN_MAXRETRY tentatives max, ban $FAIL2BAN_BANTIME s)"
}

install_nginx_stack() {
    print_step "Installation de Nginx + Certbot + SSL auto-signé + whiptail"
    
    apt install -y nginx certbot python3-certbot-nginx whiptail ssl-cert
    
    print_step "Configuration de Nginx..."
    
    # Sauvegarder la config par défaut
    cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    
    # Arrêter nginx si démarré pour éviter les conflits
    systemctl stop nginx 2>/dev/null || true
    
    # Configuration nginx par défaut
    cp "$TEMPLATES_DIR/nginx-default.conf" /etc/nginx/sites-available/default
    
    # Test de la configuration nginx
    if ! nginx -t; then
        print_error "Erreur dans la configuration Nginx"
        echo "Restauration de la config par défaut..."
        cp /etc/nginx/sites-available/default.backup /etc/nginx/sites-available/default
    fi
    
    # Démarrage de nginx avec vérification
    systemctl enable nginx
    if systemctl start nginx; then
        print_success "Nginx démarré avec succès"
        systemctl reload nginx
    else
        print_error "Erreur au démarrage de Nginx - Vérifiez les logs: journalctl -xeu nginx.service"
        return 1
    fi
    
    # Installer la page d'accueil par défaut
    echo "Installation de la page d'accueil par défaut..."
    cp "$TEMPLATES_DIR/index.html" /var/www/html/
    chown www-data:www-data /var/www/html/index.html
    
    print_success "Stack Nginx installée"
}

install_portainer() {
    print_step "Installation de Portainer (interface Docker)"
    
    # Vérifier si Docker est installé, sinon l'installer
    if ! command -v docker &> /dev/null; then
        echo "Installation de Docker (non pré-installé par OVH)..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl enable docker
        systemctl start docker
        rm -f get-docker.sh
        print_success "Docker installé"
    else
        echo "Docker déjà disponible (pré-installé OVH)"
    fi
    
    # Installer Portainer
    echo "Téléchargement et démarrage de Portainer..."
    docker volume create portainer_data 2>/dev/null || true
    
    # Arrêter un éventuel Portainer existant
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    
    # Générer le hash bcrypt du mot de passe
    echo "Génération du hash sécurisé du mot de passe..."
    HASH=$(docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$PORTAINER_PASSWORD" | cut -d ":" -f2)
    
    # Supprimer l'image httpd utilisée pour le hash (nettoyage)
    docker rmi httpd:2.4-alpine 2>/dev/null || true
    
    # Lancer Portainer avec le mot de passe sécurisé
    docker run -d \
        -p ${PORTAINER_PORT}:9000 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest \
        --admin-password="$HASH"
    
    print_success "Portainer installé avec mot de passe sécurisé → http://$SERVER_IP:$PORTAINER_PORT"
}

cleanup_services() {
    print_step "Suppression d'Exim4"
    
    apt purge exim4 exim4-base exim4-config exim4-daemon-light -y || true
    apt autoremove --purge -y
    
    print_success "Exim4 supprimé"
}

install_management_scripts() {
    print_step "Installation des scripts de gestion vhost Debian 12"
    
    # Vérifier que les scripts existent
    if [[ ! -f "$SCRIPTS_DIR/vhost-manager.sh" ]]; then
        print_error "Scripts de gestion vhost non trouvés dans $SCRIPTS_DIR"
        exit 1
    fi
    
    # Rendre les scripts exécutables
    chmod +x "$SCRIPTS_DIR"/*.sh
    
    # Copier les scripts de gestion spécifiques à Debian 12 + Docker
    cp "$SCRIPTS_DIR/vhost-manager.sh" /usr/local/bin/vhost-manager.sh
    
    chmod +x /usr/local/bin/vhost-manager.sh
    
    print_success "Scripts de gestion vhost Debian 12 installés"
    echo "• vhost-manager.sh - Interface TUI complète"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_banner
    
    # Détecter l'IP publique du serveur
    SERVER_IP=$(get_server_ip)
    echo "IP publique détectée: $SERVER_IP"
    echo ""
    
    # Vérifications
    check_prerequisites
    
    # Configuration interactive
    interactive_config
    
    # Installation dans le même ordre que l'ancien script
    install_common_packages
    install_webmin
    cleanup_services  # Avant SSH pour éviter les conflits
    configure_ssh
    install_fail2ban
    install_nginx_stack
    install_portainer
    install_management_scripts
    
    # Résumé final
    echo ""
    echo "=================================================================="
    echo "SERVEUR OVH DÉPLOYÉ AVEC SUCCÈS !"
    echo "=================================================================="
    echo ""
    echo "Accès à vos services :"
    
    if [[ $SSH_PORT != "22" ]]; then
        echo "• SSH: ssh root@$SERVER_IP -p $SSH_PORT"
    else
        echo "• SSH: ssh root@$SERVER_IP (port 22)"
    fi
    
    echo "• Webmin: http://$SERVER_IP:$WEBMIN_PORT"
    echo "• Portainer: http://$SERVER_IP:$PORTAINER_PORT"
    echo "• Sites web: http://$SERVER_IP (nginx + SSL automatique)"
    echo ""
    echo "Gestion des domaines/vhosts :"
    echo "• vhost-manager.sh → Interface complète de gestion des domaines"
    echo ""
    echo "IMPORTANT - Sauvegardez ces informations :"
    echo "• Port SSH: $SSH_PORT"
    echo "• Port Webmin: $WEBMIN_PORT"
    echo "• Port Portainer: $PORTAINER_PORT"
    echo "• Utilisateurs SSH autorisés: $SSH_ALLOWED_USERS"
    echo "• Fail2ban actif (protection SSH)"
    echo ""
    echo "Prochaines étapes recommandées :"
    
    if [[ $SSH_PORT != "22" ]]; then
        echo "1. Testez la nouvelle connexion SSH avec le port $SSH_PORT"
    fi
    
    echo "2. Configurez vos premiers domaines avec 'vhost-manager.sh'"
    echo "3. Accédez à Webmin pour la gestion système avancée"
    
    echo ""
    echo "Votre serveur VPS OVH est maintenant opérationnel !"
    echo "=================================================================="
}

# Lancer le script
main "$@"