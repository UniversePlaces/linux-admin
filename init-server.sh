#!/bin/bash

set -e

NEW_USER="user"
SSH_PORT="2222"
DOCKER_COMPOSE_VERSION="2.24.0"
TEMP_PASSWORD="changeme"

echo "=== Aktualizacja systemu ==="
export DEBIAN_FRONTEND=noninteractive
apt update && apt full-upgrade -y

echo "=== Instalacja podstawowych narzędzi ==="
apt install -y \
  curl wget git unzip ufw \
  htop net-tools software-properties-common \
  ca-certificates gnupg lsb-release \
  fail2ban chrony unattended-upgrades

echo "=== Konfiguracja użytkownika ==="
if id "$NEW_USER" &>/dev/null; then
  echo "Użytkownik $NEW_USER już istnieje, pomijam dodawanie..."
else
  echo "=== Dodawanie użytkownika '$NEW_USER' ==="
  adduser --disabled-password --gecos "" "$NEW_USER"
  echo "$NEW_USER:$TEMP_PASSWORD" | chpasswd
  chage -M 99999 "$NEW_USER"   # Hasło nigdy nie wygasa
  chage -d 0 "$NEW_USER"       # Wymusza zmianę hasła przy pierwszym logowaniu
  usermod -aG sudo "$NEW_USER"
  echo "Ustawiono tymczasowe hasło: $TEMP_PASSWORD"
fi

echo "=== Konfiguracja sudo ==="
# Dodaj użytkownika do grupy sudo jeśli jeszcze nie jest
usermod -aG sudo "$NEW_USER"

echo "=== Konfiguracja SSH ==="
ROOT_SSH_DIR="/root/.ssh"
USER_SSH_DIR="/home/$NEW_USER/.ssh"

if [ -f "$ROOT_SSH_DIR/authorized_keys" ]; then
  mkdir -p "$USER_SSH_DIR"
  cp "$ROOT_SSH_DIR/authorized_keys" "$USER_SSH_DIR/authorized_keys"
  chown -R $NEW_USER:$NEW_USER "$USER_SSH_DIR"
  chmod 700 "$USER_SSH_DIR"
  chmod 600 "$USER_SSH_DIR/authorized_keys"
  echo "Skopiowano klucz SSH z root do $NEW_USER"
else
  echo "Nie znaleziono pliku authorized_keys root, pomijam kopiowanie kluczy SSH"
fi

echo "=== Konfiguracja SSH ==="
CURRENT_PORT=$(grep "^Port " /etc/ssh/sshd_config || echo "")
if [ "$CURRENT_PORT" != "Port $SSH_PORT" ]; then
  sed -i "s/^#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config || echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
  sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config || echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
  echo "Ustawiono port SSH na $SSH_PORT"
else
  echo "Port SSH jest już ustawiony na $SSH_PORT"
fi

if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
  echo "Root login przez SSH jest już zablokowany"
else
  sed -i "s/^PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config
  echo "Zablokowano root login przez SSH"
fi

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
  echo "Logowanie hasłem SSH jest już zablokowane"
else
  sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
  echo "Zablokowano logowanie hasłem SSH"
fi

echo "Restartuję SSH..."
systemctl restart ssh

echo "=== Konfiguracja Fail2Ban ==="
cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF

systemctl restart fail2ban

echo "=== Instalacja Dockera ==="
if command -v docker &>/dev/null; then
  echo "Docker jest już zainstalowany"
else
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "Docker zainstalowany"
fi

if groups $NEW_USER | grep &>/dev/null '\bdocker\b'; then
  echo "Użytkownik $NEW_USER już jest w grupie docker"
else
  usermod -aG docker $NEW_USER
  echo "Dodano użytkownika $NEW_USER do grupy docker"
fi

echo "=== Włączenie Dockera przy starcie systemu ==="
systemctl enable docker
systemctl start docker

echo "=== Instalacja docker-compose CLI ==="
if command -v docker-compose &>/dev/null; then
  INSTALLED_VERSION=$(docker-compose --version | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
  if [ "$INSTALLED_VERSION" == "$DOCKER_COMPOSE_VERSION" ]; then
    echo "docker-compose w wersji $DOCKER_COMPOSE_VERSION już jest zainstalowany"
  else
    echo "Inna wersja docker-compose ($INSTALLED_VERSION) jest zainstalowana, aktualizuję..."
    curl -SL "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi
else
  curl -SL "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  echo "docker-compose zainstalowany"
fi

echo "=== Konfiguracja zapory UFW ==="
ufw_status=$(ufw status | head -n 1)
if [[ "$ufw_status" == "Status: inactive" ]]; then
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow $SSH_PORT/tcp
  ufw allow 80,443/tcp
  ufw --force enable
  echo "UFW skonfigurowany i włączony"
else
  echo "UFW jest już aktywny, sprawdzam reguły..."
  ufw allow $SSH_PORT/tcp || true
  ufw allow 80,443/tcp || true
fi

echo "=== Automatyczne aktualizacje ==="
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "true";
EOF

echo "=== Synchronizacja czasu ==="
timedatectl set-ntp true
systemctl restart chrony

echo "=== Konfiguracja MOTD ==="
cat <<'EOF' > /etc/update-motd.d/01-custom
#!/bin/bash
echo ""
echo "██████╗  █████╗ ███████╗███████╗██╗   ██╗███████╗██████╗ "
echo "██╔══██╗██╔══██╗██╔════╝██╔════╝██║   ██║██╔════╝██╔══██╗"
echo "██████╔╝███████║███████╗███████╗██║   ██║█████╗  ██████╔╝"
echo "██╔═══╝ ██╔══██║╚════██║╚════██║██║   ██║██╔══╝  ██╔══██╗"
echo "██║     ██║  ██║███████║███████║╚██████╔╝███████╗██║  ██║"
echo "╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝"
echo ""
echo "---------------------------------------------"
echo " Serwer:     $(hostname)"
echo " Użytkownik: $(logname)"
echo " Data:       $(date)"
echo " Uptime:     $(uptime -p)"
echo " Obciążenie: $(cut -d ' ' -f1-3 /proc/loadavg)"
echo "---------------------------------------------"
EOF

chmod +x /etc/update-motd.d/01-custom

systemctl restart ssh

echo "=== Zakończono konfigurację! ==="
IP=$(hostname -I | awk '{print $1}')
echo "Dane dostępu:"
echo "SSH: ssh -p $SSH_PORT $NEW_USER@$IP"
echo "Hasło tymczasowe: $TEMP_PASSWORD (wymagana zmiana!)"
