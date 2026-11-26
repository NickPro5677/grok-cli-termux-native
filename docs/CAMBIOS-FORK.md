# Qué cambia este fork

Este repositorio es un fork de [Thr45hx/grok-cli-termux-native](https://github.com/Thr45hx/grok-cli-termux-native), de Ryan Wylie (Thr45hx), licencia MIT.

La idea es la misma que en el original: ejecutar el `grok` oficial de xAI en Termux (Android aarch64, sin root) cambiando una ruta de 16 bytes, de `/etc/resolv.conf` a `/sdcard/.grokdns`.

En `main`, los scripts siguen siendo los del proyecto original. Los arreglos de abajo van en **otro pull request**, el de los scripts. Hasta que ese PR se fusione, cada uno está marcado **en PR**. Esta documentación no modifica los `.sh`.

| Cambio | Estado | Qué hará |
| --- | --- | --- |
| Parar si no hay permiso de almacenamiento | en PR | Si no puede escribir `/sdcard/.grokdns`, el instalador se detiene y lo dice. No termina con un «instalado» cuando el DNS no se pudo crear. |
| Mostrar los errores | en PR | Un fallo de red, de `pkg` o de permisos se ve en la terminal. El instalador se detiene con ese texto. |
| Instalar las dependencias | en PR | El instalador instala con `pkg` lo que el script necesita (python, curl y las herramientas con las que comprueba el binario) y se detiene si `pkg` no puede. |
| DNS configurable, y el del teléfono si no eliges otro | en PR | Variable `GROK_DNS`. Ejemplo: `GROK_DNS="1.1.1.1 8.8.8.8"`. Si no la defines, el archivo usa el DNS que ya usa el teléfono. Esos servidores se escriben en `/sdcard/.grokdns`. |
| El lanzador comprueba el DNS y vuelve a parchear tras actualizar | en PR | Al abrir `grok`, el lanzador de hoy ya vuelve a poner la ruta de 16 bytes. Este cambio lo refuerza: revisa que `/sdcard/.grokdns` sea válido, tiene en cuenta `GROK_DNS` y repite el parche cuando `grok update` restaura `/etc/resolv.conf`. |
| Doctor | en PR | `grok --doctor`, si está disponible, revisa Termux, la arquitectura, el permiso de almacenamiento, `/sdcard/.grokdns` y el parche, y dice qué falla. |
| CI con shellcheck | en PR | GitHub revisa los scripts con shellcheck en cada cambio, para cazar errores de bash antes de fusionar. |

Cuando uno de esos cambios entre en `main`, esta tabla pasa de **en PR** a **en main**.

Hoy, sin esperar a ese PR, ya puedes:

- instalar desde este fork siguiendo el [README](../README.md) (descargar los archivos, leer `install.sh`, luego `bash install.sh`);
- abrir `grok` después de cada `grok update`, para que el lanzador actual vuelva a aplicar la ruta de 16 bytes;
- cambiar los DNS a mano en `/sdcard/.grokdns` si una red bloquea `8.8.8.8` (ver [PROBLEMAS.md](PROBLEMAS.md)).
