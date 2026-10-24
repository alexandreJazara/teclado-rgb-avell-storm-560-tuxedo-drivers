#!/bin/bash
# Testa as teclas de atalho do teclado numérico e registra o que o driver faz.
#
# Uso: sudo bash teste-teclas.sh            (modo automático)
#      sudo bash teste-teclas.sh --auto   (força o tipo Clevo 1-zone RGB)
#
# Saia com Ctrl+C.

set -u

if [ "$(id -u)" -ne 0 ]; then
	echo "Rode com sudo: sudo bash $0"
	exit 1
fi

CTRL=/sys/kernel/debug/dynamic_debug/control
if [ ! -w "$CTRL" ]; then
	echo "dynamic debug indisponível em $CTRL"
	exit 1
fi

echo "Ligando log detalhado..."
for m in tuxedo_keyboard clevo_acpi clevo_wmi uniwill_wmi; do
	echo "module $m +p" > "$CTRL" 2>/dev/null
done

PARAM=/sys/module/tuxedo_keyboard/parameters/kbd_type_override
if [ "${1:-}" = "--auto" ]; then
	if [ -w "$PARAM" ]; then
		echo 6 > "$PARAM"
		echo "kbd_type_override = 6 (forçado: Clevo 1-zone RGB)"
		echo "O driver vai usar o protocolo Clevo (0x67) em vez do WMI do Uniwill."
	else
		echo "Parâmetro kbd_type_override ausente; módulo antigo ainda em uso."
	fi
fi

echo
echo "=== Estado atual ==="
for l in /sys/class/leds/rgb:kbd_backlight /sys/class/leds/white:kbd_backlight; do
	[ -d "$l" ] || continue
	echo "$(basename $l): brilho $(cat $l/brightness)/$(cat $l/max_brightness) intensidade [$(cat $l/multi_intensity 2>/dev/null)]"
done
for m in clevo_acpi clevo_wmi uniwill_wmi tuxedo_keyboard; do
	printf '%-16s srcversion=%s\n' "$m" "$(cat /sys/module/$m/srcversion 2>/dev/null || echo ausente)"
done

echo
echo "----------------------------------------------------------------"
echo "Pressione, uma de cada vez:"
echo "  Fn + *   liga / desliga   (comece por esta)"
echo "  Fn + -   reduz brilho"
echo "  Fn + +   aumenta brilho"
echo "  Fn + /   troca a cor"
echo
echo "Procure por:"
echo "  'Clevo event:'                  -> a tecla chegou"
echo "  'method 0x67 ... -> status 0'   -> o firmware aceitou o comando"
echo "  'method 0x67 ... -> status -X'  -> o firmware recusou (transporte errado)"
echo "  'uniwill_wmi: eval:'            -> caiu no caminho Uniwill"
echo "----------------------------------------------------------------"
echo

dmesg --clear 2>/dev/null
exec dmesg -w
