#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "                DEPLOY AUTOMATIZADO DRIVE"
echo "============================================================"
echo

if [[ $EUID -ne 0 ]]; then
  echo "Execute este script como root."
  exit 1
fi

command -v dnf >/dev/null 2>&1 || { echo "dnf nao encontrado."; exit 1; }
command -v firewall-cmd >/dev/null 2>&1 || { echo "firewalld nao encontrado."; exit 1; }
command -v lsblk >/dev/null 2>&1 || { echo "lsblk nao encontrado."; exit 1; }
command -v awk >/dev/null 2>&1 || { echo "awk nao encontrado."; exit 1; }
command -v grep >/dev/null 2>&1 || { echo "grep nao encontrado."; exit 1; }
command -v sed >/dev/null 2>&1 || { echo "sed nao encontrado."; exit 1; }
command -v tr >/dev/null 2>&1 || { echo "tr nao encontrado."; exit 1; }

print_line() {
  printf '%*s\n' "${COLUMNS:-60}" '' | tr ' ' '='
}

trim() {
  local var="$1"
  var="${var#"${var%%[![:space:]]*}"}"
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

validar_nao_vazio() {
  [[ -n "$(trim "$1")" ]]
}

validar_ip() {
  local ip="$1"
  local IFS=.
  local -a octetos

  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  read -r -a octetos <<< "$ip"
  [[ ${#octetos[@]} -eq 4 ]] || return 1

  for octeto in "${octetos[@]}"; do
    [[ "$octeto" =~ ^[0-9]{1,3}$ ]] || return 1
    (( octeto >= 0 && octeto <= 255 )) || return 1
  done

  return 0
}

validar_fqdn() {
  local fqdn="$1"

  [[ ${#fqdn} -le 253 ]] || return 1
  [[ "$fqdn" =~ ^[A-Za-z0-9.-]+$ ]] || return 1
  [[ "$fqdn" == *.* ]] || return 1
  [[ "$fqdn" != .* ]] || return 1
  [[ "$fqdn" != -* ]] || return 1
  [[ "$fqdn" != *- ]] || return 1
  [[ "$fqdn" != *..* ]] || return 1

  return 0
}

validar_nome_simples() {
  local valor="$1"
  [[ "$valor" =~ ^[A-Za-z0-9._-]+$ ]]
}

validar_inteiro_intervalo() {
  local valor="$1"
  local min="$2"
  local max="$3"

  [[ "$valor" =~ ^[0-9]+$ ]] || return 1
  (( valor >= min && valor <= max ))
}

validar_sn() {
  [[ "$1" =~ ^[sSnN]$ ]]
}

ler_texto_obrigatorio() {
  local label="$1"
  local valor

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r valor
    valor="$(trim "$valor")"

    if validar_nao_vazio "$valor"; then
      REPLY="$valor"
      return 0
    fi

    echo "Valor nao pode ser vazio."
  done
}

ler_nome_simples_obrigatorio() {
  local label="$1"
  local valor

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r valor
    valor="$(trim "$valor")"

    if ! validar_nao_vazio "$valor"; then
      echo "Valor nao pode ser vazio."
      continue
    fi

    if ! validar_nome_simples "$valor"; then
      echo "Use apenas letras, numeros, ponto, underline ou hifen."
      continue
    fi

    REPLY="$valor"
    return 0
  done
}

ler_ip_obrigatorio() {
  local label="$1"
  local valor

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r valor
    valor="$(trim "$valor")"

    if ! validar_ip "$valor"; then
      echo "IP invalido. Exemplo: 10.1.1.210"
      continue
    fi

    REPLY="$valor"
    return 0
  done
}

ler_fqdn_obrigatorio() {
  local label="$1"
  local valor

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r valor
    valor="$(trim "$valor")"

    if ! validar_fqdn "$valor"; then
      echo "FQDN invalido. Exemplo: drive.stratum7.com.br"
      continue
    fi

    REPLY="$valor"
    return 0
  done
}

ler_inteiro_intervalo_obrigatorio() {
  local label="$1"
  local min="$2"
  local max="$3"
  local valor

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r valor
    valor="$(trim "$valor")"

    if ! validar_inteiro_intervalo "$valor" "$min" "$max"; then
      echo "Informe um numero inteiro entre $min e $max."
      continue
    fi

    REPLY="$valor"
    return 0
  done
}

ler_sn_obrigatorio() {
  local label="$1"
  local valor

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r valor
    valor="$(trim "$valor")"

    if ! validar_sn "$valor"; then
      echo "Informe apenas s ou n."
      continue
    fi

    REPLY="${valor,,}"
    return 0
  done
}

ler_senha_obrigatoria() {
  local label="$1"
  local senha1
  local senha2

  while true; do
    printf "%-42s: " "$label"
    IFS= read -r -s senha1
    echo

    senha1="$(trim "$senha1")"
    if ! validar_nao_vazio "$senha1"; then
      echo "Senha nao pode ser vazia."
      continue
    fi

    printf "%-42s: " "Confirme $label"
    IFS= read -r -s senha2
    echo

    if [[ "$senha1" != "$senha2" ]]; then
      echo "As senhas nao conferem."
      continue
    fi

    REPLY="$senha1"
    return 0
  done
}

echo "CONFIGURACAO INICIAL"
print_line

ler_ip_obrigatorio "IP do servidor (HOST_IP)"
HOST_IP="$REPLY"

ler_texto_obrigatorio "Host do banco de dados (DB_HOST)"
DB_HOST="$REPLY"

ler_nome_simples_obrigatorio "Nome do banco de dados (DB_NAME)"
DB_NAME="$REPLY"

ler_nome_simples_obrigatorio "Usuario do banco de dados (DB_USER)"
DB_USER="$REPLY"

ler_senha_obrigatoria "Senha do banco de dados (DB_PASS)"
DB_PASS="$REPLY"

ler_nome_simples_obrigatorio "Usuario administrador do Nextcloud (ADMIN_USER)"
ADMIN_USER="$REPLY"

ler_senha_obrigatoria "Senha do administrador do Nextcloud (ADMIN_PASS)"
ADMIN_PASS="$REPLY"

ler_fqdn_obrigatorio "FQDN do Nextcloud (FQDN)"
FQDN="$REPLY"

ler_inteiro_intervalo_obrigatorio "SERVERID (inteiro de 0 a 1023)" 0 1023
SERVERID="$REPLY"

ler_sn_obrigatorio "Deseja adicionar e formatar novo HD? (s/n)"
ADICIONAR_HD="$REPLY"

MONTAGEM="/var/www/html/StorageData-01"

if [[ "$ADICIONAR_HD" == "s" ]]; then
  MONTAGEM="/mnt/LOCAL/StorageData-01"
  echo
  echo "DETECCAO DE DISCO"
  print_line
  echo "Detectando discos sem particao..."

  DISCOS_LIMPOS=$(
    lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | while read -r DEVICE; do
      PARTS=$(lsblk -n "$DEVICE" -o NAME | wc -l)
      if [[ "$PARTS" -eq 1 ]]; then
        echo "$DEVICE"
      fi
    done
  )

  if [[ -z "${DISCOS_LIMPOS}" ]]; then
    echo "Nenhum disco limpo encontrado. Usando diretorio local padrao."
    MONTAGEM="/var/www/html/StorageData-01"
  else
    echo "Discos limpos detectados:"
    echo "$DISCOS_LIMPOS"
    DISCO=$(echo "$DISCOS_LIMPOS" | head -n1)
    echo
    ler_sn_obrigatorio "Formatar e montar o disco $DISCO em $MONTAGEM? (s/n)"
    CONFIRMA="$REPLY"

    if [[ "$CONFIRMA" == "s" ]]; then
      umount "${DISCO}"* 2>/dev/null || true
      echo "Formatando $DISCO como XFS..."
      mkfs.xfs -f "$DISCO"
      mkdir -p "$MONTAGEM"
      mount "$DISCO" "$MONTAGEM"
      chmod 770 "$MONTAGEM"
      UUID_DISCO=$(blkid -s UUID -o value "$DISCO")
      grep -q "$UUID_DISCO" /etc/fstab || echo "UUID=$UUID_DISCO $MONTAGEM xfs defaults,noatime,nodiratime 0 0" >> /etc/fstab
      echo "Disco $DISCO montado em $MONTAGEM com XFS e permissoes 770."
    else
      echo "Etapa de HD extra pulada. Usando diretorio local padrao."
      MONTAGEM="/var/www/html/StorageData-01"
    fi
  fi
fi

NC_PATH="/var/www/html/drive"
NC_DATA="$MONTAGEM"
NC_CONFIG="$NC_PATH/config/config.php"
PHP_FPM_SOCK="/run/php-fpm/www.sock"

echo
echo "CONFIGURACAO DE REDE E SISTEMA"
print_line

firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

if grep -qE "[[:space:]]$FQDN([[:space:]]|\$)" /etc/hosts; then
  sed -i "/[[:space:]]$FQDN\([[:space:]]\|\$\)/d" /etc/hosts
fi
echo "$HOST_IP   $FQDN" >> /etc/hosts

dnf install -y https://rpms.remirepo.net/enterprise/remi-release-10.rpm
dnf install -y epel-release
systemctl daemon-reload

dnf module reset php -y

echo
echo "INSTALACAO DE PACOTES"
print_line

dnf install -y \
  rsync vim wget curl unzip zip tar \
  bash-completion policycoreutils-python-utils \
  plocate bzip2 dnf-utils jq \
  httpd mod_ssl mod_http2 \
  php php-cli php-common php-fpm php-devel php-pear \
  php-ctype php-curl php-dom php-xml php-libxml php-iconv php-json \
  php-mbstring php-openssl php-posix php-session php-zip php-zlib \
  php-pdo php-mysqlnd php-intl php-bcmath php-gmp php-gd \
  php-ldap php-redis php-sodium \
  php-pecl-apcu php-pecl-imagick php-smbclient \
  php-opcache \
  valkey

echo
echo "CONFIGURACAO DO PHP"
print_line

sed -i 's#^;date.timezone.*#date.timezone = America/Sao_Paulo#' /etc/php.ini || true
grep -q '^date.timezone = America/Sao_Paulo' /etc/php.ini || echo 'date.timezone = America/Sao_Paulo' >> /etc/php.ini
sed -i 's/^memory_limit = .*/memory_limit = 2048M/' /etc/php.ini
sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 10G/' /etc/php.ini
sed -i 's/^post_max_size = .*/post_max_size = 10G/' /etc/php.ini
sed -i 's/^max_execution_time = .*/max_execution_time = 360/' /etc/php.ini
sed -i 's/^max_input_time = .*/max_input_time = 360/' /etc/php.ini
sed -i 's/^output_buffering = .*/output_buffering = Off/' /etc/php.ini || true

cat > /etc/php.d/10-opcache.ini <<'EOF'
zend_extension=opcache
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=10000
opcache.save_comments=1
opcache.revalidate_freq=60
opcache.validate_timestamps=1
opcache.jit=off
EOF

rm -f /etc/php.d/20-apcu.ini
cat > /etc/php.d/40-apcu-custom.ini <<'EOF'
apc.enabled=1
apc.enable_cli=1
apc.shm_size=128M
apc.ttl=7200
apc.gc_ttl=3600
EOF

cp -f /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak.$(date +%F-%H%M%S)

sed -i 's#^user = .*#user = apache#' /etc/php-fpm.d/www.conf
sed -i 's#^group = .*#group = apache#' /etc/php-fpm.d/www.conf
sed -i "s#^listen = .*#listen = ${PHP_FPM_SOCK}#" /etc/php-fpm.d/www.conf
sed -i 's#^;listen.owner = .*#listen.owner = apache#' /etc/php-fpm.d/www.conf
sed -i 's#^;listen.group = .*#listen.group = apache#' /etc/php-fpm.d/www.conf
sed -i 's#^;listen.mode = .*#listen.mode = 0660#' /etc/php-fpm.d/www.conf
sed -i 's#^pm = .*#pm = dynamic#' /etc/php-fpm.d/www.conf
sed -i 's#^pm.max_children = .*#pm.max_children = 20#' /etc/php-fpm.d/www.conf
sed -i 's#^pm.start_servers = .*#pm.start_servers = 4#' /etc/php-fpm.d/www.conf
sed -i 's#^pm.min_spare_servers = .*#pm.min_spare_servers = 2#' /etc/php-fpm.d/www.conf
sed -i 's#^pm.max_spare_servers = .*#pm.max_spare_servers = 6#' /etc/php-fpm.d/www.conf

if grep -q '^pm.max_requests = ' /etc/php-fpm.d/www.conf; then
  sed -i 's#^pm.max_requests = .*#pm.max_requests = 500#' /etc/php-fpm.d/www.conf
else
  echo 'pm.max_requests = 500' >> /etc/php-fpm.d/www.conf
fi

grep -q '^clear_env = no' /etc/php-fpm.d/www.conf || echo 'clear_env = no' >> /etc/php-fpm.d/www.conf

systemctl enable --now php-fpm

echo
echo "CONFIGURACAO DO VALKEY"
print_line

cp -f /etc/valkey/valkey.conf /etc/valkey/valkey.conf.bak.$(date +%F-%H%M%S)

grep -q '^unixsocket /run/valkey/valkey.sock' /etc/valkey/valkey.conf || \
  echo 'unixsocket /run/valkey/valkey.sock' >> /etc/valkey/valkey.conf
grep -q '^unixsocketperm 770' /etc/valkey/valkey.conf || \
  echo 'unixsocketperm 770' >> /etc/valkey/valkey.conf

usermod -aG valkey apache || true

systemctl enable --now valkey
systemctl restart valkey

echo
echo "PREPARANDO DIRETORIOS"
print_line

mkdir -p "$NC_PATH" "$NC_DATA"
chown -R apache:apache "$NC_PATH" "$NC_DATA"
chmod 750 "$NC_PATH"
chmod 770 "$NC_DATA"

echo
echo "BAIXANDO E INSTALANDO NEXTCLOUD"
print_line

cd /tmp
rm -rf /tmp/nextcloud /tmp/latest.zip
wget -q https://download.nextcloud.com/server/releases/latest.zip -O /tmp/latest.zip

if [[ ! -s /tmp/latest.zip ]]; then
  echo "Erro: download do Nextcloud falhou."
  exit 1
fi

unzip -oq /tmp/latest.zip -d /tmp
rsync -a /tmp/nextcloud/ "$NC_PATH/"
chown -R apache:apache "$NC_PATH" "$NC_DATA"

mkdir -p "$NC_DATA/skeleton"
rm -rf "$NC_DATA/skeleton"/*

echo
echo "CONFIGURANDO SSL E APACHE"
print_line

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/C=BR/ST=SP/L=SP/O=Nextcloud/CN=$FQDN" \
  -keyout /etc/pki/tls/private/drive-selfsigned.key \
  -out /etc/pki/tls/certs/drive-selfsigned.crt

cat > /etc/httpd/conf.d/drive.conf <<EOF
<VirtualHost *:80>
    ServerName $FQDN
    DocumentRoot $NC_PATH

    RewriteEngine On
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost *:443>
    ServerName $FQDN
    DocumentRoot $NC_PATH

    Protocols h2 http/1.1
    SSLEngine on
    SSLCertificateFile /etc/pki/tls/certs/drive-selfsigned.crt
    SSLCertificateKeyFile /etc/pki/tls/private/drive-selfsigned.key

    Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"
    Header always set Referrer-Policy "no-referrer"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Permitted-Cross-Domain-Policies "none"
    Header always set X-Robots-Tag "noindex, nofollow"
    Header always set X-XSS-Protection "1; mode=block"

    <Directory "$NC_PATH">
        Options FollowSymLinks MultiViews
        AllowOverride All
        Require all granted

        <IfModule mod_dav.c>
            Dav off
        </IfModule>

        <FilesMatch \\.php$>
            SetHandler "proxy:unix:${PHP_FPM_SOCK}|fcgi://localhost/"
        </FilesMatch>
    </Directory>

    <IfModule mod_http2.c>
        H2Direct on
    </IfModule>

    ErrorLog /var/log/httpd/nextcloud_error.log
    CustomLog /var/log/httpd/nextcloud_access.log combined
</VirtualHost>
EOF

cat > /etc/httpd/conf.d/nextcloud-performance.conf <<'EOF'
ServerTokens Prod
ServerSignature Off
TraceEnable Off

KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 2
Timeout 300

FileETag MTime Size

<IfModule mod_deflate.c>
  AddOutputFilterByType DEFLATE text/plain text/html text/xml text/css
  AddOutputFilterByType DEFLATE text/javascript application/javascript application/x-javascript
  AddOutputFilterByType DEFLATE application/json application/xml image/svg+xml
  AddOutputFilterByType DEFLATE application/wasm
</IfModule>

<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/png "access plus 6 months"
  ExpiresByType image/jpg "access plus 6 months"
  ExpiresByType image/jpeg "access plus 6 months"
  ExpiresByType image/gif "access plus 6 months"
  ExpiresByType image/webp "access plus 6 months"
  ExpiresByType image/svg+xml "access plus 6 months"
  ExpiresByType text/css "access plus 6 months"
  ExpiresByType application/javascript "access plus 6 months"
  ExpiresByType text/javascript "access plus 6 months"
  ExpiresByType application/wasm "access plus 6 months"
  ExpiresByType font/woff "access plus 6 months"
  ExpiresByType font/woff2 "access plus 6 months"
</IfModule>

<IfModule mod_headers.c>
  <FilesMatch "\.(js|mjs|css|png|jpg|jpeg|gif|ico|svg|webp|wasm|map|woff|woff2|ttf|otf)$">
    Header unset Pragma
    Header always set Cache-Control "public, max-age=15778463, immutable"
  </FilesMatch>
</IfModule>
EOF

restorecon -Rv /var/www/html /etc/httpd /run/php-fpm /run/valkey || true

systemctl enable --now httpd
systemctl restart php-fpm
systemctl restart httpd

if [[ -f "$NC_CONFIG" ]]; then
  echo "Ja existe um config.php em $NC_CONFIG. Abortando para evitar sobrescrita de instalacao existente."
  exit 1
fi

echo
echo "INSTALANDO NEXTCLOUD VIA OCC"
print_line

sudo -u apache php "$NC_PATH/occ" maintenance:install \
  --database mysql \
  --database-name "$DB_NAME" \
  --database-user "$DB_USER" \
  --database-pass "$DB_PASS" \
  --database-host "$DB_HOST" \
  --admin-user "$ADMIN_USER" \
  --admin-pass "$ADMIN_PASS" \
  --data-dir "$NC_DATA"

sudo -u apache php "$NC_PATH/occ" config:system:set trusted_domains 1 --value="$FQDN"
sudo -u apache php "$NC_PATH/occ" config:system:set overwrite.cli.url --value="https://$FQDN"
sudo -u apache php "$NC_PATH/occ" config:system:set overwriteprotocol --value="https"
sudo -u apache php "$NC_PATH/occ" config:system:set htaccess.RewriteBase --value="/"
sudo -u apache php "$NC_PATH/occ" config:system:set default_phone_region --value="BR"
sudo -u apache php "$NC_PATH/occ" config:system:set default_language --value="pt_BR"
sudo -u apache php "$NC_PATH/occ" config:system:set maintenance_window_start --type=integer --value=2
sudo -u apache php "$NC_PATH/occ" config:system:set skeletondirectory --value="$NC_DATA/skeleton"
sudo -u apache php "$NC_PATH/occ" config:system:set lost_password_link --value="disabled"
sudo -u apache php "$NC_PATH/occ" config:system:delete server_id || true
sudo -u apache php "$NC_PATH/occ" config:system:set serverid --type=integer --value="$SERVERID"

sed -i "/'memcache.local'/d" "$NC_CONFIG"
sed -i "/'memcache.distributed'/d" "$NC_CONFIG"
sed -i "/'memcache.locking'/d" "$NC_CONFIG"
sed -i "/'redis' => \[/,/],/d" "$NC_CONFIG"

sed -i "/^);/i \\
  'memcache.local' => '\\\\\\\\OC\\\\\\\\Memcache\\\\\\\\APCu',\\n\\
  'memcache.distributed' => '\\\\\\\\OC\\\\\\\\Memcache\\\\\\\\Redis',\\n\\
  'memcache.locking' => '\\\\\\\\OC\\\\\\\\Memcache\\\\\\\\Redis',\\n\\
  'redis' => [\\n\\
    'host' => '/run/valkey/valkey.sock',\\n\\
    'port' => 0,\\n\\
    'timeout' => 1.5,\\n\\
  ],\\n" "$NC_CONFIG"

sudo -u apache php "$NC_PATH/occ" background:cron

cat > /etc/systemd/system/nextcloud-cron.service <<EOF
[Unit]
Description=Nextcloud Cron

[Service]
User=apache
ExecStart=/usr/bin/php -f $NC_PATH/cron.php
EOF

cat > /etc/systemd/system/nextcloud-cron.timer <<EOF
[Unit]
Description=Nextcloud Cron Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=nextcloud-cron.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now nextcloud-cron.timer

sudo -u apache php "$NC_PATH/occ" app:disable firstrunwizard || true
sudo -u apache php "$NC_PATH/occ" app:disable weather_status || true
sudo -u apache php "$NC_PATH/occ" app:disable support || true
sudo -u apache php "$NC_PATH/occ" app:disable recommendations || true
sudo -u apache php "$NC_PATH/occ" app:disable dashboard || true
sudo -u apache php "$NC_PATH/occ" app:disable user_status || true
sudo -u apache php "$NC_PATH/occ" app:disable app_api || true
sudo -u apache php "$NC_PATH/occ" app:disable templates || true
sudo -u apache php "$NC_PATH/occ" app:disable text || true
sudo -u apache php "$NC_PATH/occ" app:disable richdocuments || true
sudo -u apache php "$NC_PATH/occ" app:disable richdocumentscode || true

echo
echo "LIMPANDO JOBS ORFAOS E REPARANDO SISTEMA"
print_line

sudo -u apache php "$NC_PATH/occ" maintenance:mode --on

if ! command -v mysql >/dev/null 2>&1; then
  echo "Cliente mysql nao encontrado. Instalando..."
  dnf install -y mariadb
fi

mysql \
  --host="$DB_HOST" \
  --user="$DB_USER" \
  --password="$DB_PASS" \
  "$DB_NAME" <<'SQL' || true
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\FirstRunWizard\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\UserStatus\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\Text\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\Support\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\AppAPI\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\Recommendations\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\Dashboard\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\Richdocuments\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\RichdocumentsCode\\%';
DELETE FROM oc_jobs WHERE class LIKE 'OCA\\Templates\\%';
SQL

sudo -u apache php "$NC_PATH/occ" config:system:delete templatesdirectory || true
sudo -u apache php "$NC_PATH/occ" db:add-missing-indices || true
sudo -u apache php "$NC_PATH/occ" maintenance:repair --include-expensive || true
sudo -u apache php "$NC_PATH/occ" maintenance:update:htaccess
sudo -u apache php "$NC_PATH/occ" maintenance:repair || true
sudo -u apache php "$NC_PATH/occ" background:cron || true
sudo -u apache php "$NC_PATH/occ" maintenance:mode --off
sudo -u apache php "$NC_PATH/occ" files:scan-app-data || true
sudo -u apache php "$NC_PATH/occ" maintenance:repair || true

rm -rf "$NC_DATA/skeleton"/*

ADMIN_DIR=$(sudo -u apache php "$NC_PATH/occ" user:info "$ADMIN_USER" | awk -F': ' '/Home folder/ {print $2}')
if [[ -n "${ADMIN_DIR:-}" && -d "$ADMIN_DIR" ]]; then
  rm -rf "${ADMIN_DIR:?}/"*
  echo "Arquivos de exemplo do usuario $ADMIN_USER removidos."
fi

chown -R apache:apache "$NC_PATH" "$NC_DATA"
find "$NC_PATH" -type d -exec chmod 750 {} \;
find "$NC_PATH" -type f -exec chmod 640 {} \;
find "$NC_DATA" -type d -exec chmod 770 {} \;
find "$NC_DATA" -type f -exec chmod 660 {} \;

restorecon -Rv "$NC_PATH" "$NC_DATA" /etc/httpd /run/php-fpm /run/valkey || true

echo
echo "VALIDACOES FINAIS"
print_line

apachectl -t
php -v
sudo -u apache php "$NC_PATH/occ" config:list system >/dev/null

systemctl restart valkey
systemctl restart php-fpm
systemctl restart httpd

sudo -u apache php "$NC_PATH/occ" maintenance:repair || true
sudo -u apache php "$NC_PATH/occ" status

echo
print_line
echo "DRIVE FINALIZADO COM SUCESSO"
echo "Acesse: https://$FQDN"
print_line
