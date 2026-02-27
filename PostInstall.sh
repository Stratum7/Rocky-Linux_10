#!/usr/bin/env bash

############################################################
# PERGUNTA NOME DA EMPRESA (FIGLET01)
############################################################
echo "Digite o nome da empresa para o banner (FIGLET01):"
read -r BANNER_FIGLET01

############################################################
# DEFINE HOSTNAME COMO FIGLET02
############################################################
BANNER_FIGLET02="$(hostname)"

############################################################
# ATUALIZAÇÕES E PACOTES
############################################################
dnf update -y
dnf upgrade -y
dnf install epel-release -y

setenforce 0 || true

sed -i s/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/ /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

dnf install dnf-utils figlet wget vim curl git -y

############################################################
# BANNERS (TOTALMENTE FLEXÍVEL)
############################################################
figlet -w 100 -t -k "$BANNER_FIGLET01" > /etc/motd

mkdir -p /etc/motd.d

# Sanitiza nome para usar como nome de arquivo
COMPANY_FILE=$(echo "$BANNER_FIGLET01" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')

figlet -w 100 -t -k "$BANNER_FIGLET02" > "/etc/motd.d/${COMPANY_FILE}"

############################################################
# DESATIVA SELINUX PERMANENTE
############################################################
setenforce 0 || true
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

############################################################
# WEBMIN
############################################################
curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh && yes | sh setup-repos.sh && dnf install webmin -y

sed -i 's/^port=.*/port=50999/' /etc/webmin/miniserv.conf
sed -i "s/^realm=.*/realm=${BANNER_FIGLET01}/" /etc/webmin/miniserv.conf

############################################################
# FIREWALL - LIBERA WEBMIN (PORTA 50999)
############################################################
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=50999/tcp
firewall-cmd --reload

############################################################
# INJETANDO CONFIGURAÇÃO GLOBAL DO BASH
############################################################
cat << 'EOF' > /etc/profile.d/stratum7_prompt.sh
############################################################
# HISTÓRICO
############################################################
export HISTSIZE=-1
export HISTFILESIZE=-1
export HISTCONTROL=ignoredups
export HISTTIMEFORMAT="(%d/%m/%y - %H:%M:%S) -> "
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

############################################################
# FUNÇÃO PRE_PROMPT
############################################################
function pre_prompt {

    user="$(whoami)"
    host=$(echo -n "$HOSTNAME" | sed -e "s/[\.].*//")

    promptsize=$(echo -n "┌($user@$host)(`date \"+%H:%M\"`)┐" | wc -c | tr -d " ")
    fillsize=$((COLUMNS - promptsize))
    fill=""

    while [ "$fillsize" -gt "0" ]; do
        fill="${fill}─"
        fillsize=$((fillsize - 1))
    done
}

PROMPT_COMMAND=pre_prompt

############################################################
# PS1
############################################################
PS1="\n\n\
┌─[\u@\h]${fill}[\t]\n\
├─[\w]\n\
└───\\$ : "
EOF

chmod +x /etc/profile.d/stratum7_prompt.sh
