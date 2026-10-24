#!/usr/bin/env bash
# Teste minimo: apenas LIGA / DESLIGA o backlight do teclado.
# Uso: sudo bash teste-onoff.sh
set -u

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$BASE/teste-onoff.log"
LED=/sys/class/leds/rgb:kbd_backlight
PARAM=/sys/module/uniwill_wmi/parameters/ec_direct_io
DYN=/sys/kernel/debug/dynamic_debug/control

exec > >(tee "$LOG") 2>&1

if [ "$(id -u)" -ne 0 ]; then
	echo "ERRO: rode com sudo"
	exit 1
fi
if [ ! -d "$LED" ]; then
	echo "ERRO: $LED não existe (módulo não carregado?)"
	exit 1
fi

echo "=== Teste ON/OFF - $(date) - kernel $(uname -r) ==="
echo "srcversion ativo: $(cat /sys/module/uniwill_wmi/srcversion)"
echo

if ! mountpoint -q /sys/kernel/debug; then
	mount -t debugfs none /sys/kernel/debug 2>/dev/null
fi
[ -w "$DYN" ] && echo 'module uniwill_wmi +p' > "$DYN" 2>/dev/null
[ -w "$DYN" ] && echo 'module tuxedo_keyboard +p' > "$DYN" 2>/dev/null

ciclo() {
	local nome="$1"
	echo "########## $nome (ec_direct_io=$(cat $PARAM)) ##########"
	dmesg -C
	for i in 1 2 3; do
		echo "  [$i] APAGANDO  (brightness=0)"
		echo 0 > "$LED/brightness"
		sleep 3
		echo "  [$i] ACENDENDO (brightness=4)"
		echo 4 > "$LED/brightness"
		sleep 3
	done
	echo "  valor final: brightness=$(cat $LED/brightness)"
	echo "--- dmesg ---"
	dmesg
	echo
}

ciclo "CAMINHO WMI"

echo Y > "$PARAM"
ciclo "CAMINHO EC DIRETO"

# volta ao padrao
echo N > "$PARAM"
echo
echo "=== FIM - log em $LOG ==="
