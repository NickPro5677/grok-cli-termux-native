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

Hazlo en Termux, desde este fork. Son cuatro pasos: permiso, descargar, leer, ejecutar.

1. Permiso de almacenamiento (si aún no lo diste):

   ```bash
   termux-setup-storage
   ```

2. Carpeta de trabajo y los archivos de **este** repositorio:

   ```bash
   pkg update && pkg install -y curl
   mkdir -p ~/grok-termux
   cd ~/grok-termux
   curl -fsSL -o install.sh https://raw.githubusercontent.com/NickPro5677/grok-cli-termux-native/main/install.sh
   curl -fsSL -o launcher.sh https://raw.githubusercontent.com/NickPro5677/grok-cli-termux-native/main/launcher.sh
   curl -fsSL -o grok-dns.py https://raw.githubusercontent.com/NickPro5677/grok-cli-termux-native/main/grok-dns.py
   ```

   `launcher.sh` y `grok-dns.py` tienen que estar en la misma carpeta que `install.sh`. El instalador usa esos dos archivos de al lado. Si no los encuentra, los baja del proyecto original (Thr45hx), y entonces no estás instalando este fork.

   Si `pkg` o `curl` muestran un error, para aquí y mira [docs/PROBLEMAS.md](docs/PROBLEMAS.md). Con un error de descarga, no ejecutes el script: espera y vuelve a bajarlo.

3. Lee `install.sh` entero antes de ejecutarlo. Puedes subir y bajar en la pantalla de Termux:

   ```bash
   cat install.sh
   ```

   Ahí se ve qué paquetes instala, de dónde baja `grok` y qué escribe (`~/agents/grok`, `~/.grok` y `/sdcard/.grokdns`).

4. Cuando el texto te cuadre:

   ```bash
   bash install.sh
   ```

Al terminar puedes escribir `grok` en cualquier carpeta de Termux.

### Por qué no usar `curl | bash`

Este atajo es habitual y es mejor evitarlo:

```bash
curl -fsSL https://ejemplo/install.sh | bash
```

La tubería (`|`) manda el archivo al intérprete **mientras llega**. No hay un momento para leerlo. Si la descarga se corta a la mitad, si la dirección no es la que crees, o si el archivo cambia entre que lo miras en el navegador y lo ejecutas, el teléfono corre un script que no revisaste. Puede instalar paquetes, escribir en el almacenamiento y bajar un programa.

Guardar el archivo, leerlo con `cat` y luego lanzarlo con `bash install.sh` separa esas dos cosas: primero ves el texto, después decides.

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

La actualización baja un binario nuevo. Ese archivo vuelve a traer la ruta original `/etc/resolv.conf`. Ciérralo y ábrelo otra vez con `grok`. El lanzador (`~/agents/grok/launcher.sh`) adopta la versión nueva y **vuelve a aplicar el cambio de 16 bytes**. Si `/sdcard/.grokdns` desapareció, también lo crea de nuevo.

## Desinstalar

En la misma carpeta (o en una nueva), baja el script, léelo y ejecútalo:

```bash
cd ~/grok-termux
curl -fsSL -o uninstall.sh https://raw.githubusercontent.com/NickPro5677/grok-cli-termux-native/main/uninstall.sh
cat uninstall.sh
bash uninstall.sh
```

Quita el comando `grok`, la carpeta `~/agents/grok`, las versiones en `~/.grok/versions` y el archivo `/sdcard/.grokdns`.

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

Después escribe `/sdcard/.grokdns` con los servidores DNS. Hoy el archivo queda así:

```text
nameserver 8.8.8.8
nameserver 8.8.4.4
```

A partir de ahí, cuando `grok` necesita un nombre, lee ese archivo. Las conexiones cifradas (HTTPS) ya funcionaban: el programa trae sus propios certificados. Solo había que arreglar el DNS.

Cada vez que arrancas `grok`, el lanzador comprueba el binario y, si hace falta, repite el cambio. Por eso sobrevive a `grok update`.

Si el teléfono tiene root y ya existe un `/etc/resolv.conf` con una línea `nameserver`, el lanzador deja el programa sin tocar y usa esa ruta del sistema.

Dónde queda cada cosa:

| Ruta | Para qué |
| --- | --- |
| `~/.grok/versions/` | Copias del programa `grok` |
| `~/agents/grok/launcher.sh` | Lo que de verdad arranca el comando `grok` |
| `/sdcard/.grokdns` | Servidores DNS (solo sin root) |
| `~/.grok` | Sesión y ajustes |

## Licencia

[MIT](./LICENSE). Copyright (c) 2026 Ryan Wylie (Thr45hx).

Proyecto original: [github.com/Thr45hx/grok-cli-termux-native](https://github.com/Thr45hx/grok-cli-termux-native).
