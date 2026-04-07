#!/bin/bash

# =============================================================================
# Script de configuration automatique - OVH Debian 12 + Docker
# 🎯 Automatise le setup complet d'un nouveau serveur VPS OVH
# =============================================================================
#
# Prérequis : VPS OVH avec Debian 12 + Docker (option OVH)
# Usage : git clone + ./setup-debian12-docker-ovh.sh
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

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${SCRIPT_DIR}/templates/debian12-docker"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts/debian12-docker"
AUTO_MODE=false

# Gestion des arguments
for arg in "$@"; do
	case "$arg" in
	--auto|--non-interactive)
		AUTO_MODE=true
		;;
	-h|--help)
		echo "Usage: $0 [--auto]"
		echo "  --auto, --non-interactive   Exécute l'installation avec les valeurs par défaut"
		exit 0
		;;
	esac
done

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

print_banner() {
	echo -e "${CYAN}"
	echo "=================================================================="
	echo "🚀 Déploiement automatique serveur OVH"
	echo "📋 Debian 12 + Docker → Configuration complète"
	echo "=================================================================="
	echo -e "${BLUE}Services qui seront installés et configurés :"
	echo "• Webmin (administration serveur)"
	echo "• SSH sécurisé (port personnalisé + utilisateurs limités)"
	echo "• Nginx + Certbot (serveur web + SSL automatique)"
	echo "• Portainer (interface Docker)"
	echo "• Fail2ban (protection anti-bots SSH)"
	echo "• Scripts de gestion domaines/vhosts"
	echo -e "${CYAN}=================================================================="
	echo -e "${NC}"
}

print_step() {
	echo -e "\n${BLUE}[ÉTAPE]${NC} $1"
}

print_header() {
	echo -e "\n${CYAN}--- $1 ---${NC}"
}

print_info() {
	echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
	echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
	echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
	echo -e "${RED}❌ $1${NC}"
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

	if [[ "$AUTO_MODE" == true || ! -t 0 ]]; then
		if [[ $default == "y" ]]; then
			print_info "$question [Y/n] -> oui (mode non interactif)"
			return 0
		else
			print_info "$question [y/N] -> non (mode non interactif)"
			return 1
		fi
	fi

	while true; do
		if [[ $default == "y" ]]; then
			read -p "$question [Y/n]: " yn
		else
			read -p "$question [y/N]: " yn
		fi

		yn=${yn:-$default}
		case $yn in
		[Yy]*) return 0 ;;
		[Nn]*) return 1 ;;
		*) echo "Veuillez répondre oui ou non." ;;
		esac
	done
}

prompt_with_default() {
	local prompt="$1"
	local default="$2"
	local value

	read -r -p "$prompt [$default]: " value
	echo "${value:-$default}"
}

apply_default_config() {
	print_step "Configuration automatique (mode non interactif)"

	SSH_PORT="${SSH_PORT:-22}"
	WEBMIN_PORT="${WEBMIN_PORT:-10000}"
	PORTAINER_PORT="${PORTAINER_PORT:-9000}"
	SSH_ALLOWED_USERS="${SSH_ALLOWED_USERS:-root debian}"
	FAIL2BAN_MAXRETRY="${FAIL2BAN_MAXRETRY:-5}"
	FAIL2BAN_BANTIME="${FAIL2BAN_BANTIME:-3600}"
	INSTALL_PORTAINER="${INSTALL_PORTAINER:-true}"
	REMOVE_EXIM4="${REMOVE_EXIM4:-true}"
	INSTALL_SSH_KEY=false

	echo "• SSH Port: $SSH_PORT (utilisateurs: $SSH_ALLOWED_USERS)"
	echo "• Webmin Port: $WEBMIN_PORT"
	if [[ $INSTALL_PORTAINER == true ]]; then
		echo "• Portainer Port: $PORTAINER_PORT"
	else
		echo "• Portainer: désactivé"
	fi
	echo "• Fail2ban: $FAIL2BAN_MAXRETRY tentatives max, ban ${FAIL2BAN_BANTIME}s"
}

# =============================================================================
# CONFIGURATION INTERACTIVE
# =============================================================================

interactive_config() {
	print_step "Configuration personnalisée de votre serveur"

	echo ""
	print_header "CONFIGURATION DES PORTS"
	echo "Configuration des ports personnalisés pour votre VPS"
	echo "Appuyez sur Entrée pour utiliser les ports par défaut"
	echo ""

	# Port SSH
	while true; do
		SSH_PORT=$(prompt_with_default "Port SSH" "22")
		if validate_port "$SSH_PORT"; then
			break
		else
			print_error "Port invalide. Utilisez un port entre 1 et 65535."
		fi
	done

	# Port Webmin
	while true; do
		WEBMIN_PORT=$(prompt_with_default "Port Webmin" "10000")
		if validate_port "$WEBMIN_PORT" && [ "$WEBMIN_PORT" != "$SSH_PORT" ]; then
			break
		else
			print_error "Port invalide ou identique au port SSH ($SSH_PORT). Port différent requis."
		fi
	done

	# Port Portainer
	while true; do
		PORTAINER_PORT=$(prompt_with_default "Port Portainer" "9000")
		if validate_port "$PORTAINER_PORT" && [ "$PORTAINER_PORT" != "$SSH_PORT" ] && [ "$PORTAINER_PORT" != "$WEBMIN_PORT" ]; then
			break
		else
			print_error "Port invalide ou déjà utilisé. Ports pris: SSH=$SSH_PORT, Webmin=$WEBMIN_PORT"
		fi
	done

	# Utilisateurs SSH autorisés
	echo ""
	print_info "Sécurité SSH - Utilisateurs autorisés"
	SSH_ALLOWED_USERS=$(prompt_with_default "Utilisateurs SSH autorisés" "root debian")

	# Configuration Fail2ban
	echo ""
	print_info "Protection Fail2ban (anti-bots SSH)"
	FAIL2BAN_MAXRETRY=$(prompt_with_default "Nombre max tentatives connexion" "5")

	FAIL2BAN_BANTIME=$(prompt_with_default "Durée de ban en secondes" "3600")

	# Services optionnels
	echo ""
	print_step "Services optionnels"

	if ask_yes_no "Installer Portainer (recommandé pour gérer Docker) ?" "y"; then
		INSTALL_PORTAINER=true
	else
		INSTALL_PORTAINER=false
	fi

	if ask_yes_no "Supprimer Exim4 (serveur mail par défaut - recommandé) ?" "y"; then
		REMOVE_EXIM4=true
	else
		REMOVE_EXIM4=false
	fi

	# Configuration clés SSH
	echo ""
	print_info "Configuration des clés SSH (optionnel)"
	if ask_yes_no "Voulez-vous ajouter une clé SSH publique pour l'authentification sans mot de passe ?" "n"; then
		SSH_KEY_PATH=$(prompt_with_default "Chemin vers votre clé publique" "~/.ssh/id_rsa.pub")

		if [[ -f "$SSH_KEY_PATH" ]]; then
			SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")
			INSTALL_SSH_KEY=true
		else
			print_warning "Clé non trouvée : $SSH_KEY_PATH"
			print_info "Vous pourrez l'ajouter manuellement après l'installation avec :"
			print_info "ssh-copy-id -i ~/.ssh/id_rsa.pub root@serveur -p PORT"
			INSTALL_SSH_KEY=false
		fi
	else
		INSTALL_SSH_KEY=false
	fi

	# Afficher un résumé
	echo ""
	print_step "🔍 Résumé de votre configuration"
	echo "• SSH Port: $SSH_PORT (utilisateurs: $SSH_ALLOWED_USERS)"
	echo "• Webmin Port: $WEBMIN_PORT"
	if [[ $INSTALL_PORTAINER == true ]]; then
		echo "• Portainer Port: $PORTAINER_PORT"
	fi
	echo "• Nginx: ports 80/443 (gestion SSL automatique)"
	echo "• Fail2ban: $FAIL2BAN_MAXRETRY tentatives max, ban ${FAIL2BAN_BANTIME}s"
	echo ""

	if ! ask_yes_no "🚀 Lancer l'installation avec cette configuration ?" "y"; then
		print_info "Installation annulée"
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
		print_info "Utilisez: sudo ./setup-debian12-docker-ovh.sh"
		exit 1
	fi

	# Vérifier Debian 12
	if ! grep -q "bookworm" /etc/os-release 2>/dev/null; then
		print_error "Ce script est conçu pour Debian 12 (bookworm)"
		print_warning "Distribution détectée: $(lsb_release -d 2>/dev/null || echo 'Inconnue')"
		if ! ask_yes_no "Continuer malgré tout ?" "n"; then
			exit 1
		fi
	else
		print_success "Debian 12 (bookworm) détecté ✓"
	fi

	# Vérifier Docker (pré-installé par OVH)
	if command -v docker &>/dev/null; then
		print_success "Docker détecté ✓"
		docker --version | head -1
	else
		print_warning "Docker non détecté, il sera installé automatiquement"
	fi

	# Vérifier les templates et scripts
	if [[ ! -d "$TEMPLATES_DIR" ]]; then
		print_error "Dossier templates/ non trouvé dans $TEMPLATES_DIR"
		print_info "Assurez-vous d'avoir cloné le projet complet"
		exit 1
	fi

	if [[ ! -d "$SCRIPTS_DIR" ]]; then
		print_error "Dossier scripts/ non trouvé dans $SCRIPTS_DIR"
		print_info "Assurez-vous d'avoir cloné le projet complet"
		exit 1
	fi

	# Vérifier connexion internet
	if ! ping -c 1 google.com &>/dev/null; then
		print_error "Pas de connexion internet détectée"
		exit 1
	fi

	print_success "Environnement OVH vérifié et prêt"
}

install_common_packages() {
	print_step "Installation des paquets de base"

	apt update
	apt install -y wget apt-transport-https software-properties-common curl cron
	systemctl enable --now cron

	print_success "Paquets de base installés"
}

install_webmin() {
	print_step "Installation de Webmin"

	# Ajouter la clé et le dépôt
	wget -qO - http://www.webmin.com/jcameron-key.asc | apt-key add -
	echo "deb http://download.webmin.com/download/repository sarge contrib" >/etc/apt/sources.list.d/webmin.list

	apt update
	apt install -y webmin

	# Configurer avec le template
	print_info "Configuration de Webmin sur le port $WEBMIN_PORT"
	sed "s/__WEBMIN_PORT__/$WEBMIN_PORT/g" "$TEMPLATES_DIR/miniserv.conf" >/etc/webmin/miniserv.conf

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
	echo "Port $SSH_PORT" >>/etc/ssh/sshd_config
	echo "AllowUsers $SSH_ALLOWED_USERS" >>/etc/ssh/sshd_config

	# Installation de la clé SSH si demandé
	if [[ $INSTALL_SSH_KEY == true ]]; then
		print_info "Installation de la clé SSH publique..."
		mkdir -p /root/.ssh
		chmod 700 /root/.ssh
		echo "$SSH_KEY_CONTENT" >>/root/.ssh/authorized_keys
		chmod 600 /root/.ssh/authorized_keys
		print_success "Clé SSH installée pour l'authentification sans mot de passe"
	fi

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
	sed -e "s/__SSH_PORT__/$SSH_PORT/g" \
		-e "s/__MAX_RETRY__/$FAIL2BAN_MAXRETRY/g" \
		-e "s/__BAN_TIME__/$FAIL2BAN_BANTIME/g" \
		"$TEMPLATES_DIR/fail2ban-jail.local" >/etc/fail2ban/jail.local

	systemctl restart fail2ban
	systemctl enable fail2ban

	print_success "Fail2ban configuré (port $SSH_PORT, $FAIL2BAN_MAXRETRY tentatives max, ban $FAIL2BAN_BANTIME s)"
}

install_nginx_stack() {
	print_step "Installation de Nginx + Certbot + whiptail"

	apt install -y nginx certbot python3-certbot-nginx whiptail
	rm -f /etc/cron.d/certbot || true
	echo '0 2 * * * root certbot renew -q --preferred-challenges http --standalone --pre-hook "systemctl stop nginx || systemctl stop apache2" --post-hook "systemctl start nginx || systemctl start apache2"' >/etc/cron.d/certbot-standalone

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
		print_info "Restauration de la config par défaut..."
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

	print_success "Stack Nginx installée"
}

install_portainer() {
	if [[ $INSTALL_PORTAINER != true ]]; then
		print_info "Portainer ignoré (choix utilisateur)"
		return 0
	fi

	print_step "Installation de Portainer (interface Docker)"

	# Vérifier si Docker est installé, sinon l'installer
	if ! command -v docker &>/dev/null; then
		print_info "Installation de Docker (non pré-installé par OVH)..."
		curl -fsSL https://get.docker.com -o get-docker.sh
		sh get-docker.sh
		systemctl enable docker
		systemctl start docker
		rm -f get-docker.sh
		print_success "Docker installé"
	else
		print_info "Docker déjà disponible (pré-installé OVH)"
	fi

	# Installer Portainer
	print_info "Téléchargement et démarrage de Portainer..."
	docker volume create portainer_data 2>/dev/null || true

	# Arrêter un éventuel Portainer existant
	docker stop portainer 2>/dev/null || true
	docker rm portainer 2>/dev/null || true

	# Lancer Portainer
	docker run -d \
		-p ${PORTAINER_PORT}:9000 \
		--name portainer \
		--restart=always \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v portainer_data:/data \
		portainer/portainer-ce:latest

	print_success "Portainer installé → http://votre-serveur:$PORTAINER_PORT"
	print_info "Au premier accès, créez votre compte administrateur"
}

cleanup_services() {
	if [[ $REMOVE_EXIM4 == true ]]; then
		print_step "Suppression d'Exim4"

		apt purge exim4 exim4-base exim4-config exim4-daemon-light -y || true
		apt autoremove --purge -y

		print_success "Exim4 supprimé"
	fi
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
	print_info "• vhost-manager.sh - Interface TUI complète"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
	print_banner

	# Vérifications
	check_prerequisites

	# Configuration interactive
	if [[ "$AUTO_MODE" == true || ! -t 0 ]]; then
		apply_default_config
	else
		interactive_config
	fi

	# Installation dans le même ordre que l'ancien script
	install_common_packages
	install_webmin
	cleanup_services # Avant SSH pour éviter les conflits
	configure_ssh
	install_fail2ban
	install_nginx_stack
	install_portainer
	install_management_scripts

	# Résumé final
	echo ""
	echo "=================================================================="
	print_success "🎉 SERVEUR OVH DÉPLOYÉ AVEC SUCCÈS !"
	echo "=================================================================="
	echo ""
	echo "Accès à vos services :"

	if [[ $SSH_PORT != "22" ]]; then
		echo "• SSH: ssh root@votre-serveur -p $SSH_PORT"
	else
		echo "• SSH: ssh root@votre-serveur (port 22)"
	fi

	echo "• Webmin: http://votre-serveur:$WEBMIN_PORT"

	if [[ $INSTALL_PORTAINER == true ]]; then
		echo "• Portainer: http://votre-serveur:$PORTAINER_PORT"
	fi

	echo "• Sites web: http://votre-serveur (nginx + SSL automatique)"
	echo ""
	echo "Gestion des domaines/vhosts :"
	echo "• vhost-manager.sh → Interface complète de gestion des domaines"
	echo ""
	print_warning "📝 IMPORTANT - Sauvegardez ces informations :"
	echo "• Port SSH: $SSH_PORT"
	echo "• Port Webmin: $WEBMIN_PORT"
	if [[ $INSTALL_PORTAINER == true ]]; then
		echo "• Port Portainer: $PORTAINER_PORT"
	fi
	echo "• Utilisateurs SSH autorisés: $SSH_ALLOWED_USERS"
	echo "• Fail2ban actif (protection SSH)"
	echo ""
	print_info "🚀 Prochaines étapes recommandées :"

	if [[ $SSH_PORT != "22" ]]; then
		echo "1. Testez la nouvelle connexion SSH avec le port $SSH_PORT"
	fi

	echo "2. Configurez vos premiers domaines avec 'vhost-manager.sh'"
	echo "3. Accédez à Webmin pour la gestion système avancée"

	if [[ $INSTALL_PORTAINER == true ]]; then
		echo "4. Configurez Portainer (créer admin au 1er accès)"
	fi

	echo ""
	print_success "🏆 Votre serveur VPS OVH est maintenant opérationnel !"
	echo "=================================================================="
}

# Lancer le script
main "$@"
