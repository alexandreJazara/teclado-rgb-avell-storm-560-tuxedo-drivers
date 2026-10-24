#!/bin/bash
# Instala a janela de controle do teclado RGB e as permissões de acesso.
# Uso: bash instalar-gui.sh
set -eu

cd "$(dirname "$0")"

VERSAO="1.3.0"

USUARIO="${SUDO_USER:-$USER}"

if ! python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
	echo "PyGObject/GTK3 não encontrado."
	echo "No Linux Mint: sudo apt install python3-gi gir1.2-gtk-3.0"
	exit 1
fi

sudo install -Dm755 gui/teclado-rgb.py /usr/local/bin/teclado-rgb
sudo install -Dm644 gui/teclado-rgb.desktop /usr/share/applications/teclado-rgb.desktop
sudo install -Dm755 gui/avell-kbd-rgb-perms /usr/local/libexec/avell-kbd-rgb-perms
sudo install -Dm644 gui/99-avell-kbd-rgb.rules /etc/udev/rules.d/99-avell-kbd-rgb.rules
sudo install -Dm644 gui/avell-kbd-rgb-perms.service /etc/systemd/system/avell-kbd-rgb-perms.service

if ! id -nG "$USUARIO" | grep -qw plugdev; then
	sudo usermod -aG plugdev "$USUARIO"
	echo "Usuário $USUARIO adicionado ao grupo plugdev (efetivo no próximo login)."
fi

sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=leds
sudo systemctl daemon-reload
sudo systemctl enable --now avell-kbd-rgb-perms.service || true
sudo /usr/local/libexec/avell-kbd-rgb-perms || true

# Atualiza o cache do menu para o nome novo aparecer na busca.
command -v update-desktop-database >/dev/null 2>&1 && \
	sudo update-desktop-database /usr/share/applications || true

echo
echo "Pronto. Controlador do Teclado LED — Avell Storm 560 $VERSAO instalado."
echo "Abra pelo menu ou rode: teclado-rgb"
