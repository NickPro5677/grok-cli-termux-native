# Qué cambia este fork

Este repositorio es un fork de [Thr45hx/grok-cli-termux-native](https://github.com/Thr45hx/grok-cli-termux-native), de Ryan Wylie (Thr45hx), licencia MIT.

La idea es la misma que en el original: ejecutar el `grok` oficial de xAI en Termux (Android aarch64, sin root) cambiando una ruta de 16 bytes, de `/etc/resolv.conf` a `/sdcard/.grokdns`.

Los arreglos de los scripts ya están en `main`. Entraron en el pull request **#2** (merge `a9ffb93`). En la tabla figuran como **hecho**.

| Cambio | Estado | Qué hace |
| --- | --- | --- |
| Parar si no hay permiso de almacenamiento | hecho (PR #2) | Si no puede escribir `/sdcard/.grokdns`, el instalador se detiene con un error y pide `termux-setup-storage`. No dice que grok quedó instalado. |
| Mostrar los errores | hecho (PR #2) | Un fallo de red, de `pkg` o de permisos se ve en la terminal. El instalador se detiene con ese texto y no anuncia el éxito. |
| Instalar las dependencias | hecho (PR #2) | El instalador ejecuta `pkg install -y python curl file coreutils` y se detiene si `pkg` no puede. Después comprueba que existan `python3`, `curl`, `file`, `timeout` y `sort`. |
| DNS configurable, y el del teléfono si no eliges otro | hecho (PR #2) | Variable `GROK_DNS`, una lista de direcciones separadas por espacios. Ejemplo: `GROK_DNS="1.1.1.1 8.8.8.8" bash install.sh`. Si no la defines, usa el DNS del teléfono (`net.dns1` y `net.dns2`). Si el teléfono no tiene uno, escribe `1.1.1.1` y `8.8.8.8` en `/sdcard/.grokdns`. Un archivo que ya tiene un `nameserver` válido se conserva, salvo que definas `GROK_DNS`. |
| El lanzador comprueba el DNS y vuelve a parchear tras actualizar | hecho (PR #2) | Al abrir `grok`, el lanzador revisa `/sdcard/.grokdns` y vuelve a cambiar los 16 bytes si `grok update` restauró `/etc/resolv.conf`. Antes de parchear guarda una copia del mismo tamaño en `~/.grok/versions/<versión>.bak`. |
| Doctor | hecho (PR #2) | Existen `grok --doctor` y el comando `grok-doctor`. También vale `bash install.sh --doctor`. Revisan el origen de Termux, el permiso de almacenamiento, el archivo DNS, si `api.x.ai` resuelve, el parche del binario y que el móvil sea aarch64. |
| CI con shellcheck | hecho (PR #2) | GitHub Actions (`.github/workflows/ci.yml`) pasa shellcheck por los scripts y corre las pruebas en `tests/`. |
| Repetir el instalador | hecho (PR #2) | `bash install.sh` se puede ejecutar otra vez. Si esa versión ya está y arranca, no la vuelve a bajar. Una descarga a medias no sustituye a un grok que ya funcionaba. |

La guía de instalación está en el [README](../README.md). Si algo falla, [PROBLEMAS.md](PROBLEMAS.md).
