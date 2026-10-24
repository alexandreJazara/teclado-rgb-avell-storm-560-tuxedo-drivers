#!/bin/bash
# Instala os módulos compilados neste repositório e confere a versão ativa.
# Uso: bash instalar.sh   (pede a senha do sudo)
#
# Importante: o modprobe procura primeiro em /lib/modules/<ver>/updates/.
# Instalar em extra/ não substitui a versão antiga, por isso copiamos para
# updates/src/, que é onde a versão atual está.

set -eu

cd "$(dirname "$0")"

KREL="$(uname -r)"
DEST="/lib/modules/$KREL/updates/src"

echo "Kernel: $KREL"
echo "Destino: $DEST"

if [ ! -f src/tuxedo_keyboard.ko ]; then
	echo "src/tuxedo_keyboard.ko não existe. Rode 'make' primeiro."
	exit 1
fi

sudo mkdir -p "$DEST"
sudo cp -v src/tuxedo_keyboard.ko src/uniwill_wmi.ko "$DEST"/
sudo depmod -a "$KREL"

# Este chassi fala o protocolo Clevo (0x67) e nao responde ao WMI do Uniwill.
# 0x06 = teclado RGB de 1 zona.
CONF=/etc/modprobe.d/avell-kbd.conf
echo "options tuxedo_keyboard kbd_type_override=6" | sudo tee "$CONF" >/dev/null
echo "Configuracao persistente gravada em $CONF"

# Garante o carregamento no boot mesmo quando a deteccao automatica do ACPI
# nao puxa os modulos.
LOAD=/etc/modules-load.d/avell-rgb.conf
printf 'tuxedo_keyboard\nuniwill_wmi\n' | sudo tee "$LOAD" >/dev/null
echo "Carregamento automatico gravado em $LOAD"

echo
echo "Versões instaladas agora:"
for m in tuxedo_keyboard uniwill_wmi; do
	printf '%-18s %s\n' "$m" "$(modinfo -F srcversion "$DEST/$m.ko")"
done

echo
echo "Versões em uso neste momento (só mudam depois de reiniciar):"
for m in tuxedo_keyboard uniwill_wmi; do
	printf '%-18s %s\n' "$m" "$(cat "/sys/module/$m/srcversion" 2>/dev/null || echo carregado-nao)"
done

echo
echo "Reinicie para carregar a versão nova."
