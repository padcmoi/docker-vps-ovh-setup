#!/bin/bash

# Script de connexion automatisée VPS avec gestion des clés SSH
# Compatible avec toutes les distributions

set -e

echo "🚀 Configuration automatique de connexion VPS"
echo "=============================================="

# Saisie des informations VPS
read -p "IP du VPS : " VPS_IP
read -p "Port SSH (défaut 22) : " VPS_PORT
VPS_PORT=${VPS_PORT:-22}
read -p "Utilisateur (défaut: debian) : " VPS_USER
VPS_USER=${VPS_USER:-debian}

echo ""
echo "📋 VPS configuré : $VPS_USER@$VPS_IP:$VPS_PORT"

# Test de connexion initiale
echo ""
echo "🔐 Test de connexion initial..."
if ! ssh -o ConnectTimeout=10 -p $VPS_PORT $VPS_USER@$VPS_IP "echo 'Connexion OK'"; then
    echo "❌ Erreur : Impossible de se connecter au VPS"
    exit 1
fi

# Gestion des clés SSH (optionnelle)
echo ""
echo "🔑 Configuration des clés SSH (recommandé pour éviter les mots de passe)"
read -p "Voulez-vous configurer une clé SSH ? (o/N) : " SETUP_SSH
SETUP_SSH=${SETUP_SSH:-n}

if [[ $SETUP_SSH =~ ^[Oo]$ ]]; then
    # Recherche des clés SSH disponibles
    SSH_KEYS=($(find ~/.ssh -name "*.pub" 2>/dev/null | sort))
    
    if [ ${#SSH_KEYS[@]} -eq 0 ]; then
        echo "❌ Aucune clé SSH publique trouvée dans ~/.ssh/"
        echo "💡 Générez d'abord une clé avec : ssh-keygen -t rsa -b 4096"
        exit 1
    fi
    
    echo ""
    echo "📝 Clés SSH disponibles :"
    for i in "${!SSH_KEYS[@]}"; do
        echo "  $((i+1)). ${SSH_KEYS[$i]}"
    done
    
    echo "  0. Annuler"
    echo ""
    
    while true; do
        read -p "Choisissez votre clé (1-${#SSH_KEYS[@]}) : " KEY_CHOICE
        
        if [[ $KEY_CHOICE -eq 0 ]]; then
            echo "❌ Configuration SSH annulée"
            break
        elif [[ $KEY_CHOICE -ge 1 && $KEY_CHOICE -le ${#SSH_KEYS[@]} ]]; then
            SELECTED_KEY="${SSH_KEYS[$((KEY_CHOICE-1))]}"
            echo ""
            echo "🔑 Clé sélectionnée : $SELECTED_KEY"
            
            # Installation de la clé SSH
            echo "📤 Installation de la clé SSH sur le VPS..."
            if ssh-copy-id -i "$SELECTED_KEY" -p $VPS_PORT $VPS_USER@$VPS_IP; then
                echo "✅ Clé SSH installée avec succès"
                
                # Test de connexion sans mot de passe
                echo ""
                echo "🔐 Test de connexion sans mot de passe..."
                if ssh -o PasswordAuthentication=no -p $VPS_PORT $VPS_USER@$VPS_IP "echo 'Connexion SSH sans mot de passe : OK'"; then
                    echo "✅ Configuration SSH réussie !"
                else
                    echo "⚠️  Connexion par clé installée mais mot de passe encore demandé"
                fi
            else
                echo "❌ Erreur lors de l'installation de la clé SSH"
                exit 1
            fi
            break
        else
            echo "❌ Choix invalide. Entrez un numéro entre 0 et ${#SSH_KEYS[@]}"
        fi
    done
fi

# Connexion finale et informations
echo ""
echo "🎯 Configuration terminée !"
echo "=============================================="
echo "Commande de connexion :"
echo "  ssh -p $VPS_PORT $VPS_USER@$VPS_IP"
echo ""
# Proposition d'installation automatique
echo ""
echo "💡 PROCHAINES ÉTAPES À RÉALISER SUR LE VPS :"
echo "  Téléchargement et exécution du script d'installation"
echo ""

# Options d'installation
echo "🚀 Options d'installation :"
echo "  1. Installation automatique (recommandé)"
echo "  2. Connexion manuelle au VPS"
echo "  0. Quitter"
echo ""

while true; do
    read -p "Choisissez une option (0-2) : " INSTALL_CHOICE
    
    case $INSTALL_CHOICE in
        1)
            echo ""
            echo "🔄 Installation automatique en cours..."
            echo "=============================================="
            
            # Exécution du script d'installation sur le VPS
            if ssh -p $VPS_PORT $VPS_USER@$VPS_IP "
                echo '🌐 Téléchargement des fichiers d'\''installation...'
                
                # Créer la structure de dossiers
                mkdir -p templates/debian12-docker
                mkdir -p scripts/debian12-docker
                
                # Télécharger le script principal
                wget -q https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/setup-debian12-docker-ovh.sh
                
                # Télécharger les templates
                wget -q -O templates/debian12-docker/miniserv.conf https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/templates/debian12-docker/miniserv.conf
                wget -q -O templates/debian12-docker/nginx-default.conf https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/templates/debian12-docker/nginx-default.conf
                wget -q -O templates/debian12-docker/fail2ban-jail.local https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/templates/debian12-docker/fail2ban-jail.local
                wget -q -O templates/debian12-docker/config.sample https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/templates/debian12-docker/config.sample
                
                # Télécharger les scripts
                wget -q -O scripts/debian12-docker/vhost-manager.sh https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/scripts/debian12-docker/vhost-manager.sh
                
                # Vérifier que tout est téléchargé
                if [ ! -f setup-debian12-docker-ovh.sh ] || [ ! -f templates/debian12-docker/miniserv.conf ] || [ ! -f scripts/debian12-docker/vhost-manager.sh ]; then
                    echo '❌ Erreur : Impossible de télécharger tous les fichiers nécessaires'
                    exit 1
                fi
                
                chmod +x setup-debian12-docker-ovh.sh
                chmod +x scripts/debian12-docker/vhost-manager.sh
                echo '✅ Tous les fichiers téléchargés avec succès'
                echo ''
                echo '🚀 Lancement de l'\''installation automatique...'
                echo '=============================================='
                sudo ./setup-debian12-docker-ovh.sh
            "; then
                echo ""
                echo "🎉 Installation terminée avec succès !"
                echo "=============================================="
                echo "Votre VPS est maintenant configuré et sécurisé."
                echo ""
                echo "Commande de connexion :"
                echo "  ssh -p $VPS_PORT $VPS_USER@$VPS_IP"
            else
                echo ""
                echo "❌ Erreur lors de l'installation automatique"
                echo "Vous pouvez essayer l'installation manuelle (option 2)"
            fi
            break
            ;;
        2)
            echo ""
            echo "📋 Instructions pour installation manuelle :"
            echo "=============================================="
            echo "1. Connectez-vous au VPS :"
            echo "   ssh -p $VPS_PORT $VPS_USER@$VPS_IP"
            echo ""
            echo "2. Exécutez ces commandes :"
            echo "   wget https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/setup-debian12-docker-ovh.sh"
            echo "   mkdir -p templates/debian12-docker scripts/debian12-docker"
            echo "   wget -O templates/debian12-docker/miniserv.conf https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/templates/debian12-docker/miniserv.conf"
            echo "   wget -O scripts/debian12-docker/vhost-manager.sh https://raw.githubusercontent.com/padcmoi/docker-vps-ovh-setup/main/scripts/debian12-docker/vhost-manager.sh"
            echo "   chmod +x setup-debian12-docker-ovh.sh scripts/debian12-docker/vhost-manager.sh"
            echo "   sudo ./setup-debian12-docker-ovh.sh"
            echo ""
            echo "🚀 Connexion au VPS..."
            ssh -p $VPS_PORT $VPS_USER@$VPS_IP
            break
            ;;
        0)
            echo ""
            echo "👋 Configuration terminée. À bientôt !"
            break
            ;;
        *)
            echo "❌ Choix invalide. Entrez 0, 1 ou 2."
            ;;
    esac
done