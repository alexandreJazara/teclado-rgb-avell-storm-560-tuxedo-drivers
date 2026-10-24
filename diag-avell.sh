#!/usr/bin/env bash
# Diagnóstico do driver do teclado RGB (Avell Storm 560)
# Uso: sudo bash diag-avell.sh
#
# Testa os dois caminhos de acesso ao EC usados pelo uniwill_wmi:
#   1) via WMI (padrão)         -> module param ec_direct_io=0
#   2) via portas diretas do EC -> module param ec_direct_io=1
# Grava tudo em diag-avell.log ao lado deste script.

set -u

BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$BASE/diag-avell.log"
LED=/sys/class/leds/rgb:kbd_backlight
DYN=/sys/kernel/debug/dynamic_debug/control

exec > >(tee "$LOG") 2>&1

if [ "$(id -u)" -ne 0 ]; then
	echo "ERRO: rode com sudo (sudo bash $0)"
	exit 1
fi

MODS="clevo_wmi clevo_acpi tuxedo_io tuxedo_nb02_nvidia_power_ctrl uniwill_wmi tuxedo_keyboard"

echo "==================================================="
echo " Diagnóstico Avell Storm 560 - $(date)"
echo "==================================================="
uname -a
echo
echo "board: $(cat /sys/class/dmi/id/board_name 2>/dev/null) / bios: $(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
echo

echo "--- estado inicial ---"
lsmod | grep -E 'uniwill|tuxedo|clevo' || echo "(nenhum módulo carregado)"
for f in brightness max_brightness multi_intensity; do
	printf '  %s = %s\n' "$f" "$(cat $LED/$f 2>/dev/null)"
done
echo

# Habilita log de debug (pr_debug) do driver
if ! mountpoint -q /sys/kernel/debug; then
	mount -t debugfs none /sys/kernel/debug 2>/dev/null
fi
if [ -w "$DYN" ]; then
	echo 'module uniwill_wmi +p' > "$DYN" 2>/dev/null
	echo 'module tuxedo_keyboard +p' > "$DYN" 2>/dev/null
	echo "dynamic debug: habilitado"
else
	echo "dynamic debug: INDISPONÍVEL (sem debugfs)"
fi
echo

unload_all() {
	for m in $MODS; do
		modprobe -r "$m" >/dev/null 2>&1
	done
	sleep 1
	lsmod | grep -qE 'uniwill_wmi|tuxedo_keyboard' && echo "AVISO: módulos ainda carregados"
}

agir() {
	# Liga brilho, define vermelho, depois azul -- força passar por todos os callbacks
	echo 0 > "$LED/brightness" 2>/dev/null; sleep 0.3
	echo 4 > "$LED/brightness" 2>/dev/null; sleep 0.3
	echo "255 0 0" > "$LED/multi_intensity" 2>/dev/null; sleep 0.3
	echo 0 > "$LED/brightness" 2>/dev/null; sleep 0.3
	echo 4 > "$LED/brightness" 2>/dev/null; sleep 0.3
	echo "0 0 255" > "$LED/multi_intensity" 2>/dev/null; sleep 0.5
	echo "  brightness=$(cat $LED/brightness 2>/dev/null) multi_intensity='$(cat $LED/multi_intensity 2>/dev/null)'"
}

########## TESTE 1: caminho WMI (padrão) ##########
echo "==================================================="
echo " TESTE 1/2: caminho WMI (ec_direct_io=0)"
echo "==================================================="
unload_all
dmesg -C
modprobe uniwill_wmi 2>&1
sleep 2
echo "--- dmesg após carregar ---"
dmesg
echo "--- ações no sysfs ---"
agir
echo "--- dmesg após as ações ---"
dmesg
echo

########## TESTE 2: caminho direto no EC ##########
echo "==================================================="
echo " TESTE 2/2: caminho direto no EC (ec_direct_io=1)"
echo "==================================================="
unload_all
dmesg -C
modprobe uniwill_wmi ec_direct_io=1 2>&1
sleep 2
echo "--- dmesg após carregar ---"
dmesg
echo "--- ações no sysfs ---"
agir
echo "--- dmesg após as ações ---"
dmesg
echo

echo "==================================================="
echo " FIM"
echo "==================================================="
echo "O teclado está ligado (cor azul, brilho máximo) agora, no modo ec_direct_io=1."
echo "Anote se o teclado acendeu e me avise."
echo "Log salvo em: $LOG"
