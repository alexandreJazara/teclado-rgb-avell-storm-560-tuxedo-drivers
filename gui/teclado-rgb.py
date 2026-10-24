#!/usr/bin/env python3
"""Controle da iluminação RGB do teclado do Avell Storm 560.

A janela conversa com o LED class exposto pelo driver em
/sys/class/leds/rgb:kbd_backlight, então tudo o que ela faz também pode ser
feito por brightnessctl ou por qualquer outro applet do sistema.
"""

import colorsys
import math
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")

from gi.repository import Gdk, GLib, Gtk

LED = "/sys/class/leds/rgb:kbd_backlight"
F_BRIGHTNESS = os.path.join(LED, "brightness")
F_MAX_BRIGHTNESS = os.path.join(LED, "max_brightness")
F_COLOR = os.path.join(LED, "multi_intensity")
F_EFEITO = "/sys/devices/platform/tuxedo_keyboard/kbd_effect"

HELPER_PERMISSOES = "/usr/local/libexec/avell-kbd-rgb-perms"

# Informações exibidas na aba "Sobre". Mantenha em sincronia com o README.
VERSAO = "1.0.0"
DATA_ATUALIZACAO = "24 de outubro de 2026"
URL_PROJETO = "https://github.com/alexandrejazara/tuxedo-drivers-avell-560"
AUTOR = "Alexandre Jazara"

# Abaixo disto o teclado está apagado na prática. O systemd-backlight pode
# restaurar um valor da escala antiga (0-4) e a janela mostraria "ligado" com
# a luz invisível.
LIMIAR_VISIVEL = 16

# As sete cores do arco-íris mais o branco.
PRESETS = [
    ("Vermelho", (255, 0, 0)),
    ("Laranja", (255, 127, 0)),
    ("Amarelo", (255, 255, 0)),
    ("Verde", (0, 255, 0)),
    ("Azul", (0, 0, 255)),
    ("Anil", (75, 0, 130)),
    ("Violeta", (148, 0, 211)),
    ("Branco", (255, 255, 255)),
]

# Efeitos animados pela própria janela. O firmware deste chassi aceita o
# comando de modo (0x67) mas não aplica nenhum deles, então a animação é feita
# aqui, alternando brilho e cor pelo sysfs.
EFEITOS = [
    ("custom", "Fixo (manual)"),
    ("breathe", "Respiração"),
    ("rainbow", "Arco-íris"),
    ("flash", "Flash"),
    ("wave", "Onda (fade de cor)"),
]

INTERVALO_ANIMACAO_MS = 100


def ler_inteiro(caminho, padrao=0):
    try:
        with open(caminho) as arquivo:
            return int(arquivo.read().strip())
    except (OSError, ValueError):
        return padrao


def ler_cor():
    try:
        with open(F_COLOR) as arquivo:
            valores = [int(v) for v in arquivo.read().split()]
        if len(valores) == 3:
            return tuple(valores)
    except (OSError, ValueError):
        pass
    return (255, 255, 255)


def ler_texto(caminho):
    try:
        with open(caminho) as arquivo:
            return arquivo.read().strip()
    except OSError:
        return None


def desenhar_cor(area, contexto, cor):
    contexto.set_source_rgb(cor[0] / 255, cor[1] / 255, cor[2] / 255)
    contexto.rectangle(0, 0, area.get_allocated_width(), area.get_allocated_height())
    contexto.fill()
    return False


class JanelaRGB(Gtk.Window):
    def __init__(self):
        super().__init__(title="Teclado RGB")
        self.set_border_width(12)
        self.set_default_size(440, 430)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.ultimo_brilho = 255
        self.sincronizando = False
        self.agendamento = 0

        # Estado das animações
        self.animacao = None
        self.animacao_id = 0
        self.fase = 0.0
        self.cor_base = (255, 255, 255)
        self.ultimo_nivel = -1

        self._montar_interface()
        self._carregar_estado()
        GLib.timeout_add(800, self._sincronizar)

    # ------------------------------------------------------------------
    # Construção da interface
    # ------------------------------------------------------------------
    def _montar_interface(self):
        caderno = Gtk.Notebook()
        self.add(caderno)
        caderno.append_page(
            self._montar_pagina_controle(), Gtk.Label(label="Controle")
        )
        caderno.append_page(
            self._montar_pagina_sobre(), Gtk.Label(label="Sobre")
        )

    def _montar_pagina_controle(self):
        caixa = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        caixa.set_border_width(12)

        titulo = Gtk.Label()
        titulo.set_markup("<b>Iluminação do teclado</b>")
        titulo.set_xalign(0)
        caixa.pack_start(titulo, False, False, 0)

        self.aviso = Gtk.InfoBar()
        self.aviso.set_message_type(Gtk.MessageType.WARNING)
        self.aviso.get_content_area().add(
            Gtk.Label(label="Sem permissão para controlar o LED do teclado.")
        )
        botao_corrigir = self.aviso.add_button("Corrigir", Gtk.ResponseType.ACCEPT)
        botao_corrigir.connect("clicked", self._corrigir_permissoes)
        self.aviso.set_no_show_all(True)
        caixa.pack_start(self.aviso, False, False, 0)

        # Liga / desliga
        linha_poder = Gtk.Box(spacing=10)
        rotulo_poder = Gtk.Label(label="Ligado")
        rotulo_poder.set_xalign(0)
        self.interruptor = Gtk.Switch()
        self.interruptor.connect("notify::active", self._ao_alternar)
        linha_poder.pack_start(rotulo_poder, True, True, 0)
        linha_poder.pack_end(self.interruptor, False, False, 0)
        caixa.pack_start(linha_poder, False, False, 0)

        # Brilho
        linha_brilho = Gtk.Box(spacing=10)
        rotulo_brilho = Gtk.Label(label="Brilho")
        rotulo_brilho.set_xalign(0)
        self.valor_brilho = Gtk.Label(label="--")
        self.valor_brilho.set_width_chars(4)
        self.escala = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 255, 1)
        self.escala.set_draw_value(False)
        self.escala.set_hexpand(True)
        self.escala.connect("value-changed", self._ao_mudar_brilho)
        linha_brilho.pack_start(rotulo_brilho, False, False, 0)
        linha_brilho.pack_start(self.escala, True, True, 0)
        linha_brilho.pack_end(self.valor_brilho, False, False, 0)
        caixa.pack_start(linha_brilho, False, False, 0)

        # Cor
        linha_cor = Gtk.Box(spacing=10)
        rotulo_cor = Gtk.Label(label="Cor")
        rotulo_cor.set_xalign(0)
        self.botao_cor = Gtk.ColorButton()
        self.botao_cor.set_use_alpha(False)
        self.botao_cor.connect("color-set", self._ao_escolher_cor)
        linha_cor.pack_start(rotulo_cor, True, True, 0)
        linha_cor.pack_end(self.botao_cor, False, False, 0)
        caixa.pack_start(linha_cor, False, False, 0)

        # Cores rápidas (arco-íris)
        rotulo_presets = Gtk.Label(label="Cores do arco-íris")
        rotulo_presets.set_xalign(0)
        caixa.pack_start(rotulo_presets, False, False, 0)

        fluxo = Gtk.FlowBox()
        fluxo.set_max_children_per_line(8)
        fluxo.set_selection_mode(Gtk.SelectionMode.NONE)
        fluxo.set_row_spacing(6)
        fluxo.set_column_spacing(6)
        for nome, cor in PRESETS:
            botao = Gtk.Button()
            botao.set_tooltip_text(nome)
            botao.set_relief(Gtk.ReliefStyle.NORMAL)
            area = Gtk.DrawingArea()
            area.set_size_request(26, 20)
            area.connect("draw", desenhar_cor, cor)
            botao.add(area)
            botao.connect("clicked", self._ao_escolher_preset, cor)
            fluxo.add(botao)
        caixa.pack_start(fluxo, False, False, 0)

        # Efeitos do firmware
        linha_efeito = Gtk.Box(spacing=10)
        rotulo_efeito = Gtk.Label(label="Efeito")
        rotulo_efeito.set_xalign(0)
        self.combo = Gtk.ComboBoxText()
        for chave, nome in EFEITOS:
            self.combo.append(chave, nome)
        self.combo.set_active_id("custom")
        self.combo.connect("changed", self._ao_mudar_efeito)
        linha_efeito.pack_start(rotulo_efeito, True, True, 0)
        linha_efeito.pack_end(self.combo, False, False, 0)
        caixa.pack_start(linha_efeito, False, False, 0)

        rodape = Gtk.Label()
        rodape.set_markup(
            "<small>As teclas Fn do teclado numérico também controlam a "
            "iluminação e esta janela acompanha.</small>"
        )
        rodape.set_line_wrap(True)
        rodape.set_xalign(0)
        rodape.get_style_context().add_class("dim-label")
        caixa.pack_end(rodape, False, False, 0)

        return caixa

    def _montar_pagina_sobre(self):
        caixa = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        caixa.set_border_width(12)

        titulo = Gtk.Label()
        titulo.set_markup("<b>Teclado RGB — Avell Storm 560</b>")
        titulo.set_xalign(0)
        caixa.pack_start(titulo, False, False, 0)

        resumo = Gtk.Label(
            label="Controle da iluminação RGB do teclado em notebooks "
            "Avell/Tongfang que respondem ao protocolo Clevo."
        )
        resumo.set_line_wrap(True)
        resumo.set_xalign(0)
        caixa.pack_start(resumo, False, False, 0)

        grade = Gtk.Grid()
        grade.set_row_spacing(6)
        grade.set_column_spacing(12)
        informacoes = [
            ("Versão", VERSAO),
            ("Atualizado em", DATA_ATUALIZACAO),
            ("Autor", AUTOR),
            ("Licença", "GPL-2.0-or-later"),
            ("Driver base", "TUXEDO Computers v4.24.0"),
        ]
        for indice, (rotulo, valor) in enumerate(informacoes):
            chave = Gtk.Label()
            chave.set_markup("<b>%s</b>" % rotulo)
            chave.set_xalign(0)
            grade.attach(chave, 0, indice, 1, 1)
            grade.attach(Gtk.Label(label=valor, xalign=0), 1, indice, 1, 1)
        caixa.pack_start(grade, False, False, 0)

        caixa.pack_start(Gtk.Separator(), False, False, 4)

        rotulo_projeto = Gtk.Label()
        rotulo_projeto.set_markup("<b>Projeto no GitHub</b>")
        rotulo_projeto.set_xalign(0)
        caixa.pack_start(rotulo_projeto, False, False, 0)

        link = Gtk.LinkButton.new_with_label(URL_PROJETO, URL_PROJETO)
        link.set_halign(Gtk.Align.START)
        caixa.pack_start(link, False, False, 0)

        nota = Gtk.Label()
        nota.set_markup(
            "<small>Desenvolvido por %s com auxílio do Qoder (IA), a partir "
            "do driver oficial da TUXEDO Computers. Código aberto sob a "
            "GPL-2.0-or-later.</small>" % AUTOR
        )
        nota.set_line_wrap(True)
        nota.set_xalign(0)
        nota.get_style_context().add_class("dim-label")
        caixa.pack_end(nota, False, False, 0)

        return caixa

    # ------------------------------------------------------------------
    # Leitura e escrita no sysfs
    # ------------------------------------------------------------------
    def _carregar_estado(self):
        maximo = ler_inteiro(F_MAX_BRIGHTNESS, 255) or 255
        self.escala.set_range(0, maximo)
        self._sincronizar(forcar=True)

    def _escrever(self, caminho, texto):
        try:
            with open(caminho, "w") as arquivo:
                arquivo.write(texto)
        except PermissionError:
            self.aviso.show_all()
            return False
        except OSError as erro:
            self.aviso.get_content_area().get_children()[0].set_text(
                "Falha ao escrever no LED: %s" % erro
            )
            self.aviso.show_all()
            return False
        self.aviso.hide()
        return True

    def _aplicar_brilho(self, valor):
        maximo = int(self.escala.get_adjustment().get_upper())
        valor = max(0, min(int(valor), maximo))
        if self._escrever(F_BRIGHTNESS, str(valor)):
            self.valor_brilho.set_text(str(valor))
            if valor > 0:
                self.ultimo_brilho = valor

    def _aplicar_cor(self, cor):
        self._escrever(F_COLOR, "%d %d %d" % cor)

    # ------------------------------------------------------------------
    # Callbacks
    # ------------------------------------------------------------------
    def _ao_alternar(self, interruptor, _parametro):
        if self.sincronizando:
            return
        self._parar_animacao(atualizar_combo=True)
        if interruptor.get_active():
            # Um brilho restaurado da escala antiga (0-4) é invisível: nesse
            # caso liga no máximo em vez de repetir o valor baixo.
            alvo = self.ultimo_brilho
            if alvo <= LIMIAR_VISIVEL:
                alvo = int(self.escala.get_adjustment().get_upper())
            self._aplicar_brilho(alvo)
        else:
            atual = int(self.escala.get_value())
            if atual > LIMIAR_VISIVEL:
                self.ultimo_brilho = atual
            self._aplicar_brilho(0)

    def _ao_mudar_brilho(self, escala):
        if self.sincronizando:
            return
        self._parar_animacao(atualizar_combo=True)
        # Arrastar o controle dispara muitos eventos; agrupa em uma única
        # escrita para não inundar o canal ACPI.
        if self.agendamento:
            GLib.source_remove(self.agendamento)
        self.agendamento = GLib.timeout_add(120, self._aplicar_brilho_agendado)

    def _aplicar_brilho_agendado(self):
        self.agendamento = 0
        self._aplicar_brilho(self.escala.get_value())
        return False

    def _ao_escolher_cor(self, botao):
        if self.sincronizando:
            return
        self._parar_animacao(atualizar_combo=True)
        rgba = botao.get_rgba()
        cor = (round(rgba.red * 255), round(rgba.green * 255), round(rgba.blue * 255))
        self.cor_base = cor
        self._aplicar_cor(cor)

    def _ao_mudar_efeito(self, combo):
        if self.sincronizando:
            return
        efeito = combo.get_active_id()
        if not efeito:
            return
        self._iniciar_animacao(efeito)

    def _ao_escolher_preset(self, _botao, cor):
        self._parar_animacao(atualizar_combo=True)
        self.cor_base = cor
        rgba = Gdk.RGBA(cor[0] / 255, cor[1] / 255, cor[2] / 255, 1.0)
        self.sincronizando = True
        self.botao_cor.set_rgba(rgba)
        self.sincronizando = False
        if int(self.escala.get_value()) <= LIMIAR_VISIVEL:
            alvo = self.ultimo_brilho
            if alvo <= LIMIAR_VISIVEL:
                alvo = int(self.escala.get_adjustment().get_upper())
            self._aplicar_brilho(alvo)
        self._aplicar_cor(cor)

    # ------------------------------------------------------------------
    # Efeitos animados em software
    # ------------------------------------------------------------------
    def _escrever_nivel(self, valor):
        maximo = int(self.escala.get_adjustment().get_upper()) or 255
        valor = max(0, min(int(valor), maximo))
        if valor == self.ultimo_nivel:
            return True
        if self._escrever(F_BRIGHTNESS, str(valor)):
            self.ultimo_nivel = valor
            return True
        return False

    def _abortar_animacao(self):
        if self.animacao_id:
            GLib.source_remove(self.animacao_id)
            self.animacao_id = 0
        self.animacao = None
        self.ultimo_nivel = -1
        return False

    def _parar_animacao(self, atualizar_combo=False):
        if self.animacao_id:
            GLib.source_remove(self.animacao_id)
            self.animacao_id = 0
        self.animacao = None
        self.ultimo_nivel = -1
        if atualizar_combo and self.combo.get_active_id() != "custom":
            self.sincronizando = True
            self.combo.set_active_id("custom")
            self.sincronizando = False

    def _iniciar_animacao(self, tipo):
        self._parar_animacao()
        # Sai de qualquer modo de firmware que possa ignorar as escritas.
        self._escrever(F_EFEITO, "custom")
        if tipo == "custom":
            return
        if int(self.escala.get_value()) <= LIMIAR_VISIVEL:
            alvo = self.ultimo_brilho
            if alvo <= LIMIAR_VISIVEL:
                alvo = int(self.escala.get_adjustment().get_upper())
            self._aplicar_brilho(alvo)
        self.animacao = tipo
        self.fase = 0.0
        self.ultimo_nivel = -1
        self.animacao_id = GLib.timeout_add(
            INTERVALO_ANIMACAO_MS, self._passo_animacao
        )

    def _passo_animacao(self):
        if not self.animacao:
            self.animacao_id = 0
            return False

        maximo = int(self.escala.get_adjustment().get_upper()) or 255
        self.fase += 0.12

        if self.animacao == "breathe":
            # Sobe e desce suavemente entre 10% e 100%.
            nivel = int(maximo * (0.55 + 0.45 * math.sin(self.fase)))
            if not self._escrever_nivel(nivel):
                return self._abortar_animacao()
        elif self.animacao == "rainbow":
            matiz = (self.fase * 45) % 360
            cor = tuple(
                int(round(v * 255))
                for v in colorsys.hsv_to_rgb(matiz / 360, 1.0, 1.0)
            )
            if not self._escrever_nivel(maximo):
                return self._abortar_animacao()
            self._aplicar_cor(cor)
        elif self.animacao == "flash":
            nivel = maximo if int(self.fase * 8) % 4 < 2 else 0
            if not self._escrever_nivel(nivel):
                return self._abortar_animacao()
        elif self.animacao == "wave":
            # Fade suave entre a cor escolhida e o seu complemento.
            fator = 0.5 + 0.5 * math.sin(self.fase)
            complemento = tuple(255 - c for c in self.cor_base)
            cor = tuple(
                int(round(a * (1 - fator) + b * fator))
                for a, b in zip(self.cor_base, complemento)
            )
            if not self._escrever_nivel(maximo):
                return self._abortar_animacao()
            self._aplicar_cor(cor)

        return True

    def _ao_fechar(self, *_):
        self._parar_animacao()
        Gtk.main_quit()

    def _corrigir_permissoes(self, _botao):
        try:
            subprocess.run(["pkexec", HELPER_PERMISSOES], check=False)
        except OSError:
            pass
        self._sincronizar(forcar=True)

    # ------------------------------------------------------------------
    # Sincronização com o hardware (teclas Fn, outros programas)
    # ------------------------------------------------------------------
    def _sincronizar(self, forcar=False):
        # Durante uma animação quem manda no LED é o laço de efeitos; ler o
        # estado agora sobrescreveria os controles com valores intermediários.
        if self.animacao:
            return True

        if not os.path.isdir(LED):
            self.aviso.get_content_area().get_children()[0].set_text(
                "O LED rgb:kbd_backlight não está disponível."
            )
            self.aviso.show_all()
            return True

        brilho = ler_inteiro(F_BRIGHTNESS)
        maximo = ler_inteiro(F_MAX_BRIGHTNESS, 255) or 255
        cor = ler_cor()
        efeito = ler_texto(F_EFEITO)

        self.sincronizando = True
        try:
            self.escala.set_range(0, maximo)
            if forcar or int(self.escala.get_value()) != brilho:
                self.escala.set_value(brilho)
            self.valor_brilho.set_text(str(brilho))
            if brilho > LIMIAR_VISIVEL:
                self.ultimo_brilho = brilho
            ligado = brilho > LIMIAR_VISIVEL or efeito not in (None, "custom")
            self.interruptor.set_active(ligado)
            self.botao_cor.set_rgba(
                Gdk.RGBA(cor[0] / 255, cor[1] / 255, cor[2] / 255, 1.0)
            )
            if efeito:
                self.combo.set_active_id(efeito)
        finally:
            self.sincronizando = False

        return True


def main():
    if not os.path.isdir(LED):
        print("LED rgb:kbd_backlight não encontrado em %s" % LED, file=sys.stderr)
        return 1

    janela = JanelaRGB()
    janela.connect("destroy", janela._ao_fechar)
    janela.show_all()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
