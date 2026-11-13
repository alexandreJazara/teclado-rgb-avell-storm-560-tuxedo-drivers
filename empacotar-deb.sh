#!/bin/bash
# Gera o pacote instalador .deb (com DKMS) para Linux Mint / Ubuntu / Debian.
# Uso: bash empacotar-deb.sh
# Saída: dist/avell-storm560-rgb_1.4.0_all.deb

set -eu

cd "$(dirname "$0")"

PACOTE="avell-storm560-rgb"
VERSAO="1.4.0"
ARQ="all"
SAIDA_DIR="dist"
DEB_NOME="${PACOTE}_${VERSAO}_${ARQ}.deb"

if ! command -v dpkg-deb >/dev/null 2>&1; then
	echo "Erro: 'dpkg-deb' não encontrado. Instale o pacote 'dpkg'."
	exit 1
fi

STAGE="$(mktemp -d)"
chmod 755 "$STAGE"
trap 'rm -rf "$STAGE"' EXIT

echo "== Montando estrutura do pacote $DEB_NOME =="

# 1. Código-fonte do driver para o DKMS
SRC_DEST="$STAGE/usr/src/$PACOTE-$VERSAO"
mkdir -p "$SRC_DEST"
chmod 755 "$STAGE/usr" "$STAGE/usr/src" "$SRC_DEST"
tar --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
	--exclude='*.mod' --exclude='*.mod.c' --exclude='.*.cmd' \
	--exclude='modules.order' --exclude='Module.symvers' \
	--exclude='*.code-workspace' \
	-cf - Kbuild Makefile dkms.conf src | tar -xf - -C "$SRC_DEST"

# 2. Configuração persistente do kernel
install -d "$STAGE/etc/modprobe.d" "$STAGE/etc/modules-load.d"
echo "options tuxedo_keyboard kbd_type_override=6" > "$STAGE/etc/modprobe.d/avell-kbd.conf"
printf 'clevo_acpi\nclevo_wmi\ntuxedo_keyboard\nuniwill_wmi\n' > "$STAGE/etc/modules-load.d/avell-rgb.conf"
chmod 644 "$STAGE/etc/modprobe.d/avell-kbd.conf" "$STAGE/etc/modules-load.d/avell-rgb.conf"

# 3. Janela de controle (GUI) e permissões
install -Dm755 gui/teclado-rgb.py "$STAGE/usr/local/bin/teclado-rgb"
install -Dm644 gui/teclado-rgb.desktop "$STAGE/usr/share/applications/teclado-rgb.desktop"
install -Dm755 gui/avell-kbd-rgb-perms "$STAGE/usr/local/libexec/avell-kbd-rgb-perms"
install -Dm644 gui/99-avell-kbd-rgb.rules "$STAGE/etc/udev/rules.d/99-avell-kbd-rgb.rules"
install -Dm644 gui/avell-kbd-rgb-perms.service "$STAGE/etc/systemd/system/avell-kbd-rgb-perms.service"

# 4. Metadados DEBIAN
mkdir -p "$STAGE/DEBIAN"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PACOTE
Version: $VERSAO
Section: kernel
Priority: optional
Architecture: $ARQ
Depends: dkms, build-essential, linux-headers-generic | linux-headers-amd64, python3-gi, gir1.2-gtk-3.0
Maintainer: Alexandre Jazara <https://github.com/alexandreJazara/teclado-rgb-avell-storm-560-tuxedo-drivers>
Homepage: https://github.com/alexandreJazara/teclado-rgb-avell-storm-560-tuxedo-drivers
Description: Driver DKMS e controlador RGB para o teclado do Avell Storm 560
 Módulos tuxedo_keyboard e uniwill_wmi adaptados para o Avell Storm 560,
 com suporte a DKMS (recompilação automática em atualizações de kernel),
 bloqueio/desbloqueio do touchpad e janela gráfica de controle RGB.
EOF

cat > "$STAGE/DEBIAN/conffiles" <<EOF
/etc/modprobe.d/avell-kbd.conf
/etc/modules-load.d/avell-rgb.conf
EOF

cat > "$STAGE/DEBIAN/postinst" <<EOF
#!/bin/sh
set -e

PACOTE="$PACOTE"
VERSAO="$VERSAO"

case "\$1" in
	configure)
		# Remove cópias manuais antigas que possam conflitar com o DKMS.
		for kdir in /lib/modules/*; do
			rm -f "\$kdir/updates/src/tuxedo_keyboard.ko" \
				"\$kdir/updates/src/uniwill_wmi.ko" \
				"\$kdir/updates/src/clevo_acpi.ko" \
				"\$kdir/updates/src/clevo_wmi.ko" 2>/dev/null || true
		done

		if ! dkms status -m "\$PACOTE" -v "\$VERSAO" 2>/dev/null | grep -q "\$PACOTE"; then
			dkms add -m "\$PACOTE" -v "\$VERSAO"
		fi

		for kbuild in /lib/modules/*/build; do
			[ -d "\$kbuild" ] || continue
			kver="\$(basename "\$(dirname "\$kbuild")")"
			dkms build -m "\$PACOTE" -v "\$VERSAO" -k "\$kver" || true
			dkms install -m "\$PACOTE" -v "\$VERSAO" -k "\$kver" || true
		done

		REINICIAR=0
		modprobe -r uniwill_wmi tuxedo_keyboard clevo_wmi clevo_acpi 2>/dev/null || true
		if [ ! -d /sys/module/tuxedo_keyboard ]; then
			modprobe clevo_acpi || true
			modprobe clevo_wmi || true
			modprobe tuxedo_keyboard || true
			modprobe uniwill_wmi || true
		else
			REINICIAR=1
		fi

		if [ -n "\${SUDO_USER:-}" ] && [ "\$SUDO_USER" != "root" ]; then
			if ! id -nG "\$SUDO_USER" 2>/dev/null | grep -qw plugdev; then
				usermod -aG plugdev "\$SUDO_USER" || true
				echo "Usuário \$SUDO_USER adicionado ao grupo plugdev (efetivo no próximo login)."
			fi
		fi

		udevadm control --reload-rules 2>/dev/null || true
		udevadm trigger --subsystem-match=leds 2>/dev/null || true
		if [ -d /run/systemd/system ]; then
			systemctl daemon-reload || true
			systemctl enable --now avell-kbd-rgb-perms.service || true
		fi
		/usr/local/libexec/avell-kbd-rgb-perms || true
		command -v update-desktop-database >/dev/null 2>&1 && \
			update-desktop-database /usr/share/applications || true

		if [ "\$REINICIAR" -eq 1 ]; then
			echo
			echo "AVISO: Uma versão anterior do driver já estava carregada na memória."
			echo "Reinicie o computador para ativar a versão \$VERSAO."
		fi
		;;
esac

exit 0
EOF
chmod 755 "$STAGE/DEBIAN/postinst"

cat > "$STAGE/DEBIAN/prerm" <<EOF
#!/bin/sh
set -e

PACOTE="$PACOTE"
VERSAO="$VERSAO"

case "\$1" in
	remove|upgrade|deconfigure)
		dkms remove -m "\$PACOTE" -v "\$VERSAO" --all 2>/dev/null || true
		if [ "\$1" = "remove" ] && [ -d /run/systemd/system ]; then
			systemctl disable --now avell-kbd-rgb-perms.service 2>/dev/null || true
		fi
		;;
esac

exit 0
EOF
chmod 755 "$STAGE/DEBIAN/prerm"

mkdir -p "$SAIDA_DIR"
dpkg-deb --build --root-owner-group "$STAGE" "$SAIDA_DIR/$DEB_NOME"

echo
echo "Pacote gerado com sucesso: $SAIDA_DIR/$DEB_NOME"
echo "Para instalar localmente: sudo apt install ./$SAIDA_DIR/$DEB_NOME"
