# Changelog

Cambios visibles de este fork. El formato se parece a [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

Los arreglos de los scripts van en otro pull request. Aquí figuran como **en PR** hasta que se fusionen en `main`.

## [Unreleased]

### Añadido

- README en español, con un resumen corto en inglés, crédito y enlace al autor original [Ryan Wylie (Thr45hx)](https://github.com/Thr45hx/grok-cli-termux-native), y la licencia MIT.
- Instalación paso a paso desde este fork: descargar `install.sh` con `curl`, leerlo y ejecutarlo con `bash install.sh`, y por qué `curl | bash` es arriesgado.
- [docs/PROBLEMAS.md](docs/PROBLEMAS.md): tabla de fallos frecuentes (DNS, almacenamiento, mirrors de Termux, redes que bloquean el DNS, login, actualización, Xiaomi/Samsung, cortes de luz). Incluye `grok --doctor` si está disponible.
- [docs/CAMBIOS-FORK.md](docs/CAMBIOS-FORK.md): diferencias previstas frente al upstream.

### En PR (scripts; todavía no están en `main`)

- El instalador se detiene si no puede escribir `/sdcard/.grokdns`.
- Los errores de red, paquetes y permisos se muestran.
- El instalador instala las dependencias y se detiene si `pkg` falla.
- `GROK_DNS` configurable. Si no se define, se usa el DNS del teléfono.
- El lanzador comprueba el DNS y vuelve a aplicar el parche de 16 bytes después de `grok update`.
- Comprobación `grok --doctor`, si está disponible.
- CI con shellcheck.
