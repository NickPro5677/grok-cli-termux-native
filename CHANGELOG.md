# Changelog

Cambios visibles de este fork. El formato se parece a [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [Unreleased]

### Corregido

- El instalador oficial de xAI y `grok update` dejan un `grok` sin el parche DNS en `~/.grok/bin` y ponen esa carpeta delante de `$PREFIX/bin`. El comando que arranca no es nuestro lanzador, así que `grok --doctor` responde `unexpected argument '--doctor'`. El instalador y el lanzador apartan ese archivo (`grok.viejo`), lo sustituyen por un enlace al lanzador y comentan la línea de PATH en `~/.bashrc`, `~/.profile` y `~/.zshrc`. Tras instalar o actualizar, si hace falta: `hash -r`, o cierra Termux y ábrelo otra vez. `uninstall.sh` restaura las copias. `grok --doctor` falla si otro `grok` sigue delante, e indica el arreglo `mv ~/.grok/bin/grok ~/.grok/bin/grok.viejo; hash -r`.
- `GROK_CHANNEL=alpha bash install.sh` instala el canal alpha (en noviembre de 2026, stable es 1.0.92 y alpha es 1.0.94). `grok update` sigue el canal elegido. `--stable` o `--alpha` en ese comando lo cambian.

### Cambiado

- La instalación del README baja solo `install.sh`. El script descarga de `main`, si faltan, `common.sh`, `launcher.sh`, `grok-dns.py`, `grok-doctor.sh` y `uninstall.sh`.
- También se documenta clonar el repositorio con git.
- `grok --doctor` y `grok-doctor` son la comprobación normal. Ya no se presentan como «si está disponible».
- Los arreglos de scripts pasan de «en PR» a **hecho**.

### Hecho (scripts, PR #2, `a9ffb93`)

- El instalador se detiene si no puede escribir `/sdcard/.grokdns`. Pide `termux-setup-storage` y no anuncia que la instalación terminó.
- Los errores de red, paquetes y permisos se muestran, y el instalador se detiene.
- Dependencias que instala: `python`, `curl`, `file` y `coreutils`.
- `GROK_DNS` elige los servidores. Si no se define, se usa el DNS del teléfono; si no hay, `1.1.1.1` y `8.8.8.8`.
- El lanzador comprueba el DNS y vuelve a aplicar el parche de 16 bytes después de `grok update`. Guarda una copia `.bak` del programa antes del cambio.
- Comprobaciones `grok --doctor` y `grok-doctor`.
- CI con shellcheck y las pruebas de `tests/`.
- Volver a ejecutar `bash install.sh` es seguro.

### Añadido

- README en español, con un resumen corto en inglés, crédito y enlace al autor original [Ryan Wylie (Thr45hx)](https://github.com/Thr45hx/grok-cli-termux-native), y la licencia MIT. Entró en el PR #1 (`b241744`).
- [docs/PROBLEMAS.md](docs/PROBLEMAS.md): tabla de fallos frecuentes (DNS, almacenamiento, mirrors de Termux, redes que bloquean el DNS, login, actualización, Xiaomi/Samsung, cortes de luz).
- [docs/CAMBIOS-FORK.md](docs/CAMBIOS-FORK.md): diferencias de este fork frente al upstream.
