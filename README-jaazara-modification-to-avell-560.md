# Controlador do Teclado LED — Avell Storm 560 no Linux

Driver de kernel e aplicativo gráfico para controlar a iluminação RGB do teclado do **Avell Storm 560** (chassi Tongfang/Uniwill) em Linux Mint, Ubuntu e derivados.

Este repositório é um fork do [tuxedo-drivers](https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers) da TUXEDO Computers, adaptado para um chassi que responde ao protocolo **Clevo** em vez do WMI da Uniwill.

**Versão 1.3.0** — atualizada em **24 de outubro de 2026**

---

## Situação dos recursos

| Recurso | Situação |
| --- | --- |
| Ligar / desligar (`Fn` + `*`) | Funciona |
| Botão **Ligar/Desligar o teclado** na janela | Funciona |
| Botão **Ligar/Desligar o touchpad** na janela | Funciona |
| Aumentar / diminuir brilho (`Fn` + `+` / `Fn` + `-`) | Funciona, em 6 degraus visíveis |
| Trocar a cor (`Fn` + `/`) | Funciona, percorre 8 cores |
| Bloquear/desbloquear o touchpad (`Fn` + `F1`) | Funciona |
| Controlador do Teclado LED | Funciona |
| Cor RGB arbitrária (seletor de cores) | Funciona |
| Efeitos animados (respiração, arco-íris, flash, onda) | Funcionam em software, com a janela aberta |
| Efeitos nativos do firmware | O firmware aceita o comando, mas **ignora** todos os modos |
| Zonas independentes de cor | **Não**: o teclado tem uma única zona |

> **Por que os efeitos são em software?**
> Os oito modos de efeito do protocolo Clevo (`custom`, `breathe`, `cycle`, `dance`, `flash`, `random_color`, `tempo`, `wave`) retornam `status 0` neste chassi, mas não produzem nenhuma alteração na luz. Por isso a janela anima brilho e cor diretamente pelo sysfs. A desvantagem é que a animação para quando a janela é fechada.

---

## Requisitos

- Linux Mint 22.x, Ubuntu 24.04 ou derivados (testado no kernel `7.0.0-38-generic`)
- Headers do kernel em uso
- PyGObject e GTK 3 para a janela

```bash
sudo apt update
sudo apt install build-essential git linux-headers-$(uname -r) \
                 python3-gi gir1.2-gtk-3.0
```

---

## Instalação rápida

```bash
git clone https://github.com/alexandreJazara/teclado-rgb-avell-storm-560-tuxedo-drivers.git
cd teclado-rgb-avell-storm-560-tuxedo-drivers
bash instalar-tudo.sh
```

O script verifica o ambiente, compila os módulos, instala o driver, grava a configuração persistente e instala a janela com as permissões de acesso. Ao final, **reinicie** para carregar a versão nova do módulo.

Opções:

```bash
bash instalar-tudo.sh --driver   # somente o driver
bash instalar-tudo.sh --gui      # somente a janela (driver já instalado)
```

### O que é instalado

| Arquivo | Destino |
| --- | --- |
| `tuxedo_keyboard.ko`, `uniwill_wmi.ko` | `/lib/modules/$(uname -r)/updates/src/` |
| Configuração do módulo | `/etc/modprobe.d/avell-kbd.conf` |
| Carregamento no boot | `/etc/modules-load.d/avell-rgb.conf` |
| Aplicativo | `/usr/local/bin/teclado-rgb` |
| Atalho no menu | `/usr/share/applications/teclado-rgb.desktop` |
| Helper de permissões | `/usr/local/libexec/avell-kbd-rgb-perms` |
| Regra udev | `/etc/udev/rules.d/99-avell-kbd-rgb.rules` |
| Serviço de permissões | `/etc/systemd/system/avell-kbd-rgb-perms.service` |

A configuração persistente contém:

```
options tuxedo_keyboard kbd_type_override=6
```

`0x06` é o tipo Clevo `1_ZONE_RGB`, que força o driver a usar o protocolo correto mesmo quando a detecção automática falha.

### Secure Boot

Os módulos são compilados localmente e não possuem assinatura digital. Com o **Secure Boot** ativado, o kernel recusa o carregamento. Desative a opção na BIOS (normalmente em `Security` ou `Boot`) antes de reiniciar.

### Carregamento automático

O `instalar.sh` grava `/etc/modules-load.d/avell-rgb.conf` com `tuxedo_keyboard` e `uniwill_wmi`, garantindo que os módulos subam no boot mesmo quando a detecção automática do ACPI não os carrega.

---

## Usando o Controlador do Teclado LED

Abra **Controlador do Teclado LED — Avell Storm 560** no menu do sistema ou rode:

```bash
teclado-rgb
```

A janela tem duas abas:

- **Controle**: liga/desliga, brilho, seletor de cor, oito atalhos de cor do arco-íris e o menu de efeitos.
- **Sobre**: versão, data de atualização, autor, licença e o link deste repositório.

As teclas `Fn` continuam funcionando e a janela acompanha as mudanças em até um segundo. Durante uma animação a sincronização é pausada para não sobrescrever os valores intermediários.

### Atalhos físicos

| Atalho | Ação |
| --- | --- |
| `Fn` + `*` | Liga / desliga a iluminação |
| `Fn` + `+` | Aumenta o brilho |
| `Fn` + `-` | Diminui o brilho |
| `Fn` + `/` | Próxima cor |
| `Fn` + `F1` | Liga / desliga o touchpad |

### Efeitos

| Efeito | O que faz |
| --- | --- |
| Fixo (manual) | Mantém a cor escolhida |
| Respiração | Sobe e desce o brilho suavemente |
| Arco-íris | Percorre o círculo de cores |
| Flash | Alterna entre máximo e apagado |
| Onda (fade de cor) | Faz transição entre a cor escolhida e a cor complementar |

Qualquer interação manual (brilho, cor ou atalho) volta o efeito para **Fixo (manual)**.

---

## Controle manual pelo sysfs

```bash
# Brilho (0 a 255)
echo 255 | sudo tee /sys/class/leds/rgb:kbd_backlight/brightness

# Cor no formato "R G B"
echo "255 120 0" | sudo tee /sys/class/leds/rgb:kbd_backlight/multi_intensity

# Modo do firmware (aceito, mas ignorado neste chassi)
echo custom | sudo tee /sys/devices/platform/tuxedo_keyboard/kbd_effect
```

Valores aceitos em `kbd_effect`: `custom`, `breathe`, `cycle`, `dance`, `flash`, `random_color`, `tempo` e `wave`.

Para usar sem `sudo`, o serviço `avell-kbd-rgb-perms` deixa `brightness`, `multi_intensity` e `kbd_effect` graváveis pelo grupo `plugdev`.

---

## Como o suporte foi construído

O caminho até o teclado funcionar envolveu diagnósticos no firmware deste chassi:

1. **O WMI da Uniwill não responde.** As chamadas ao GUID `ABBC0F6D-8EA1-11D1-00A0-C90629100000` retornam `ACPI_TYPE_INTEGER` com valor `0` em vez do buffer esperado. O acesso direto ao mailbox do EC também dá timeout.
2. **O `_DSM` da Clevo responde.** O device ACPI `CLV0001` expõe o UUID `93f224e4-fbdc-4bbf-add6-db71bdc0afad`, e é por ele que o comando `0x67` (`CLEVO_CMD_SET_KB_RGB_LEDS`) chega ao teclado.
3. **A detecção automática falha.** Por isso o módulo recebe `kbd_type_override=6` e passa a tratar o teclado como RGB de uma zona.
4. **O `uniwill_wmi` vencia a corrida de probe.** Os dois drivers disputam o registro do LED e o Uniwill registrava uma escala de 0 a 4, inútil para o Clevo (0 a 255). A solução foi fazer `uniwill_leds_init()` delegar o registro ao Clevo quando o override está ativo.
5. **As funções externas ignoravam o override.** Quatro funções de `clevo_leds.h` testavam a variável crua em vez de `clevo_leds_get_backlight_type()`, o que impedia a troca de cor. Passaram a usar o getter.
6. **O brilho mudava de um em um.** Na escala de 0 a 255 o passo era invisível. O controle por tecla agora percorre seis níveis (`0x00`, `0x33`, `0x66`, `0x99`, `0xcc`, `0xff`).
7. **Os efeitos do firmware não funcionam.** Tentativas com `wave`, `breathe` e outros modos geraram `method 0x67 -> status 0` sem nenhuma mudança visual. A solução foi animar pela janela.
8. **O `Fn+F1` não chegava ao desktop.** O firmware envia `0x5D`, mas o evento caía no keymap do Uniwill e era descartado; além disso, o `KEY_F21` não tem mapeamento no X11. O driver passou a reportar `KEY_TOUCHPAD_TOGGLE`/`ON`/`OFF` diretamente, que o Cinnamon traduz para `XF86TouchpadToggle`.

---

## Compilando do zero (desenvolvimento)

```bash
# compilar
make

# limpar artefatos
make clean

# instalar os módulos compilados
bash instalar.sh

# instalar apenas a janela
bash instalar-gui.sh
```

O `Makefile` compila com `make -C /lib/modules/$(uname -r)/build M=$(CURDIR) modules`. O `instalar.sh` copia os `.ko` para `updates/src/`, que tem prioridade sobre `extra/` na busca do `modprobe`.

Para acompanhar o que o driver faz:

```bash
# habilita as mensagens de depuração do módulo
echo "module tuxedo_keyboard +p" | sudo tee /sys/kernel/debug/dynamic_debug/control

# acompanha o log
sudo dmesg -w | grep -i -E "clevo|uniwill|tuxedo"
```

---

## Estrutura do repositório

```
src/
  tuxedo_keyboard.c        núcleo e parâmetros do módulo
  clevo_keyboard.h         atalhos Fn e degraus de brilho
  clevo_leds.h             protocolo Clevo 0x67 (cor, brilho, efeitos)
  clevo_acpi.c             transporte ACPI _DSM
  uniwill_leds.h           LEDs do Uniwill e delegação para o Clevo
  uniwill_wmi.c            transporte WMI do Uniwill
gui/
  teclado-rgb.py           controlador do teclado LED (GTK 3)
  teclado-rgb.desktop      atalho no menu
  avell-kbd-rgb-perms      helper que ajusta as permissões do sysfs
  avell-kbd-rgb-perms.service  oneshot que chama o helper no boot
  99-avell-kbd-rgb.rules   regra udev
instalar.sh                instala os módulos e a configuração
instalar-gui.sh            instala a janela e as permissões
instalar-tudo.sh           instalação completa
desinstalar.sh             remove tudo o que foi instalado
diag-avell.sh              coleta diagnóstico de ACPI, WMI e do LED
teste-ec.sh                compara o acesso por WMI e por portas do EC
teste-onoff.sh             testa apenas ligar/desligar pelo sysfs
teste-teclas.sh            acompanha os eventos das teclas Fn
```

---

## Solução de problemas

**O LED `rgb:kbd_backlight` não aparece**

```bash
lsmod | grep -E "tuxedo_keyboard|uniwill_wmi|clevo_acpi"
cat /etc/modprobe.d/avell-kbd.conf
sudo dmesg | grep -i -E "clevo|uniwill|keyboard"
```

Confirme que o override está gravado e reinicie. Se o `clevo_acpi` não estiver carregado, verifique se o device `CLV0001` existe em `/sys/bus/acpi/devices/`.

**A janela mostra "Sem permissão para controlar o LED"**

```bash
sudo /usr/local/libexec/avell-kbd-rgb-perms
```

Se o usuário acabou de entrar no grupo `plugdev`, é preciso sair e entrar na sessão de novo.

**A janela abre "ligada" com o teclado apagado**

O `systemd-backlight` pode restaurar um valor antigo da escala 0–4. A janela trata valores até 16 como apagado e, ao ligar, usa o brilho máximo.

**Os efeitos não animam**

A animação depende da janela aberta. Se ela parar sozinha, provavelmente uma escrita no sysfs falhou (permissão revogada ou módulo recarregado). Rode o helper de permissões e abra a janela de novo.

**O teclado parou depois de atualizar o kernel**

Os módulos foram compilados para o kernel antigo. Rode `bash instalar-tudo.sh --driver` e reinicie.

---

## Desinstalação

```bash
bash desinstalar.sh
```

O script remove módulos, configuração, janela, regra udev e serviço. Depois é só reiniciar.

---

## Limitações conhecidas

- O teclado tem **uma única zona**. Efeitos por tecla, duas cores simultâneas ou texto rolando pelo teclado são fisicamente impossíveis neste hardware.
- O firmware ignora os modos de efeito nativos; as animações rodam pela janela.
- O aplicativo depende de GTK 3 e PyGObject.

---

## Créditos e licença

- Driver base: [TUXEDO Computers](https://www.tuxedocomputers.com/) — `tuxedo-drivers` v4.24.0, licença GPL-2.0-or-later.
- Adaptação para o Avell Storm 560, investigação do protocolo e janela gráfica: **Alexandre Jazara**, com auxílio do **Qoder (IA)**.
- O código continua aberto: fork, altere e envie suas melhorias.

Este projeto é distribuído sob a **GPL-2.0-or-later**. Veja o arquivo `LICENSE`.

---

## Aviso legal

> **LEIA COM ATENÇÃO:**
>
> 1. **SEM VÍNCULO OFICIAL:** Este repositório é uma iniciativa independente de código aberto. Não possui vínculo comercial, chancela ou suporte da **Avell High Performance** nem da **TUXEDO Computers GmbH**.
> 2. **ISENÇÃO DE RESPONSABILIDADE:** O código foi adaptado e testado apenas no hardware do autor (**Avell Storm 560**, Ryzen 7, RTX 5060, Linux Mint). O autor **não se responsabiliza** por danos diretos ou indiretos, falhas no sistema, instabilidades, congelamentos, danos a componentes ou perda de garantia decorrentes do uso, instalação ou modificação destes drivers.
> 3. **USO POR SUA CONTA E RISCO:** Compilar e carregar módulos modificados no kernel exige consciência dos riscos técnicos envolvidos.
