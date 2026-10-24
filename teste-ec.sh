#!/usr/bin/env bash
# Teste em runtime: caminho WMI x caminho EC direto, SEM descarregar módulos.
# Uso: sudo bash teste-ec.sh
#
# O parâmetro /sys/module/uniwill_wmi/parameters/ec_direct_io é gravável,
# então alternamos o caminho de acesso ao EC em tempo real.

set -u

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$BASE/teste-ec.log"
LED=/sys/class/leds/rgb:kbd_backlight
PARAM=/sys/module/uniwill_wmi/parameters/ec_direct_io
DYN=/sys/kernel/debug/dynamic_debug/control

exec > >(tee "$LOG") 2>&1

if [ "$(id -u)" -ne 0 ]; then
	echo "ERRO: rode com sudo (sudo bash $0)"
	exit 1
fi

if [ ! -d "$LED" ]; then
	echo "ERRO: $LED não existe. Reinicie o notebook e rode de novo."
	exit 1
fi

echo "=== Teste de caminho EC - $(date) ==="
uname -r
lsmod | grep -E 'uniwill|tuxedo|clevo'
echo

if ! mountpoint -q /sys/kernel/debug; then
	mount -t debugfs none /sys/kernel/debug 2>/dev/null
fi
[ -w "$DYN" ] && echo 'module tuxedo_keyboard +p' > "$DYN" 2>/dev/null
[ -w "$DYN" ] && echo 'module uniwill_wmi +p' > "$DYN" 2>/dev/null

cores() {
	echo "   >>> VERMELHO"
	echo 4 > "$LED/brightness"; sleep 0.3
	echo "255 0 0" > "$LED/multi_intensity"; sleep 2
	echo "   >>> VERDE"
	echo "0 255 0" > "$LED/multi_intensity"; sleep 2
	echo "   >>> AZUL"
	echo "0 0 255" > "$LED/multi_intensity"; sleep 2
	echo "   >>> BRANCO"
	echo "255 255 255" > "$LED/multi_intensity"; sleep 2
	echo "   >>> APAGADO"
	echo 0 > "$LED/brightness"; sleep 1.5
	echo "   >>> LIGADO DE NOVO (branco)"
	echo 4 > "$LED/brightness"; sleep 1
	echo "   brightness=$(cat $LED/brightness 2>/dev/null)  multi_intensity='$(cat $LED/multi_intensity 2>/dev/null)'"
}

echo "==================================================="
echo " TESTE A: via WMI  (ec_direct_io=$(cat $PARAM))"
echo " OBSERVE O TECLADO: as cores devem mudar a cada passo"
echo "==================================================="
dmesg -C
cores
echo "--- dmesg do teste A ---"
dmesg
echo

echo "==================================================="
echo " TESTE B: EC direto (ec_direct_io=Y)"
echo " OBSERVE O TECLADO NOVAMENTE"
echo "==================================================="
echo Y > "$PARAM"
echo "   ec_direct_io agora = $(cat $PARAM)"
dmesg -C
cores
echo "--- dmesg do teste B ---"
dmesg
echo

echo "==================================================="
echo " FIM - log em $LOG"
echo " Teste A = WMI | Teste B = EC direto"
echo "==================================================="
