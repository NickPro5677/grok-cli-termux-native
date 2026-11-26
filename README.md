# grok en Termux

**English:** This fork runs xAI's Grok Build CLI (`grok`) natively on Termux (Android aarch64, no root). One 16-byte path change makes DNS read `/sdcard/.grokdns` instead of `/etc/resolv.conf`. Original project by [Ryan Wylie (Thr45hx)](https://github.com/Thr45hx/grok-cli-termux-native). [MIT](./LICENSE) license. The guide below is in Spanish.

Guía corta para instalar el comando `grok` en el móvil, sin root. El proyecto original es de Ryan Wylie ([Thr45hx/grok-cli-termux-native](https://github.com/Thr45hx/grok-cli-termux-native)), licencia [MIT](./LICENSE). Esto es un fork: [NickPro5677/grok-cli-termux-native](https://github.com/NickPro5677/grok-cli-termux-native). No está afiliado con xAI.

Si algo falla, mira [docs/PROBLEMAS.md](docs/PROBLEMAS.md). Lo que este fork cambia está en [docs/CAMBIOS-FORK.md](docs/CAMBIOS-FORK.md).

## Qué es

Grok Build es el programa de terminal de xAI. El comando se llama `grok`.

En Termux (la app de terminal para Android) ese programa ya puede abrirse tal cual: viene preparado para el procesador del móvil. Funciona en un Termux normal, con tu usuario, sin cuenta de administrador (root) y sin montar otro Linux dentro (proot).

Solo falla el DNS, el paso que convierte un nombre (`x.ai`) en una dirección. El programa busca un archivo del sistema, `/etc/resolv.conf`, y en Termux esa ruta no se puede crear. El instalador apunta esa búsqueda a `/sdcard/.grokdns`, un archivo que sí puedes escribir. Más abajo está la explicación corta.

![Grok ya instalado, explicando por qué corre nativo en Termux](screenshots/grok-explains-native.png)

## Requisitos

- **Termux de [F-Droid](https://f-droid.org/packages/com.termux/).** Instala esa app. La copia de la Play Store lleva años sin actualizarse y sus paquetes no sirven.
- **Móvil aarch64** (arm64, el procesador de casi todos los teléfonos actuales). En Termux:

  ```bash
  uname -m
  ```

  Tiene que salir `aarch64`.
- **Permiso de almacenamiento.** El DNS se guarda en `/sdcard/.grokdns`. En Termux:

  ```bash
  termux-setup-storage
  ```

  Pulsa **Permitir**. Sin ese permiso la instalación no puede dejar el archivo de DNS.
- **Internet** la primera vez: hay que descargar el programa.

## Instalación

Hazlo en Termux, desde este fork. Solo descargas `install.sh`. Si en esa carpeta faltan los demás archivos, el instalador los baja de `main`: `common.sh`, `launcher.sh`, `grok-dns.py`, `grok-doctor.sh` y `uninstall.sh`.

Haz los comandos de uno en uno. `termux-setup-storage` espera a que pulses Permitir, y `less` espera a que pulses `q`.

```bash
pkg update && pkg install -y curl
termux-setup-storage
curl -fsSL -o install.sh https://raw.githubusercontent.com/NickPro5677/grok-cli-termux-native/main/install.sh
less install.sh
bash install.sh
grok --doctor
```

- `pkg update && pkg install -y curl` deja `curl` listo para bajar el script. Dentro de `bash install.sh` se instalan también `python`, `curl`, `file` y `coreutils`.
- `termux-setup-storage` pide el permiso de almacenamiento. Sin él el instalador se detiene y no dice que grok quedó instalado.
- `curl` guarda `install.sh` en la carpeta actual. No lo ejecuta.
- `less install.sh` muestra el script. Léelo: se ve qué paquetes instala, de dónde baja `grok` y qué escribe (`~/agents/grok`, `~/.grok/versions` y `/sdcard/.grokdns`). `q` sale de `less`.
- `bash install.sh` instala. Se puede repetir. Si esa versión ya está y arranca, no la vuelve a bajar. Si un paso falla, se detiene y no anuncia que terminó.
- `grok --doctor` revisa el teléfono (almacenamiento, DNS, el parche y que sea aarch64). El mismo chequeo es el comando `grok-doctor`.

Si `pkg` o `curl` muestran un error, para y mira [docs/PROBLEMAS.md](docs/PROBLEMAS.md). Si la descarga falla, no ejecutes el script: espera y vuelve a bajarlo.

### Otra forma: clonar el repositorio

```bash
pkg update && pkg install -y git
termux-setup-storage
git clone https://github.com/NickPro5677/grok-cli-termux-native
cd grok-cli-termux-native
less install.sh
bash install.sh
grok --doctor
```

En el clon, los ayudantes ya están junto a `install.sh`, así que no los vuelve a descargar. Léelo igual antes de ejecutarlo.

### Por qué no usar `curl | bash`

Este atajo es habitual y es mejor evitarlo:

```bash
curl -fsSL https://ejemplo/install.sh | bash
```

La tubería (`|`) manda el archivo al intérprete **mientras llega**. No hay un momento para leerlo. Si la descarga se corta a la mitad, si la dirección no es la que crees, o si el archivo cambia entre que lo miras en el navegador y lo ejecutas, el teléfono corre un script que no revisaste. Puede instalar paquetes, escribir en el almacenamiento y bajar un programa.

Guardar el archivo, leerlo con `less` y luego lanzarlo con `bash install.sh` separa esas dos cosas: primero ves el texto, después decides.

## Primer uso e inicio de sesión

Abre el programa:

```bash
grok
```

La primera vez pide **Sign in with Grok**. Se abre el navegador del teléfono, entras en tu cuenta y vuelves a Termux.

Si prefieres una clave de API (empieza por `xai-`, se crea en la consola de xAI, [console.x.ai](https://console.x.ai)):

```bash
export XAI_API_KEY="tu-clave"
grok -p "hola desde Termux"
```

La clave solo vive en esa sesión de Termux. No la pegues en un archivo que vayas a subir a internet ni se la pases a nadie.

## Actualizar

Dentro de grok, `Ctrl+U`. Desde la terminal:

```bash
grok update
```

La actualización baja un binario nuevo. Ese archivo vuelve a traer la ruta original `/etc/resolv.conf`. Ciérralo y ábrelo otra vez con `grok`. El lanzador (`~/agents/grok/launcher.sh`) adopta la versión nueva y **vuelve a aplicar el cambio de 16 bytes**. Antes de tocar el programa guarda una copia `.bak` a su lado, por ejemplo `~/.grok/versions/1.2.3.bak`, con el archivo de antes del parche. Si `/sdcard/.grokdns` desapareció o no tiene un `nameserver` válido, también lo crea de nuevo.

## Desinstalar

El instalador deja el script junto a `common.sh`. Léelo y ejecútalo desde ahí:

```bash
less ~/agents/grok/uninstall.sh
bash ~/agents/grok/uninstall.sh
```

Quita los comandos `grok` y `grok-doctor`, la carpeta `~/agents/grok`, las versiones en `~/.grok/versions` (también los `.bak`) y el archivo `/sdcard/.grokdns`.

Deja la sesión y los ajustes en `~/.grok`. Para borrar eso también:

```bash
rm -rf ~/.grok
```

## Cómo funciona el truco de 16 bytes

El programa tiene escrita, por dentro, esta ruta:

```text
/etc/resolv.conf
```

Son 16 caracteres. En un móvil sin root, Termux no puede crear ese archivo: `/etc` apunta al sistema, que es de solo lectura.

Esta otra ruta mide **los mismos 16 caracteres**:

```text
/sdcard/.grokdns
```

El instalador cambia un texto por el otro, en el mismo sitio, letra por letra. Como miden igual, el resto del programa no se mueve. Es como cambiar una palabra por otra del mismo tamaño: las líneas de debajo siguen donde estaban.

Después escribe `/sdcard/.grokdns` con los servidores DNS. Si no defines `GROK_DNS`, usa los del teléfono. Si el teléfono no tiene ninguno, el archivo queda así:

```text
nameserver 1.1.1.1
nameserver 8.8.8.8
```

Para elegirlos tú, antes de instalar o si quieres reescribir el archivo:

```bash
GROK_DNS="1.1.1.1 8.8.8.8" bash install.sh
```

Si `/sdcard/.grokdns` ya tiene una línea `nameserver` válida y no pones `GROK_DNS`, ese archivo se queda como está.

A partir de ahí, cuando `grok` necesita un nombre, lee ese archivo. Las conexiones cifradas (HTTPS) ya funcionaban: el programa trae sus propios certificados. Solo había que arreglar el DNS.

Cada vez que arrancas `grok`, el lanzador comprueba el binario y, si hace falta, repite el cambio y guarda el `.bak`. Por eso sobrevive a `grok update`.

Si el teléfono tiene root y ya existe un `/etc/resolv.conf` con una línea `nameserver`, el lanzador deja el programa sin tocar y usa esa ruta del sistema.

Dónde queda cada cosa:

| Ruta | Para qué |
| --- | --- |
| `~/.grok/versions/` | Copias del programa `grok` |
| `~/.grok/versions/<versión>.bak` | Copia de antes del parche DNS |
| `~/agents/grok/launcher.sh` | Lo que de verdad arranca el comando `grok` |
| `~/agents/grok/grok-doctor.sh` | El comando `grok-doctor` |
| `/sdcard/.grokdns` | Servidores DNS (solo sin root) |
| `~/.grok` | Sesión y ajustes |

## Licencia

[MIT](./LICENSE). Copyright (c) 2026 Ryan Wylie (Thr45hx).

Proyecto original: [github.com/Thr45hx/grok-cli-termux-native](https://github.com/Thr45hx/grok-cli-termux-native).
