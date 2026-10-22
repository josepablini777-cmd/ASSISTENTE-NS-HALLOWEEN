# c00lgui – panel lanzador con skins de asistentes

Panel para Windows que abre YouTube, las apps de Office y otros programas con un clic.
Tiene tres skins, cada una con su propio estilo, animaciones y diálogos:

| Skin | Estilo | Efecto al entrar |
|---|---|---|
| **c00lgui** | Panel hacker de c00lkidd (Roblox): negro y rojo | Glitch: la ventana tiembla y salen errores falsos |
| **SeaDrive** | Asistente de YonKaGor, con aspecto de página web | Carga como una web: URL, barra de progreso… |
| **Static Miku** | Miku de Flavor Foley, como un dibujo animado en una tele vieja | Estática de tele y encendido desde el centro |

## Cómo descargarlo

1. Pulsa el botón verde **Code** → **Download ZIP**.
2. Descomprime el ZIP en cualquier carpeta.
3. Haz doble clic en **`c00lgui.vbs`**.

Si Windows muestra un aviso de seguridad, pulsa **Más información → Ejecutar de todas formas**.

No hace falta instalar nada: funciona con PowerShell, que ya viene con Windows 10 y 11.

## Cómo se usa

- **Botones:** abren la app. Si una app de Office no está instalada, se abre su versión web.
- **`<` y `>`:** cambian de página.
- **Skins:** elige otra skin. Se recuerda para la próxima vez.
- **Mover la ventana:** arrástrala desde el título.
- **Asistente:** haz clic en el GIF de SeaDrive o de Miku y te contestan.

## Añadir tus propios botones

Abre `c00lgui.ps1` con el Bloc de notas y busca la lista `$Botones` al principio. Añade una línea como esta:

```powershell
@{ Nombre = 'Roblox'; Abrir = 'https://www.roblox.com' }
```

Las frases de cada asistente están en la sección `SKINS` del mismo archivo.

## Créditos

- **c00lkidd / c00lgui:** personaje y estética de Roblox.
- **SeaDrive:** personaje de [YonKaGor](https://www.youtube.com/@YonKaGor), de la canción *Top 10 Things To Do Before You Die*. GIF de [Tenor](https://tenor.com/view/seadrive-seadrive-yonkagor-yonkagor-seadrive-yonkagor-furry-gif-13965177036432532238).
- **Static Miku:** personaje de [Flavor Foley](https://flavorfoley.com/FFF/st/), del videoclip *Static*. GIFs de Tenor.

Proyecto de fans sin ánimo de lucro. Los personajes pertenecen a sus autores.
