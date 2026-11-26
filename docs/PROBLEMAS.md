# Problemas frecuentes

Cosas que suelen pasar al instalar o al abrir `grok` en Termux. Empieza por la fila que se parezca a tu pantalla.

Comprobación rápida, **si está disponible** en tu versión:

```bash
grok --doctor
```

Ese comando llega con los cambios de los scripts de este fork (siguen **en PR**; ver [CAMBIOS-FORK.md](CAMBIOS-FORK.md)). Si la terminal dice que no conoce `--doctor`, usa la tabla.

| Qué ves | Qué hacer |
| --- | --- |
| `could not resolve host` (o grok no abre ninguna web) | El programa no está leyendo un DNS. 1) `cat /sdcard/.grokdns` tiene que mostrar al menos una línea `nameserver`. 2) Si el archivo no está o no se puede leer, concede el almacenamiento (`termux-setup-storage`, pulsa Permitir) y vuelve a ejecutar `bash install.sh`. 3) Abre `grok` otra vez: el lanzador vuelve a aplicar el cambio de 16 bytes. 4) Si el archivo existe y la red bloquea esos DNS, mira la fila de DNS bloqueado. |
| Permiso de almacenamiento denegado (`Permission denied` al escribir `/sdcard/.grokdns`, o el instalador avisa de que no puede crear ese archivo) | En Termux: `termux-setup-storage` y pulsa **Permitir**. Prueba `touch /sdcard/.grokdns`. Si eso falla, activa el permiso a mano: Ajustes → Aplicaciones → Termux → Permisos → Almacenamiento (o Archivos). Luego `bash install.sh` otra vez. Hasta que se fusione el arreglo, el instalador de `main` puede seguir y decir «instalado» aunque no haya podido escribir el archivo: si después sale `could not resolve host`, era esto. |
| Termux viejo, o `pkg` falla (repositorio, firma, 404, paquetes que no existen) | La app de la Play Store no sirve: instala Termux desde [F-Droid](https://f-droid.org/packages/com.termux/). En un Termux ya actualizado, cambia el espejo y sube los paquetes: `termux-change-repo` (elige un mirror) y después `pkg upgrade`. Vuelve a lanzar el instalador. |
| El DNS de siempre va en casa y falla en otra red (datos, instituto, trabajo) | Algunas redes bloquean `8.8.8.8` y `8.8.4.4`, que son los que escribe el instalador de hoy. Edita el archivo y deja servidores que esa red deje pasar, por ejemplo: `printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /sdcard/.grokdns`. El lanzador respeta el archivo si ya tiene una línea `nameserver`. Cuando el cambio esté fusionado podrás hacer lo mismo con la variable `GROK_DNS="1.1.1.1 8.8.8.8"` antes de instalar o de abrir `grok`. Si no la pones, usará el DNS del teléfono. Sigue **en PR**. |
| `grok` se queda colgado en el inicio de sesión | Mira si el móvil entra en una web normal. Si el mensaje es `could not resolve host`, usa esa fila. Cierra con `Ctrl+C` y abre `grok` otra vez. Tiene que abrirse el navegador en «Sign in with Grok»; si no se abre, comprueba que hay un navegador y que Termux puede abrir enlaces. Otra vía: una clave de la consola de xAI (`export XAI_API_KEY="tu-clave"`) y de nuevo `grok`. `grok --doctor` si está disponible. |
| Después de `grok update` deja de funcionar | El binario nuevo trae otra vez la ruta `/etc/resolv.conf`. Cierra grok y ejecuta `grok` de nuevo: el lanzador copia la versión nueva y vuelve a apuntar el programa a `/sdcard/.grokdns`. Comprueba `cat /sdcard/.grokdns`. Si la descarga se cortó, repite `grok update`. Si sigue igual, `bash install.sh` otra vez (es seguro). |
| Xiaomi, Redmi, POCO o Samsung: el permiso no aparece, se quita, o `/sdcard` no se deja escribir | En MIUI y HyperOS el aviso de Termux a veces no sale. Ajustes → Aplicaciones → Termux → Permisos → Almacenamiento, y permite también las ventanas emergentes en segundo plano para que el diálogo pueda mostrarse. En Samsung (One UI) es el mismo permiso; si lo negaste una vez, el aviso no vuelve y hay que activarlo en Ajustes. Después de una actualización del sistema el permiso puede caerse: otra vez `termux-setup-storage` y, si hace falta, `bash install.sh`. |
| Internet inestable o se cortó la luz a mitad de la instalación | Vuelve a ejecutar `bash install.sh` en la misma carpeta. Se puede repetir: la descarga nueva sustituye a la que quedó a medias, y el programa solo se da por instalado si arranca. Deja la pantalla encendida hasta que termine. |

Si nada de la tabla encaja, anota el texto exacto del error (sin claves ni datos personales) y la salida de `uname -m`.
