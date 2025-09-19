#!/bin/bash

# Script de connexion automatisée VPS avec gestion des clés SSH
# Compatible avec toutes les distributions

clear

set -e

echo "Configuration automatique d'installation VPS"
echo "=============================================="

# Sélection du template d'installation
echo ""
echo "Templates d'installation disponibles :"

# Scanner les templates disponibles
TEMPLATES=()
TEMPLATE_DIRS=()
counter=1

for template_dir in templates/*/; do
    if [[ -d "$template_dir" && -f "${template_dir}template.info" ]]; then
        # Lire les informations du template
        source "${template_dir}template.info"
        
        # Afficher dans le menu
        echo "  $counter. $DISPLAY_NAME"
        
        # Stocker les informations
        TEMPLATES[$counter]="$DISPLAY_NAME"
        TEMPLATE_DIRS[$counter]="$(basename "$template_dir")"
        
        ((counter++))
    fi
done

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
    echo "ERREUR: Aucun template trouvé avec un fichier template.info"
    exit 1
fi

echo ""

# Construire le regex pour les choix valides
max_choice=$((counter-1))
choice_regex="^[1-$max_choice]$"

while true; do
    echo -n "Choisissez votre template (1-$max_choice): "
    read -n1 TEMPLATE_CHOICE
    echo  # Aller à la ligne
    
    if [[ $TEMPLATE_CHOICE =~ $choice_regex ]]; then
        # Recharger les infos du template sélectionné
        selected_dir="${TEMPLATE_DIRS[$TEMPLATE_CHOICE]}"
        source "templates/$selected_dir/template.info"
        
        TEMPLATE_NAME="$selected_dir"
        SETUP_SCRIPT="scripts/$selected_dir/$SCRIPT_NAME"
        echo "✓ Template sélectionné: $DESCRIPTION"
        break
    else
        echo "Choisissez le template avec les touches numériques (1-$max_choice)"
    fi
done

echo ""

# Fonction de validation IP
validate_ip() {
    local ip=$1
    # Vérifier le format général avec regex
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Vérifier que chaque octet est entre 0 et 255
        IFS='.' read -ra OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [[ $octet -lt 0 || $octet -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Récupérer l'IP et le port depuis les arguments ou laisser vide
VPS_IP="${1:-}"
VPS_PORT="${2:-22}"

# Saisie des informations VPS avec validation
while true; do
    read -e -p "IP du VPS : " -i "$VPS_IP" VPS_IP
    if [[ -n "$VPS_IP" ]] && validate_ip "$VPS_IP"; then
        echo "✓ IP valide: $VPS_IP"
        break
    else
        echo "ERREUR: IP invalide. Format attendu: xxx.xxx.xxx.xxx (0-255 pour chaque partie)"
    fi
done

read -e -p "Port SSH : " -i "$VPS_PORT" VPS_PORT
read -e -p "Utilisateur : " -i "debian" VPS_USER

echo ""
echo "VPS configuré : $VPS_USER@$VPS_IP:$VPS_PORT"

# Test de connexion initiale
echo ""
echo "Test de connexion initial..."
echo "ATTENTION: Si c'est un nouveau VPS OVH, il peut demander de changer le mot de passe"
echo "lors de la première connexion. C'est normal, définissez un nouveau mot de passe."
echo ""

# Nettoyer l'ancienne clé SSH si elle existe (utile pour les réinstallations VPS)
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$VPS_IP" 2>/dev/null || true

# Test avec gestion du changement de mot de passe forcé
if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -p $VPS_PORT $VPS_USER@$VPS_IP "echo 'Connexion OK'" 2>/dev/null; then
    echo "✓ Connexion par clé SSH réussie"
elif ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $VPS_PORT $VPS_USER@$VPS_IP "echo 'Connexion OK'" 2>&1 | grep -q "You are required to change your password"; then
    echo "⚠️  Changement de mot de passe requis par OVH détecté"
    echo "Vous devez vous connecter manuellement UNE FOIS pour changer le mot de passe"
    echo ""
    echo "Étapes à suivre :"
    echo "1. Connectez-vous manuellement: ssh -p $VPS_PORT $VPS_USER@$VPS_IP"
    echo "2. Définissez un nouveau mot de passe quand demandé"
    echo "3. Tapez 'exit' pour fermer la connexion"
    echo "4. Relancez ce script install-vps.sh"
    echo ""
    ssh -o StrictHostKeyChecking=no -p $VPS_PORT $VPS_USER@$VPS_IP
    exit 1
elif ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p $VPS_PORT $VPS_USER@$VPS_IP "echo 'Connexion OK'"; then
    echo "❌ Erreur : Impossible de se connecter au VPS"
    echo "Vérifiez :"
    echo "- L'IP du VPS : $VPS_IP"
    echo "- Le port SSH : $VPS_PORT"  
    echo "- L'utilisateur : $VPS_USER"
    echo "- Le mot de passe/clé SSH"
    exit 1
else
    echo "✓ Connexion réussie"
fi

# Gestion des clés SSH (optionnelle)
echo ""
echo "Configuration des clés SSH (recommandé pour éviter les mots de passe)"

while true; do
    echo -n "Voulez-vous configurer une clé SSH ? [o/N]: "
    read -n1 SETUP_SSH
    echo  # Aller à la ligne
    
    case $SETUP_SSH in
        [OoYy] ) 
            SETUP_SSH="o"
            break
            ;;
        [Nn] ) 
            SETUP_SSH="n"
            break
            ;;
        "" ) 
            # Touche Entrée = défaut (non)
            SETUP_SSH="n"
            break
            ;;
        * ) 
            echo "Répondez SEULEMENT par 'o' pour oui ou 'n' pour non."
            ;;
    esac
done

if [[ $SETUP_SSH == "o" ]]; then
    # Recherche des clés SSH disponibles
    SSH_KEYS=($(find ~/.ssh -name "*.pub" 2>/dev/null | sort))
    
    if [ ${#SSH_KEYS[@]} -eq 0 ]; then
        echo "Aucune clé SSH publique trouvée dans ~/.ssh/"
        echo "Générez d'abord une clé avec : ssh-keygen -t rsa -b 4096"
        exit 1
    fi
    
    echo ""
    echo "Clés SSH disponibles :"
    for i in "${!SSH_KEYS[@]}"; do
        echo "  $((i+1)). ${SSH_KEYS[$i]}"
    done
    
    echo "  0. Annuler"
    echo ""
    
    while true; do
        echo -n "Choisissez votre clé (1-${#SSH_KEYS[@]}, 0=Annuler): "
        read -n1 KEY_CHOICE
        echo  # Aller à la ligne
        
        # Vérifier que c'est un chiffre valide
        if [[ $KEY_CHOICE =~ ^[0-9]$ ]]; then
            if [[ $KEY_CHOICE -eq 0 ]]; then
                echo "Configuration SSH annulée"
                break
            elif [[ $KEY_CHOICE -ge 1 && $KEY_CHOICE -le ${#SSH_KEYS[@]} ]]; then
            SELECTED_KEY="${SSH_KEYS[$((KEY_CHOICE-1))]}"
            echo ""
            echo "Clé sélectionnée : $SELECTED_KEY"
            
            # Installation de la clé SSH
            echo "Installation de la clé SSH sur le VPS..."
            if ssh-copy-id -i "$SELECTED_KEY" -p $VPS_PORT $VPS_USER@$VPS_IP; then
                echo "Clé SSH installée avec succès"
                
                # Test de connexion sans mot de passe
                echo ""
                echo "Test de connexion sans mot de passe..."
                if ssh -o PasswordAuthentication=no -p $VPS_PORT $VPS_USER@$VPS_IP "echo 'Connexion SSH sans mot de passe : OK'"; then
                    echo "Configuration SSH réussie !"
                else
                    echo "Connexion par clé installée mais mot de passe encore demandé"
                fi
            else
                echo "Erreur lors de l'installation de la clé SSH"
                exit 1
            fi
            break
            else
                echo "Appuyez sur un chiffre entre 0 et ${#SSH_KEYS[@]} SEULEMENT"
            fi
        else
            echo "Appuyez sur un CHIFFRE entre 0 et ${#SSH_KEYS[@]} SEULEMENT"
        fi
    done
fi

# Connexion finale et informations
echo ""
echo "Configuration terminée !"
echo "=============================================="
echo "Commande de connexion :"
echo "  ssh -p $VPS_PORT $VPS_USER@$VPS_IP"
echo ""
# Proposition d'installation automatique
echo ""
echo "PROCHAINES ÉTAPES À RÉALISER SUR LE VPS :"
echo "  Téléchargement et exécution du script d'installation"
echo ""

# Options d'installation
echo "Options d'installation :"
echo "  1. Installation automatique (recommandé)"
echo "  2. Connexion manuelle au VPS"
echo "  0. Quitter"
echo ""

while true; do
    echo -n "Choisissez une option (0-2): "
    read -n1 INSTALL_CHOICE
    echo  # Aller à la ligne
    
    # Vérifier que c'est un chiffre valide entre 0 et 2
    if [[ $INSTALL_CHOICE =~ ^[0-2]$ ]]; then
        case $INSTALL_CHOICE in
        1)
            echo ""
            echo "Installation automatique en cours..."
            echo "=============================================="
            
            # Copier les fichiers locaux vers le VPS au lieu de télécharger depuis GitHub
            echo "Copie des fichiers locaux vers le VPS..."
            
            # Vérifier que les fichiers locaux existent
            if [[ ! -f "$SETUP_SCRIPT" ]]; then
                echo "ERREUR: Le fichier $SETUP_SCRIPT n'existe pas localement"
                exit 1
            fi
            
            # Créer la structure sur le VPS
            ssh -p $VPS_PORT $VPS_USER@$VPS_IP "mkdir -p templates/$TEMPLATE_NAME scripts/$TEMPLATE_NAME"
            
            # Copier le script principal avec écrasement forcé
            echo "Copie du script principal (écrasement forcé)..."
            scp -P $VPS_PORT "$SETUP_SCRIPT" $VPS_USER@$VPS_IP:~/
            
            # Copier les templates avec écrasement forcé
            echo "Copie des templates..."
            scp -P $VPS_PORT templates/$TEMPLATE_NAME/* $VPS_USER@$VPS_IP:~/templates/$TEMPLATE_NAME/
            
            # Copier le thème Webmin vers le home puis le déplacer vers /
            echo "Copie du thème Webmin MSC..."
            scp -P $VPS_PORT templates/$TEMPLATE_NAME/webmin-theme-msc.wbt.gz $VPS_USER@$VPS_IP:~/
            
            # Copier les scripts avec écrasement forcé
            echo "Copie des scripts de gestion..."
            scp -P $VPS_PORT scripts/$TEMPLATE_NAME/* $VPS_USER@$VPS_IP:~/scripts/$TEMPLATE_NAME/
            
            # Exécuter sur le VPS avec confirmation de la version
            if ssh -t -p $VPS_PORT $VPS_USER@$VPS_IP "
                chmod +x $(basename "$SETUP_SCRIPT")
                chmod +x scripts/$TEMPLATE_NAME/vhost-manager.sh
                
                # Déplacer le thème Webmin vers / avec sudo
                sudo mv ~/webmin-theme-msc.wbt.gz /webmin-theme-msc.wbt.gz
                sudo chown root:root /webmin-theme-msc.wbt.gz
                echo 'Thème Webmin déplacé vers /webmin-theme-msc.wbt.gz'
                
                echo 'Fichiers copiés et permissions définies avec succès'
                echo ''
                echo 'Lancement de l'\''installation automatique...'
                echo '=============================================='
                
                # Supprimer l'ancien script s'il existe
                rm -f $(basename "$SETUP_SCRIPT").bak 2>/dev/null || true
                
                sudo ./$(basename "$SETUP_SCRIPT")
            "; then
                echo ""
                echo "Nettoyage des fichiers temporaires..."
                ssh -p $VPS_PORT $VPS_USER@$VPS_IP "
                    # Supprimer les fichiers et dossiers copiés temporairement
                    rm -f ~/setup.sh
                    rm -rf ~/templates
                    rm -rf ~/scripts
                    echo 'Fichiers temporaires supprimés avec succès'
                "
                
                echo ""
                echo "Installation terminée avec succès !"
                echo "=============================================="
                echo "Votre VPS est maintenant configuré et sécurisé."
                echo ""
                echo "Commande de connexion :"
                echo "  ssh -p [PORT_SSH_CONFIGURÉ] $VPS_USER@$VPS_IP"
                echo ""
                echo "IMPORTANT: Utilisez le port SSH que vous avez configuré"
                echo "pendant l'installation (affiché dans le résumé final)"
            else
                echo ""
                echo "Erreur lors de l'installation automatique"
                echo "Vous pouvez essayer l'installation manuelle (option 2)"
            fi
            break
            ;;
        2)
            echo ""
            echo "Instructions pour installation manuelle :"
            echo "=============================================="
            echo "1. Connectez-vous au VPS :"
            echo "   ssh -p $VPS_PORT $VPS_USER@$VPS_IP"
            echo ""
            echo "2. Copiez manuellement vos fichiers locaux vers le VPS"
            echo ""
            echo "Connexion au VPS..."
            ssh -p $VPS_PORT $VPS_USER@$VPS_IP
            break
            ;;
        0)
            echo ""
            echo "Configuration terminée. À bientôt !"
            break
            ;;
        esac
    else
        echo "Appuyez sur un CHIFFRE entre 0 et 2 SEULEMENT"
    fi
done