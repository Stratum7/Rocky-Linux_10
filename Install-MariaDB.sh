#!/bin/bash

############################################
# INSTALAÇÃO MARIADB - ROCKY LINUX 10
############################################

set -euo pipefail

echo "Instalando dependências..."
dnf install -y mariadb-server openssl firewalld

echo "Garantindo firewalld ativo..."
systemctl enable --now firewalld

echo "Gerando senha segura para root..."
# 24 chars com variedade. (sem espaços/aspas)
ROOT_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9@#%+=_' | head -c 24)"

echo "Instalando MariaDB..."
dnf install -y mariadb-server

echo "Habilitando e iniciando serviço..."
systemctl enable --now mariadb

echo "Aguardando serviço subir..."
sleep 5

############################################
# HARDENING INICIAL
############################################

mysql <<EOF
-- Define senha root local
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';

-- Remove usuários anônimos
DELETE FROM mysql.user WHERE User='';

-- Remove banco de teste
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Remove qualquer root remoto pré-existente
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');

FLUSH PRIVILEGES;
EOF

############################################
# LIBERAR ROOT REMOTO APENAS PARA REDES
############################################

mysql -u root -p"${ROOT_PASSWORD}" <<EOF
CREATE USER IF NOT EXISTS 'root'@'10.%' IDENTIFIED BY '${ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'10.%' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS 'root'@'192.168.%' IDENTIFIED BY '${ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'192.168.%' WITH GRANT OPTION;

FLUSH PRIVILEGES;
EOF

############################################
# TUNING AUTOMÁTICO + CONFIGURAÇÃO
############################################

CNF_FILE="/etc/my.cnf.d/mariadb-server.cnf"

echo "Calculando tuning baseado na RAM e CPU..."

# RAM total em MB
MEM_MB="$(awk '/MemTotal/ {printf "%d\n", $2/1024}' /proc/meminfo)"

# CPU cores
CORES="$(nproc)"
if [ -z "${CORES}" ] || [ "${CORES}" -lt 1 ]; then
  CORES=1
fi

# Define buffer pool (MB)
# >= 2GB -> 75% RAM
# < 2GB  -> 40% RAM (para não estrangular o sistema)
if [ "${MEM_MB}" -ge 2048 ]; then
  BP_MB="$(( MEM_MB * 75 / 100 ))"
else
  BP_MB="$(( MEM_MB * 40 / 100 ))"
fi

# Limites mínimos razoáveis
if [ "${BP_MB}" -lt 128 ]; then
  BP_MB=128
fi

# Instances (baseline)
if [ "${BP_MB}" -lt 1024 ]; then
  BP_INST=1
elif [ "${BP_MB}" -lt 4096 ]; then
  BP_INST=2
elif [ "${BP_MB}" -lt 8192 ]; then
  BP_INST=4
else
  BP_INST=8
fi

# Log buffer (MB) baseline
LOG_BUF_MB=64

############################################
# TUNING POR CPU: max_connections / thread_cache_size / table_open_cache
############################################

# max_connections: CORES*100 (min 200, max 2000)
MAX_CONN="$(( CORES * 100 ))"
if [ "${MAX_CONN}" -lt 200 ]; then
  MAX_CONN=200
elif [ "${MAX_CONN}" -gt 2000 ]; then
  MAX_CONN=2000
fi

# thread_cache_size: CORES*16 (min 64, max 512)
THREAD_CACHE="$(( CORES * 16 ))"
if [ "${THREAD_CACHE}" -lt 64 ]; then
  THREAD_CACHE=64
elif [ "${THREAD_CACHE}" -gt 512 ]; then
  THREAD_CACHE=512
fi

# table_open_cache: CORES*2000 (min 4000, max 20000)
TABLE_OPEN_CACHE="$(( CORES * 2000 ))"
if [ "${TABLE_OPEN_CACHE}" -lt 4000 ]; then
  TABLE_OPEN_CACHE=4000
elif [ "${TABLE_OPEN_CACHE}" -gt 20000 ]; then
  TABLE_OPEN_CACHE=20000
fi

# table_definition_cache: ~ metade do table_open_cache (min 2000, max 10000)
TABLE_DEF_CACHE="$(( TABLE_OPEN_CACHE / 2 ))"
if [ "${TABLE_DEF_CACHE}" -lt 2000 ]; then
  TABLE_DEF_CACHE=2000
elif [ "${TABLE_DEF_CACHE}" -gt 10000 ]; then
  TABLE_DEF_CACHE=10000
fi

# open_files_limit: margem para conexões/temporários + cache de tabelas
OPEN_FILES_LIMIT="$(( TABLE_OPEN_CACHE * 2 + 2048 ))"
if [ "${OPEN_FILES_LIMIT}" -lt 8192 ]; then
  OPEN_FILES_LIMIT=8192
elif [ "${OPEN_FILES_LIMIT}" -gt 65535 ]; then
  OPEN_FILES_LIMIT=65535
fi

echo "CPU detectada: ${CORES} cores"
echo "RAM detectada: ${MEM_MB} MB"
echo "Aplicando innodb_buffer_pool_size: ${BP_MB}M"
echo "Aplicando innodb_buffer_pool_instances: ${BP_INST}"
echo "Aplicando max_connections: ${MAX_CONN}"
echo "Aplicando thread_cache_size: ${THREAD_CACHE}"
echo "Aplicando table_open_cache: ${TABLE_OPEN_CACHE}"
echo "Aplicando table_definition_cache: ${TABLE_DEF_CACHE}"
echo "Aplicando open_files_limit: ${OPEN_FILES_LIMIT}"

# Garante bind-address para LAN
if grep -q "^[[:space:]]*bind-address" "${CNF_FILE}"; then
  sed -i "s/^[[:space:]]*bind-address.*/bind-address = 0.0.0.0/" "${CNF_FILE}"
else
  echo "bind-address = 0.0.0.0" >> "${CNF_FILE}"
fi

# Remove bloco gerenciado anterior (se existir) para não duplicar
sed -i '/^# S7-BEGIN-MANAGED$/,/^# S7-END-MANAGED$/d' "${CNF_FILE}"

# Insere bloco gerenciado com tuning e hardening
cat >> "${CNF_FILE}" <<EOC

# S7-BEGIN-MANAGED
[mysqld]
# Rede
bind-address=0.0.0.0

# Segurança / consistência
skip-name-resolve=1
local-infile=0
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Performance baseline (InnoDB)
default_storage_engine=InnoDB
innodb_buffer_pool_size=${BP_MB}M
innodb_buffer_pool_instances=${BP_INST}
innodb_log_file_size=256M
innodb_log_buffer_size=${LOG_BUF_MB}M
innodb_flush_method=O_DIRECT
innodb_flush_log_at_trx_commit=1
innodb_file_per_table=1

# Conexões / caches (CPU-based)
max_connections=${MAX_CONN}
thread_cache_size=${THREAD_CACHE}
table_open_cache=${TABLE_OPEN_CACHE}
table_definition_cache=${TABLE_DEF_CACHE}
open_files_limit=${OPEN_FILES_LIMIT}

# Temp tables (baseline)
tmp_table_size=128M
max_heap_table_size=128M

# Timeouts (evita conexões zumbis)
wait_timeout=600
interactive_timeout=600

# Logs úteis (ajuste conforme necessidade)
slow_query_log=1
long_query_time=2
# S7-END-MANAGED
EOC

echo "Reiniciando MariaDB..."
systemctl restart mariadb

############################################
# FIREWALL
############################################

echo "Configurando firewall..."

firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port protocol="tcp" port="3306" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/16" port protocol="tcp" port="3306" accept'
firewall-cmd --permanent --remove-port=3306/tcp >/dev/null 2>&1 || true
firewall-cmd --reload

############################################
# FINAL
############################################

echo "--------------------------------------------"
echo " MariaDB instalado com sucesso!"
echo " Root remoto liberado apenas para:"
echo "   10.0.0.0/8  (host: 10.%)"
echo "   192.168.0.0/16 (host: 192.168.%)"
echo ""
echo " CPU detectada: ${CORES} cores"
echo " RAM detectada: ${MEM_MB} MB"
echo " innodb_buffer_pool_size aplicado: ${BP_MB}M (75% se RAM>=2GB)"
echo " innodb_buffer_pool_instances aplicado: ${BP_INST}"
echo " max_connections aplicado: ${MAX_CONN}"
echo " thread_cache_size aplicado: ${THREAD_CACHE}"
echo " table_open_cache aplicado: ${TABLE_OPEN_CACHE}"
echo ""
echo " SENHA DO ROOT:"
echo " ${ROOT_PASSWORD}"
echo "--------------------------------------------"
