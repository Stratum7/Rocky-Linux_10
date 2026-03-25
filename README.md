Execute via root

1) Baixe as modificações post-install \
curl -fsSL https://install.stratum7.com.br/post-install -o postinstall.sh \
chmod +x postinstall.sh \
./postinstall.sh

2) Instalar MariaDB


3) Instalar Drive \
curl -fsSL https://install.stratum7.com.br/Install-Drive.sh -o Install-Drive.sh \
chmod +x Install-Drive.sh \
./Install-Drive.sh






Para fazer depois de forma automatizada, esse script já deixa pronto:

cria /root/nextcloud-postinstall-disable-apps.sh
cria o serviço nextcloud-postinstall-disable-apps.service
cria o timer nextcloud-postinstall-disable-apps.timer
agenda a execução automática 30 minutos após o boot

Com isso, a instalação sobe com os apps padrão ativos, reduzindo aqueles warnings iniciais, e só depois a rotina automática desabilita os apps opcionais, limpa jobs órfãos e roda reparos.

Comandos úteis:

systemctl status nextcloud-postinstall-disable-apps.timer
systemctl list-timers | grep nextcloud-postinstall

Para executar manualmente a pós-instalação sem esperar o timer:

systemctl start nextcloud-postinstall-disable-apps.service

Para ver logs dessa automação:

journalctl -u nextcloud-postinstall-disable-apps.service -n 100 --no-pager

Para impedir que rode automaticamente:

systemctl disable --now nextcloud-postinstall-disable-apps.timer

Para remover a automação depois que ela já tiver rodado e você não quiser mais manter:

systemctl disable --now nextcloud-postinstall-disable-apps.timer
rm -f /etc/systemd/system/nextcloud-postinstall-disable-apps.timer
rm -f /etc/systemd/system/nextcloud-postinstall-disable-apps.service
rm -f /root/nextcloud-postinstall-disable-apps.sh
systemctl daemon-reload
