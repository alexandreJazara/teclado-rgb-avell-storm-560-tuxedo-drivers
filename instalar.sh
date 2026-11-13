#!/bin/bash
# Instala os módulos do driver via DKMS (recompila automaticamente em atualizações de kernel)
# e grava a configuração persistente.
# Uso: bash instalar.sh   (pede a senha do sudo)

set -eu

cd "$(dirname "$0")"

PACOTE="avell-storm560-rgb"
VERSAO="1.4.0"
KREL="$(uname -r)"
DEST="/lib/modules/$KREL/updates/src"
SRC_DEST="/usr/src/$PACOTE-$VERSAO"

echo "Driver do teclado RGB — Avell Storm 560 (versão $VERSAO)"
echo "Kernel: $KREL"

if command -v dkms >/dev/null 2>&1; then
	echo "Modo: DKMS (recompilação automática em atualizações de kernel)"

	# Remove cópias manuais antigas que possam conflitar com o DKMS.
	sudo rm -f "$DEST/tuxedo_keyboard.ko" "$DEST/uniwill_wmi.ko" "$DEST/clevo_acpi.ko" "$DEST/clevo_wmi.ko"

	# Remove versões anteriores deste pacote já registradas no DKMS.
	for old_ver in $(dkms status "$PACOTE" 2>/dev/null | awk -F'[,/]' '{gsub(/ /,"",$2); print $2}' | sort -u); do
		sudo dkms remove -m "$PACOTE" -v "$old_ver" --all || true
	done
	sudo rm -rf /usr/src/"$PACOTE"-*

	sudo mkdir -p "$SRC_DEST"
	tar --exclude='*.o' --exclude='*.ko' --exclude='*.cmd' \
		--exclude='*.mod' --exclude='*.mod.c' --exclude='.*.cmd' \
		--exclude='modules.order' --exclude='Module.symvers' \
		--exclude='*.code-workspace' \
		-cf - Kbuild Makefile dkms.conf src | sudo tar -xf - -C "$SRC_DEST"

	sudo dkms add -m "$PACOTE" -v "$VERSAO"
	sudo dkms build -m "$PACOTE" -v "$VERSAO" -k "$KREL"
	sudo dkms install -m "$PACOTE" -v "$VERSAO" -k "$KREL"
else
	echo "Aviso: 'dkms' não encontrado. Instalando manualmente apenas para o kernel $KREL."
	echo "Destino: $DEST"

	if [ ! -f src/tuxedo_keyboard.ko ]; then
		echo "src/tuxedo_keyboard.ko não existe. Rode 'make' primeiro."
		exit 1
	fi

	sudo mkdir -p "$DEST"
	sudo cp -v src/tuxedo_keyboard.ko src/uniwill_wmi.ko src/clevo_acpi.ko src/clevo_wmi.ko "$DEST"/
	sudo depmod -a "$KREL"
fi

# Este chassi fala o protocolo Clevo (0x67) e nao responde ao WMI do Uniwill.
# 0x06 = teclado RGB de 1 zona.
CONF=/etc/modprobe.d/avell-kbd.conf
echo "options tuxedo_keyboard kbd_type_override=6" | sudo tee "$CONF" >/dev/null
echo "Configuracao persistente gravada em $CONF"

# Garante o carregamento no boot mesmo quando a deteccao automatica do ACPI
# nao puxa os modulos.
LOAD=/etc/modules-load.d/avell-rgb.conf
printf 'clevo_acpi\nclevo_wmi\ntuxedo_keyboard\nuniwill_wmi\n' | sudo tee "$LOAD" >/dev/null
echo "Carregamento automatico gravado em $LOAD"

echo
if command -v dkms >/dev/null 2>&1; then
	echo "Status DKMS:"
	dkms status "$PACOTE/$VERSAO" || true
fi

echo
echo "Versões em uso neste momento (só mudam depois de reiniciar):"
for m in tuxedo_keyboard uniwill_wmi; do
	printf '%-18s %s\n' "$m" "$(cat "/sys/module/$m/srcversion" 2>/dev/null || echo carregado-nao)"
done

echo
sudo modprobe -r uniwill_wmi tuxedo_keyboard clevo_wmi clevo_acpi 2>/dev/null || true
if [ ! -d /sys/module/tuxedo_keyboard ]; then
	sudo modprobe clevo_acpi || true
	sudo modprobe clevo_wmi || true
	sudo modprobe tuxedo_keyboard || true
	sudo modprobe uniwill_wmi || true
	echo "Módulos carregados no kernel atual."
else
	echo "Uma versão anterior do driver já está em uso; reinicie para carregar a versão nova."
fi
