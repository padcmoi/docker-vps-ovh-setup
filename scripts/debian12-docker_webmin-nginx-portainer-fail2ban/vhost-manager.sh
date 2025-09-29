#!/usr/bin/env bash
# Gestion interactive des vhosts nginx avec whiptail TUI
set -euo pipefail

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être lancé avec sudo ou root"
    exit 1
  fi
}

list_vhosts_raw() {
  local files=("$SITES_AVAILABLE"/*)
  for f in "${files[@]}"; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    [ "$name" = "default" ] && continue  # Ignorer le vhost par défaut
    status="DISABLED"
    [ -L "$SITES_ENABLED/$name" ] && status="ENABLED"
    echo "$name|$status"
  done
}

list_vhosts_menu() {
  local menu_items=()
  while IFS='|' read -r name status; do
    menu_items+=("$name" "$status")
  done < <(list_vhosts_raw)
  [ ${#menu_items[@]} -eq 0 ] && { whiptail --msgbox "Aucun vhost trouvé" 8 50; return 1; }
  whiptail --title "Vhosts disponibles" --menu "Sélectionner un vhost" 20 70 12 "${menu_items[@]}" 3>&1 1>&2 2>&3
}

prompt_input() {
  local prompt="$1" default="$2"
  whiptail --inputbox "$prompt" 10 70 "$default" 3>&1 1>&2 2>&3
}

confirm_yesno() {
  whiptail --yesno "$1" 8 60
}

add_or_update_vhost() {
  local pre_domain="$1"
  local pre_target="$2"

  DOMAIN=$(prompt_input "Nom de domaine (ex: example.com):" "$pre_domain")
  TARGET=$(prompt_input "Backend (ex: http://127.0.0.1:8888):" "$pre_target")
  
  SSL_CHOICE=$(whiptail --title "Mode SSL" --menu "Choisir mode HTTPS" 15 60 4 \
    "1" "Let's Encrypt certonly" \
    "2" "Certificat personnalisé" \
    "3" "Pas de SSL" 3>&1 1>&2 2>&3)

  CERT_PATH=""
  KEY_PATH=""

  if [ "$SSL_CHOICE" = "1" ]; then
    # Variables pour cleanup en cas d'erreur
    CONF="$SITES_AVAILABLE/$DOMAIN"
    TEMP_VHOST_CREATED="no"
    
    # Créer un vhost temporaire HTTP pour la validation
    echo "Création du vhost temporaire pour validation SSL..."
    cat >"$CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_pass $TARGET;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # Activer le vhost temporaire
    if ln -sf "$CONF" "$SITES_ENABLED/$DOMAIN" && nginx -t && systemctl reload nginx; then
      TEMP_VHOST_CREATED="yes"
      echo "✅ Vhost temporaire créé et Nginx rechargé"
    else
      echo "❌ ERREUR: Impossible de créer le vhost temporaire"
      echo "Nginx pourrait avoir un problème de configuration"
      rm -f "$CONF" 2>/dev/null
      whiptail --msgbox "Erreur lors de la création du vhost temporaire.\nVérifiez la configuration Nginx." 10 60
      return 1
    fi
    
    # Tenter d'obtenir le certificat SSL
    echo "Tentative d'obtention du certificat SSL..."
      CERTBOT_CMD="certbot certonly --webroot -w /var/www/html --agree-tos --non-interactive --register-unsafely-without-email -d \"$DOMAIN\""
      if certbot certonly --webroot -w /var/www/html --agree-tos --non-interactive --register-unsafely-without-email -d "$DOMAIN"; then
        echo "✅ Certificat SSL obtenu avec succès !"
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
        KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
      else
        echo ""
        echo "❌ ÉCHEC: Impossible d'obtenir le certificat SSL"
        echo ""
        echo "🔍 DIAGNOSTIC :"
        echo "• Commande échouée: $CERTBOT_CMD"
        echo "• Vérifiez que $DOMAIN pointe vers cette IP: $(curl -s ifconfig.me 2>/dev/null || echo 'inconnue')"
        echo "• Vérifiez le DNS: dig $DOMAIN A"
        echo ""
        echo "🛠️  SOLUTIONS :"
        echo "1. Corrigez votre DNS puis relancez ce script"
        echo "2. Ou tapez manuellement: $CERTBOT_CMD"
        echo "3. Puis relancez ce script (il détectera le certificat existant)"
        echo ""
        echo "🧹 NETTOYAGE: Suppression du vhost temporaire..."
        
        # Nettoyage complet
        rm -f "$SITES_ENABLED/$DOMAIN" 2>/dev/null
        rm -f "$CONF" 2>/dev/null
        if nginx -t && systemctl reload nginx; then
          echo "✅ Nginx nettoyé et rechargé avec succès"
        else
          echo "⚠️  Attention: Problème lors du rechargement de Nginx"
        fi
        
        whiptail --msgbox "Échec SSL: vhost supprimé, Nginx intact.\nVoir les solutions dans le terminal." 12 70
        return 1
      fi
    
  elif [ "$SSL_CHOICE" = "2" ]; then
    CERT_PATH=$(prompt_input "Chemin fullchain.pem:" "")
    KEY_PATH=$(prompt_input "Chemin privkey.pem:" "")
  fi

  FORCE_REDIRECT="no"
  confirm_yesno "Forcer HTTP -> HTTPS ?" && FORCE_REDIRECT="yes"

  CONF="$SITES_AVAILABLE/$DOMAIN"

  if [ "$SSL_CHOICE" = "3" ]; then
    # HTTP uniquement
    cat >"$CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location / {
        proxy_pass $TARGET;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
  else
    if [ "$FORCE_REDIRECT" = "yes" ]; then
      cat >"$CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;
    ssl_certificate $CERT_PATH;
    ssl_certificate_key $KEY_PATH;
    location / {
        proxy_pass $TARGET;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    else
      cat >"$CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location / {
        proxy_pass $TARGET;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;
    ssl_certificate $CERT_PATH;
    ssl_certificate_key $KEY_PATH;
    location / {
        proxy_pass $TARGET;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    fi
  fi

  ln -sf "$CONF" "$SITES_ENABLED/$DOMAIN"
  nginx -t && systemctl reload nginx
  whiptail --msgbox "Vhost $DOMAIN créé/mis à jour." 8 50
}

main_menu() {
  ensure_root
  while true; do
    CHOICE=$(whiptail --title "Vhost Manager" --menu "Naviguer avec flèches" 20 70 10 \
      "1" "Lister" \
      "2" "Ajouter" \
      "3" "Modifier" \
      "4" "Supprimer" \
      "5" "Activer/Desactiver" \
      "6" "Quitter" 3>&1 1>&2 2>&3)
    case "$CHOICE" in
      "1") sel=$(list_vhosts_menu) && whiptail --textbox "$SITES_AVAILABLE/$sel" 30 100 ;;
      "2") add_or_update_vhost "" "" ;;
      "3") sel=$(list_vhosts_menu) && rm -f "$SITES_AVAILABLE/$sel" "$SITES_ENABLED/$sel" && add_or_update_vhost "$sel" "" ;;
      "4") sel=$(list_vhosts_menu) && rm -f "$SITES_AVAILABLE/$sel" "$SITES_ENABLED/$sel" && nginx -t && systemctl reload nginx ;;
      "5") sel=$(list_vhosts_menu) && [ -L "$SITES_ENABLED/$sel" ] && rm -f "$SITES_ENABLED/$sel" || ln -sf "$SITES_AVAILABLE/$sel" "$SITES_ENABLED/$sel" && nginx -t && systemctl reload nginx ;;
      "6") exit 0 ;;
    esac
  done
}

main_menu
