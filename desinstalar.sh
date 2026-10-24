#!/bin/bash
# Remove o driver, a configuração persistente e a janela de controle.
# Os arquivos do projeto e os fontes do kernel não são tocados.
#
# Uso: bash desinstalar.sh

set -eu

cd "$(dirname "$0")"

KREL="$(uname -r)"
DEST="/lib/modules/$KREL/updates/src"

echo "== Removendo a janela e as permissões =="
sudo systemctl disable --now avell-kbd-rgb-perms.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/avell-kbd-rgb-perms.service
sudo rm -f /etc/udev/rules.d/99-avell-kbd-rgb.rules
sudo rm -f /usr/local/libexec/avell-kbd-rgb-perms
sudo rm -f /usr/share/applications/teclado-rgb.desktop
sudo rm -f /usr/local/bin/teclado-rgb

echo "== Removendo os módulos instalados em $DEST =="
sudo rm -f "$DEST/tuxedo_keyboard.ko" "$DEST/uniwill_wmi.ko"
sudo depmod -a "$KREL"

echo "== Removendo a configuração persistente =="
sudo rm -f /etc/modprobe.d/avell-kbd.conf
sudo rm -f /etc/modules-load.d/avell-rgb.conf

sudo udevadm control --reload-rules 2>/dev/null || true
sudo systemctl daemon-reload

echo
echo "Pronto. Reinicie para voltar aos módulos que já vinham no sistema."
echo "O usuário continua no grupo plugdev; isso não precisa ser desfeito."
