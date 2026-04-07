#!/usr/bin/env bash
# Gestion interactive des vhosts nginx avec whiptail TUI
set -euo pipefail

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
VHOST_MANAGER_ENV_FILE="/etc/vhost-manager.env"

ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être lancé avec sudo ou root"
    exit 1
  fi
}

list_vhosts_raw() {
  for f in "$SITES_AVAILABLE"/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
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

confirm_yesno_default_no() {
  whiptail --defaultno --yesno "$1" 8 70
}

load_letsencrypt_email() {
  local email="${LETSENCRYPT_EMAIL:-}"

  if [ -z "$email" ] && [ -f "$VHOST_MANAGER_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    . "$VHOST_MANAGER_ENV_FILE"
    email="${LETSENCRYPT_EMAIL:-}"
  fi

  if [ -z "$email" ]; then
    email=$(grep -Rho 'mailto:[^"]*' /etc/letsencrypt/accounts 2>/dev/null | head -n 1 | sed 's/^mailto://' || true)
  fi

  echo "$email"
}

cert_covers_domain() {
  local cert_file="$1"
  local domain="$2"

  [ -f "$cert_file" ] || return 1

  openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null \
    | tr -d ' ' \
    | grep -q "DNS:$domain"
}

add_or_update_vhost() {
  local pre_domain="$1"
  local pre_target="$2"

  DOMAIN=$(prompt_input "Nom de domaine (ex: example.com):" "$pre_domain")
  TARGET=$(prompt_input "Backend (ex: http://127.0.0.1:8888):" "$pre_target")
  DOMAIN="${DOMAIN,,}"

  if ! [[ "$DOMAIN" =~ ^[a-z0-9.-]+$ ]] || [[ "$DOMAIN" != *.* ]]; then
    whiptail --msgbox "Nom de domaine invalide: $DOMAIN" 8 70
    return 1
  fi

  SSL_CHOICE=$(whiptail --title "Mode SSL" --menu "Choisir mode HTTPS" 15 60 4 \
    "1" "Let's Encrypt certonly" \
    "2" "Certificat personnalisé" \
    "3" "Pas de SSL" 3>&1 1>&2 2>&3)

  CERT_PATH=""
  KEY_PATH=""

  if [ "$SSL_CHOICE" = "1" ]; then
    # Si un certificat existe déjà pour ce domaine, on le réutilise.
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] \
      && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ] \
      && cert_covers_domain "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$DOMAIN"; then
      CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
      KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
      whiptail --msgbox "Certificat Let's Encrypt existant détecté pour $DOMAIN.\nRéutilisation du certificat actuel." 10 78
    else
      if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && ! cert_covers_domain "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$DOMAIN"; then
        whiptail --msgbox "Le certificat existant ne couvre pas $DOMAIN.\nRéémission d'un certificat correct..." 10 78
      fi

      EMAIL=$(load_letsencrypt_email)
      CERTBOT_ARGS=(
        certonly
        --standalone
        --agree-tos
        --non-interactive
        --force-renewal
        --cert-name "$DOMAIN"
        -d "$DOMAIN"
      )

      # Sur les sous-domaines, www.<sous-domaine> n'existe souvent pas.
      if [[ "$DOMAIN" != www.* ]] && confirm_yesno_default_no "Inclure aussi www.$DOMAIN dans le certificat ?"; then
        CERTBOT_ARGS+=(--expand -d "www.$DOMAIN")
      fi

      if [ -n "$EMAIL" ]; then
        CERTBOT_ARGS+=(-m "$EMAIL")
      else
        CERTBOT_ARGS+=(--register-unsafely-without-email)
      fi

      systemctl stop nginx || true
      if ! CERTBOT_OUTPUT=$(certbot "${CERTBOT_ARGS[@]}" 2>&1); then
        systemctl start nginx || true
        LAST_ERROR=$(printf '%s\n' "$CERTBOT_OUTPUT" | tail -n 12)
        whiptail --msgbox "Erreur Certbot:\n\n$LAST_ERROR\n\nLog complet: /var/log/letsencrypt/letsencrypt.log" 22 100
        return 1
      fi
      systemctl start nginx
      CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
      KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    fi
  elif [ "$SSL_CHOICE" = "2" ]; then
    CERT_PATH=$(prompt_input "Chemin fullchain.pem:" "")
    KEY_PATH=$(prompt_input "Chemin privkey.pem:" "")
  fi

  FORCE_REDIRECT="no"
  FORCE_REDIRECT="yes"
  confirm_yesno "Forcer HTTP -> HTTPS ?" || FORCE_REDIRECT="no"

  CONF="$SITES_AVAILABLE/$DOMAIN"

  if [ "$SSL_CHOICE" = "3" ]; then
    # HTTP uniquement
    cat >"$CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    location / {
        proxy_pass $TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
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
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
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
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;
    ssl_certificate $CERT_PATH;
    ssl_certificate_key $KEY_PATH;
    location / {
        proxy_pass $TARGET;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port 443;
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
      "1" "Lister / voir vhost" \
      "2" "Ajouter vhost" \
      "3" "Modifier vhost" \
      "4" "Supprimer vhost" \
      "5" "Activer / Désactiver vhost" \
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
