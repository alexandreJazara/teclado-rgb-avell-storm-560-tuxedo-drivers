#!/bin/bash
# Instalação completa do teclado RGB do Avell Storm 560:
#   1. compila os módulos do kernel;
#   2. instala os módulos e a configuração persistente;
#   3. instala a janela de controle e as permissões de acesso.
#
# Uso:
#   bash instalar-tudo.sh          # driver + janela
#   bash instalar-tudo.sh --driver # somente o driver
#   bash instalar-tudo.sh --gui    # somente a janela (driver já instalado)
#
# Rode como usuário comum: o script pede a senha do sudo quando precisar.

set -eu

cd "$(dirname "$0")"

VERSAO="1.1.0"

MODO="${1:-tudo}"

case "$MODO" in
	tudo|--driver|--gui) ;;
	-h|--help)
		sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*)
		echo "Opção desconhecida: $MODO"
		echo "Use --driver, --gui ou nenhuma opção."
		exit 1
		;;
esac

KREL="$(uname -r)"
FALHAS=0

titulo() {
	echo
	echo "== $1 =="
}

verificar() {
	if [ ! -e "$1" ]; then
		echo "  [faltando] $1"
		FALHAS=1
	else
		echo "  [ok] $2"
	fi
}

titulo "Controlador do Teclado LED — Avell Storm 560 $VERSAO"
titulo "Verificando o ambiente"
verificar "/lib/modules/$KREL/build/Makefile" "headers do kernel $KREL"
command -v make >/dev/null 2>&1 && echo "  [ok] make" || { echo "  [faltando] make"; FALHAS=1; }
command -v gcc >/dev/null 2>&1 && echo "  [ok] gcc" || { echo "  [faltando] gcc"; FALHAS=1; }

if [ "$MODO" != "--driver" ]; then
	if python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
		echo "  [ok] PyGObject/GTK 3"
	else
		echo "  [faltando] PyGObject/GTK 3"
		FALHAS=1
	fi
fi

if [ "$FALHAS" -ne 0 ]; then
	echo
	echo "Instale o que falta e rode de novo. No Linux Mint/Ubuntu:"
	echo "  sudo apt install build-essential linux-headers-$KREL python3-gi gir1.2-gtk-3.0"
	exit 1
fi

if [ "$MODO" != "--gui" ]; then
	titulo "Compilando os módulos"
	make -j"$(nproc)"

	titulo "Instalando o driver"
	bash instalar.sh
fi

if [ "$MODO" != "--driver" ]; then
	titulo "Instalando a janela de controle"
	bash instalar-gui.sh
fi

titulo "Concluído"
if [ "$MODO" != "--gui" ]; then
	echo "Reinicie o computador para carregar a versão nova do driver."
else
	echo "Feche e abra o 'Controlador do Teclado LED' para usar a versão nova."
fi
