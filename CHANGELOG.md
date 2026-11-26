# Changelog

Cambios visibles de este fork. El formato se parece a [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [Unreleased]

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
