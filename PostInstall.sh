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

# Preserva PROMPT_COMMAND original (se existir) e garante history -a
__S7_ORIG_PROMPT_COMMAND="${PROMPT_COMMAND:-}"

############################################################
# FUNÇÃO PRE_PROMPT (ORIGINAL)
############################################################
function pre_prompt {

    newPWD="${PWD}"
    user="$(whoami)"
    host=$(echo -n "$HOSTNAME" | sed -e "s/[\.].*//")
    datenow=$(date "+%a, %d %b %y")

    let promptsize=$(echo -n "┌($user@$host ddd., DD mmm YY)(`date \"+%H:%M\"`)┐" \
        | wc -c | tr -d " ")

    let fillsize=${COLUMNS}-${promptsize}
    fill=""

    while [ "$fillsize" -gt "0" ]
    do
        fill="${fill}─"
        let fillsize=${fillsize}-1
    done

    if [ "$fillsize" -lt "0" ]
    then
        let cutt=3-${fillsize}
        newPWD="...$(echo -n "$PWD" | sed -e "s/\(^.\{$cutt\}\)\(.*\)/\2/")"
    fi
}

# PROMPT_COMMAND final: history -a + pre_prompt + (original se havia)
if [ -n "$__S7_ORIG_PROMPT_COMMAND" ]; then
    export PROMPT_COMMAND="history -a; pre_prompt; $__S7_ORIG_PROMPT_COMMAND"
else
    export PROMPT_COMMAND="history -a; pre_prompt"
fi
export black="\[\033[0;38;5;0m\]"
export red="\[\033[0;38;5;1m\]"
export orange="\[\033[0;38;5;130m\]"
export green="\[\033[0;38;5;2m\]"
export yellow="\[\033[0;38;5;3m\]"
export blue="\[\033[0;38;5;25m\]"
export bblue="\[\033[0;38;5;26m\]"
export magenta="\[\033[0;38;5;55m\]"
export cyan="\[\033[0;38;5;6m\]"
export white="\[\033[0;38;5;6m\]"
export coldblue="\[\033[0;38;5;25m\]"
export smoothblue="\[\033[0;38;5;26m\]"
export iceblue="\[\033[0;38;5;26m\]"
export turqoise="\[\033[0;38;5;50m\]"
export smoothgreen="\[\033[0;38;5;42m\]"
export myred="\[\033[01;31m\]"

PS1="\n \n\
┌─\[$(tput bold)\]\[\033[38;5;25m\][\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \
\[$(tput bold)\]\u\[$(tput sgr0)\] \
\[$(tput bold)\]\[$(tput sgr0)\]\[\033[38;5;26m\]@\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \
\[$(tput bold)\]\h\[$(tput sgr0)\] \
\[$(tput bold)\]\[$(tput sgr0)\]\[\033[38;5;26m\]]\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \
\${fill}\033[38;5;11m\][\t]\[$(tput sgr0)\] \n\
├─\[$(tput bold)\]\[\033[38;5;26m\][\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \
\[$(tput bold)\]\w\[$(tput sgr0) \]\[$(tput bold)\]\[$(tput sgr0)\]\[\033[38;5;26m\]]\[$(tput sgr0)\] \
\[$(tput bold)\]\[\033[38;5;26m\][\[$(tput sgr0)\]\[$(tput sgr0)\]\[\033[38;5;15m\] \
\$(/bin/ls -1 | /usr/bin/wc -l | /bin/sed 's: ::g') files, \
\$(/bin/ls -lah | /bin/grep -m 1 total | /bin/sed 's/total //')  \
\[$(tput bold)\]\[$(tput sgr0)\]\[\033[38;5;26m\]]\[$(tput sgr0)\]     \n\
│\n\
└\[\033[38;5;25m\]───\[$(tput sgr0)\]\[\033[38;5;15m\] \
\[$(tput sgr0)\]\[\033[38;5;25m\]\\$\[$(tput sgr0)\]\[\033[38;5;15m\] : \[$(tput sgr0)\]"
EOF


chmod +x /etc/profile.d/stratum7_prompt.sh
