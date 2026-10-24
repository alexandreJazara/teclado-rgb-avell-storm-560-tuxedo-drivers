# Teclado RGB do Avell Storm 560

Fork do **tuxedo-drivers** da TUXEDO Computers com suporte ao teclado RGB do **Avell Storm 560** (chassi Tongfang/Uniwill) em Linux Mint, Ubuntu e derivados.

**Versão 1.0.0** — atualizada em **24 de outubro de 2026**

## Instalação rápida

```bash
git clone https://github.com/alexandrejazara/tuxedo-drivers-avell-560.git
cd tuxedo-drivers-avell-560
bash instalar-tudo.sh
```

Reinicie depois. O script compila os módulos, instala o driver, grava a configuração persistente (`kbd_type_override=6`) e instala a janela **Teclado RGB** com as permissões de acesso.

Para remover tudo depois:

```bash
bash desinstalar.sh
```

## O que funciona

| Recurso | Situação |
| --- | --- |
| Ligar / desligar (`Fn` + `*`) | Funciona |
| Brilho (`Fn` + `+` / `Fn` + `-`) | Funciona, em 6 degraus visíveis |
| Troca de cor (`Fn` + `/`) | Funciona, percorre 8 cores |
| Janela gráfica "Teclado RGB" | Funciona |
| Cor RGB arbitrária | Funciona |
| Efeitos animados | Em software, com a janela aberta |
| Efeitos nativos do firmware | Aceitos, mas ignorados neste chassi |
| Zonas independentes | Não: o teclado tem uma única zona |

## Documentação completa

Instruções detalhadas de instalação, uso, arquitetura, diagnóstico, limitações e desinstalação estão em:

**[README-jaazara-modification-to-avell-560.md](README-jaazara-modification-to-avell-560.md)**

## Aviso legal

Este é um projeto independente, sem vínculo com a **Avell High Performance** ou a **TUXEDO Computers GmbH**. O código foi testado apenas no hardware do autor. Compilar e carregar módulos modificados no kernel é feito por sua conta e risco. Veja o aviso completo e a licença no [README em português](README-jaazara-modification-to-avell-560.md).

O driver base é da TUXEDO Computers; a adaptação para o Avell Storm 560 e a janela gráfica foram desenvolvidas por **Alexandre Jazara** com auxílio do **Qoder (IA)**, sob a licença GPL-2.0-or-later.

---

# README ORIGIN

# Table of Content
- <a href="#description">Description</a>
- <a href="#building-and-install">Building and Install</a>
- <a href="#troubleshooting">Troubleshooting</a>
- <a href="#regarding-upstreaming-of-tuxedo-drivers">Regarding upstreaming of tuxedo-drivers</a>

# Description
Drivers for several platform devices for TUXEDO notebooks meant for DKMS.

## Features implemented by this driver package
- Fn-keys
- Keyboard backlight
- Fan control
- Power control
- Other sensors
- Hardware specific userspace quirks

## Modules included in this package
- clevo_acpi
- clevo_wmi
- tuxedo_keyboard
- uniwill_wmi
- ite_8291
- ite_8291_lb
- ite_8297
- ite_829x
- tuxedo_io
- tuxedo_compatibility_check
- tuxedo_nb05_keyboard
- tuxedo_nb05_power_profiles
- tuxedo_nb05_ec
- tuxedo_nb05_sensors
- tuxedo_nb04_keyboard
- tuxedo_nb04_wmi_ab
- tuxedo_nb04_wmi_bs
- tuxedo_nb04_sensors
- tuxedo_nb04_power_profiles
- tuxedo_nb04_kbd_backlight
- tuxedo_nb05_kbd_backlight
- tuxedo_nb02_nvidia_power_ctrl
- tuxedo_nb05_fan_control
- tuxi_acpi
- tuxedo_tuxi_fan_control
- stk8321
- gxtp7380

# Building and Install

## Dependencies:
All:
- make

`make package-*`:
- [simple-package-creator](https://gitlab.com/tuxedocomputers/development/packages/simple-package-creator)
- [simple-package-tools](https://gitlab.com/tuxedocomputers/development/packages/simple-package-tools)

# Troubleshooting

## The keyboard backlight control and/or touchpad toggle key combinations do not work
For all devices with a touchpad toggle key(-combo) and some devices with keyboard backlight control key-combos the driver does nothing more then to send the corresponding key event to userspace where it is the desktop environments duty to carry out the action. Some smaller desktop environments however don't bind an action to these keys by default so it seems that these keys don't work.

Please refer to your desktop environments documentation on how to set custom keybindings to fix this.

For keyboard brightness control you should use the D-Bus interface of UPower as actions for the key presses.

For touchpad toggle on X11 you can use `xinput` to enable/disable the touchpad, on Wayland the correct way is desktop environment specific.

# Regarding upstreaming of tuxedo-drivers
The code, while perfectly functional, is currently not in an upstreamable state. That being said we started an upstreaming effort and the first small part, the keyboard backlight control for the Sirius 16 Gen 1 & 2, already got accepted.

If you want to hack away at this matter yourself please follow the following precautions and guidelines to avoid breakages on both software and hardware level:
- Involve us in the whole process. Nothing is won if at some point tuxedo-control-center or the dkms variant of tuxedo-drivers stops working. Especially when you send something to the LKML, please set us in the cc.
- We mostly can't share documentation, but we can answer questions.
- Code interacting with the EC, which is most of tuxedo-drivers, can brick devices and therefore must be ensured to only run on compatible and tested devices.
- If you use tuxedo-drivers as a reference or code snippets from it, a "Codeveloped-by:\<name\> \<tuxedo_email\>" must be included in your upstream commit, with \<name\> and \<tuxedo_email\> depending on the actual part of tuxedo-drivers being used. Please talk to us regarding this.
