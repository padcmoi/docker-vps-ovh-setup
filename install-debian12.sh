# Installation

## Common
sudo apt update
sudo apt install -y wget apt-transport-https software-properties-common

## Webmin
wget -qO - http://www.webmin.com/jcameron-key.asc | sudo apt-key add -
echo "deb http://download.webmin.com/download/repository sarge contrib" | sudo tee -a /etc/apt/sources.list

sudo apt update
sudo apt install -y webmin

cat <<EOF | sudo tee /etc/webmin/miniserv.conf
port=51235
root=/usr/share/webmin
mimetypes=/usr/share/webmin/mime.types
addtype_cgi=internal/cgi
realm=Webmin Server
logfile=/var/webmin/miniserv.log
errorlog=/var/webmin/miniserv.error
pidfile=/var/webmin/miniserv.pid
logtime=168
ssl=0
no_ssl2=1
no_ssl3=1
ssl_honorcipherorder=0
no_sslcompression=1
env_WEBMIN_CONFIG=/etc/webmin
env_WEBMIN_VAR=/var/webmin
atboot=1
logout=/etc/webmin/logout-flag
listen=51235
denyfile=\.pl$
log=1
blockhost_failures=5
blockhost_time=60
syslog=1
ipv6=1
session=1
premodules=WebminCore
server=MiniServ/2.501
userfile=/etc/webmin/miniserv.users
keyfile=/etc/webmin/miniserv.pem
logclear=1
ssl_hsts=0
ssl_enforce=0
passwd_file=/etc/shadow
passwd_uindex=0
passwd_pindex=1
passwd_cindex=2
passwd_mindex=4
passwd_mode=0
preroot=mscstyle3
passdelay=1
failed_script=/etc/webmin/failed.pl
login_script=/etc/webmin/login.pl
logout_script=/etc/webmin/logout.pl
cipher_list_def=1
no_trust_ssl=1
sudo=1
error_handler_404=
error_handler_401=
error_handler_403=
logouttimes=
certfile=
extracas=
no_tls1_2=
no_tls1=
no_tls1_1=
no_testing_cookie=1
EOF

sudo systemctl restart webmin

## Retire eventuellement Exim4 qui peut rentrer en conflit avec d'autres services
sudo apt purge exim4 exim4-base exim4-config exim4-daemon-light -y
sudo apt autoremove --purge -y

## SSH
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%F-%H%M)
sudo sed -i 's/^Port /#Port /' /etc/ssh/sshd_config
echo "Port 51234" | sudo tee -a /etc/ssh/sshd_config
echo "AllowUsers root debian" | sudo tee -a /etc/ssh/sshd_config
sudo sshd -t
sudo systemctl restart ssh
sudo ss -tlnp | grep sshd

## Fail2ban
sudo apt install -y fail2ban

cat <<EOF | sudo tee /etc/fail2ban/jail.local
[sshd]
enabled = true
port = 51234
backend = systemd
maxretry = 5
bantime = 3600
EOF

sudo systemctl restart fail2ban
sudo systemctl enable fail2ban
