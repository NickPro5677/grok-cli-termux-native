# Problemas frecuentes

Cosas que suelen pasar al instalar o al abrir `grok` en Termux. Empieza por la fila que se parezca a tu pantalla.

Primero pasa el chequeo:

```bash
grok --doctor
```

Hace lo mismo el comando `grok-doctor`. Mira el origen de Termux, si puede escribir el archivo DNS, si `api.x.ai` resuelve, si el parche de 16 bytes está puesto y si el móvil es aarch64. Una línea `[FAIL]` dice qué corregir. Cuando lo arregles, vuelve a lanzar `grok --doctor`.

Si el comando `grok` todavía no existe, el mismo chequeo es:

```bash
bash install.sh --doctor
```

| Qué ves | Qué hacer |
| --- | --- |
| `could not resolve host` (o grok no abre ninguna web) | El programa no está leyendo un DNS que funcione. 1) `grok --doctor`. 2) `cat /sdcard/.grokdns` tiene que mostrar al menos una línea `nameserver`. 3) Si el archivo no está, concede el almacenamiento (`termux-setup-storage`, pulsa Permitir) y vuelve a ejecutar `bash install.sh`. 4) Abre `grok` otra vez: el lanzador vuelve a aplicar el cambio de 16 bytes y guarda un `.bak`. 5) Si el archivo existe y la red bloquea esos DNS, mira la fila de DNS bloqueado. |
| Permiso de almacenamiento denegado (`Permission denied`, o el instalador dice `Cannot write /sdcard/.grokdns`) | El instalador se detiene y no dice que grok quedó instalado. En Termux: `termux-setup-storage` y pulsa **Permitir**. Prueba `touch /sdcard/.grokdns`. Si eso falla, activa el permiso a mano: Ajustes → Aplicaciones → Termux → Permisos → Almacenamiento (o Archivos). Luego `bash install.sh` otra vez. `grok --doctor` también avisa si no puede escribir ese archivo. |
| Termux viejo, o `pkg` falla (repositorio, firma, 404, paquetes que no existen) | La app de la Play Store no sirve: instala Termux desde [F-Droid](https://f-droid.org/packages/com.termux/). En un Termux ya actualizado, cambia el espejo y sube los paquetes: `termux-change-repo` (elige un mirror) y después `pkg upgrade`. Vuelve a lanzar el instalador. `grok --doctor` marca la app de la Play Store y una lista de paquetes que apunta a mirrors que ya no sirven, y muestra esos dos comandos. |
| El DNS de siempre va en casa y falla en otra red (datos, instituto, trabajo) | Si no pones `GROK_DNS`, el instalador usa el DNS del teléfono. Si el teléfono no tiene uno, escribe `1.1.1.1` y `8.8.8.8`. Algunas redes bloquean esas direcciones. Para elegir otras: `GROK_DNS="1.1.1.1 8.8.8.8" bash install.sh`. Eso reescribe `/sdcard/.grokdns`. Si no defines `GROK_DNS` y el archivo ya tiene un `nameserver` válido, se queda como está. Una dirección que el instalador no acepta lo detiene y no borra el archivo anterior. Luego `grok --doctor` prueba si `api.x.ai` resuelve. |
| `grok` se queda colgado en el inicio de sesión | Mira si el móvil entra en una web normal. Si el mensaje es `could not resolve host`, usa esa fila. Cierra con `Ctrl+C` y abre `grok` otra vez. Tiene que abrirse el navegador en «Sign in with Grok»; si no se abre, comprueba que hay un navegador y que Termux puede abrir enlaces. Otra vía: una clave de la consola de xAI (`export XAI_API_KEY="tu-clave"`) y de nuevo `grok`. Pasa también `grok --doctor`. |
| Después de `grok update` deja de funcionar | El binario nuevo trae otra vez la ruta `/etc/resolv.conf`. Cierra grok y ejecuta `grok` de nuevo: el lanzador copia la versión nueva, guarda `~/.grok/versions/<versión>.bak` y vuelve a apuntar el programa a `/sdcard/.grokdns`. Comprueba `cat /sdcard/.grokdns` y `grok --doctor`. Si la descarga se cortó, repite `grok update`. Si sigue igual, `bash install.sh` otra vez (es seguro: no sustituye un grok que ya arranca). |
| Xiaomi, Redmi, POCO o Samsung: el permiso no aparece, se quita, o `/sdcard` no se deja escribir | En MIUI y HyperOS el aviso de Termux a veces no sale. Ajustes → Aplicaciones → Termux → Permisos → Almacenamiento, y permite también las ventanas emergentes en segundo plano para que el diálogo pueda mostrarse. En Samsung (One UI) es el mismo permiso; si lo negaste una vez, el aviso no vuelve y hay que activarlo en Ajustes. Después de una actualización del sistema el permiso puede caerse: otra vez `termux-setup-storage` y, si hace falta, `bash install.sh`. |
| Internet inestable o se cortó la luz a mitad de la instalación | Vuelve a ejecutar `bash install.sh`. Se puede repetir. Si un paso falla, el instalador se detiene y no dice que terminó. Si esa misma versión ya está, el parche cuadra y el programa arranca, no la vuelve a bajar. Deja la pantalla encendida hasta que termine. |

Si nada de la tabla encaja, anota el texto exacto del error (sin claves ni datos personales), la salida de `uname -m` y la de `grok --doctor`.
