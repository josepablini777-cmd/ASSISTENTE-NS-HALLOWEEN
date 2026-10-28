# CLAUDE.md – guía del código de c00lgui

Instrucciones para Claude (o cualquiera) que vaya a modificar este proyecto. Léelo entero antes de tocar nada.

## Qué es

c00lgui es un panel lanzador para Windows (abre YouTube, Office, programas…) con **skins**: cada skin es un personaje (de YouTube, Roblox, videojuegos…) con su propio aspecto, intro animada, frases, sonidos y minijuego. Los personajes opinan unos de otros y discuten entre ellos.

- Todo el programa está en **un solo archivo: `c00lgui.ps1`** (PowerShell 5.1 + WinForms + System.Drawing, unas 8000 líneas).
- `c00lgui.vbs` lo abre sin ventana de consola (es lo que se ejecuta con doble clic).
- `skins\<carpeta>\` tiene las imágenes (png/jpg/gif) y sonidos (wav/mp3) de cada skin.
- `README.md`: instrucciones para el usuario y **notas del parche** (añade una sección nueva arriba con cada versión).

## Sobre el usuario

- Habla **español**, no es programador y es gamer. Contesta en español sencillo, sin jerga.
- Trabaja también **desde otro PC**: haz siempre `git pull` antes de empezar.
- **No subas a GitHub hasta que lo pida.** Cuando lo pida: commit con mensaje en español (`vX.Y: resumen` + lista) y actualiza las notas del parche del README.
- Suele dejar imágenes y audios en `%USERPROFILE%\Downloads`. Cópialos (convertidos/reducidos) a la carpeta de la skin; no uses los originales tal cual si son enormes.
- Al terminar un cambio, ábrele el panel para que lo vea:
  `Start-Process wscript.exe -ArgumentList '"<ruta>\c00lgui.vbs"'` (antes cierra el que esté abierto).

## Reglas que no se pueden romper

1. **Codificación:** `c00lgui.ps1` debe guardarse en **UTF-8 con BOM** y finales de línea **CRLF**. Sin BOM, PowerShell 5.1 rompe las tildes y la ñ. Si lo editas con un script (Python), lee con `utf-8-sig` y escribe `b'\xef\xbb\xbf' + texto.replace('\n', '\r\n')`.
2. **Comprueba la sintaxis** después de cada cambio:
   `[System.Management.Automation.Language.Parser]::ParseFile('c00lgui.ps1',[ref]$null,[ref]$e); $e.Count` → tiene que dar 0.
3. **PowerShell no distingue mayúsculas en las variables:** `$T` y `$t` son la misma. Ya causó un fallo (una intro dejó de dibujarse). Usa nombres distintos de verdad.
4. **La coma pesa más que `-bor`:** escribe `Fnt('Arial', 12, ([FontStyle]::Bold -bor [FontStyle]::Italic))`, con paréntesis.
5. **Listas de listas:** en `@( @('a','b') @('c','d') )` PowerShell junta todo en una lista plana. Pon una coma delante de cada sublista: `@( , @('a','b') , @('c','d') )` (así están `$Discusiones` y `$TextoTutorial`).
6. **Variables de los eventos:** lo que usen los temporizadores y los clics tiene que ser `$script:algo`.
7. **Audio:** el panel reproduce **WAV** (SoundPlayer) y **MP3** (MediaPlayer). **OGG no funciona**: conviértelo a WAV (mono para que pese menos).
8. **Imágenes:** antes de liberar una imagen que esté en un PictureBox, pon `.Image = $null` (si no, sale la ventana de error al cambiar de skin).
9. No subas los archivos personales: `skin.txt`, `ajustes.txt` y `botones.txt` (ya están en `.gitignore`).
10. **`[Math]::Min`/`Max` con un número entero redondea:** `[Math]::Min(110, 30.3)` da **30**. Si el otro valor tiene decimales, escribe el número con decimales: `[Math]::Min(110.0, $x + 0.3)`. Este fallo dejó a Pursuer sin recuperar estamina y a varias barras sin bajar nunca.
11. **Bocadillo:** `Decir` escribe según el tiempo (no se ralentiza aunque haya muchos efectos). Para frases que no se deben cortar (explosiones, modos especiales, finales de minijuego) usa `Decir-Fijo`: bloquea las demás frases hasta que se haya podido leer.
12. **Ventanitas con fundido:** no dejes la `Opacity` de un formulario en 1.0 después de animarla; déjala en 0.99 (al pasar a 1.0 Windows deja de pintarla hasta que le haces clic).

13. **Modo seguro (epilepsia):** `$script:aj.Epilepsia` quita intros, temblores (`Sacudir`), glitch, estática y destellos. Si añades un efecto que parpadee, haga flash o cambie de color de golpe, pon su variable a 0 en `Sin-Destellos` (se llama en cada fotograma). Los temblores nuevos deben usar `Sacudir` y las intros deben arrancar desde `Efecto-Entrada`, que ya respetan el modo seguro.
14. **Arranque:** al abrir sale siempre el aviso de epilepsia (`Mostrar-Aviso`); al cerrarlo, `Arranque` pone el logo, la intro y la guía del panda. Sin `skin.txt` (la primera vez) la skin es **SeaDrive**, la más tranquila.

## Escalado (DPI)

Todo se diseña a **tamaño base** y se escala una vez:
- `$script:K` = escala de la pantalla × tamaño elegido en Ajustes.
- `Fnt(...)` crea fuentes ya escaladas (para controles). `FntP(...)` crea fuentes a tamaño base (para dibujar dentro de un `Paint` que ya hace `ScaleTransform($K)`).
- `Escalar $control` escala un control y sus hijos. El panel mide 760×320 de base en las skins nuevas.
- Dentro de los `Paint` del formulario, las coordenadas son de tamaño base (0..760, 0..320).

## Estructura de `c00lgui.ps1` (busca estos títulos `# =====`)

| Sección | Qué hay |
|---|---|
| AJUSTES | `$script:aj` (sonido, volumen, intros, tamaño…), `Cargar-Ajustes` / `Guardar-Ajustes` → `ajustes.txt` |
| BOTONES | `$BotonesDeSerie`, `Cargar-Botones` / `Guardar-Botones` → `botones.txt` (`Nombre \| abre \| web`) |
| SKINS | guía para añadir skins + el gran diccionario `$Skins` (una entrada por skin) |
| GRUPOS DEL MENÚ SKINS | `$GruposSkins`: grupos del menú y "de dónde viene" cada skin |
| DIÁLOGOS | `Decir` (bocadillo con máquina de escribir, `$twTimer`), `Opinion`, `Saludo`, bocas que se mueven al hablar (campo `Habla`) |
| Secciones por personaje | la mecánica de cada skin (Guillotina, Mikaela, Zodiac… Kevin, Kennyoung) |
| PERSONAJES DIBUJADOS | sistema de **actores**: `Nuevo-Actor`, `Actor-Pose`, `Pintar-Actores`, `$actTimer` (anima los GIF) |
| ANIMACIÓN DE FONDO | `$ambTimer` (cada 50 ms): llama al "tick" de cada skin (`Kevin-Tick`, `Ky-Tick`…) |
| DISCUSIONES | `$Discusiones` (se carga de `dialogos\_charlas.json` con `Cargar-Dialogos`), ventanita del invitado (`Abrir-Invitado`, `Pintar-Invitado`), `Efectos-Linea` (sonidos/temblores según palabras), `$idleTimer` (frases sueltas) |
| GLITCH / TRANSICIONES / INTROS | `Intro-Overlay` y una función `Transicion-*` por skin |
| LÓGICA | `Nuevo-Boton`, `Pintar-Boton`, `Lanzar` (abrir una app), `Mostrar-Pagina` (botones o menú Skins), `Efecto-Entrada` |
| AJUSTES / EDITOR DE BOTONES / TUTORIAL | ventanas de configuración |
| VENTANA | `$form`, su `Paint` (dibujo de cada estilo), ratón (`$mDown`, `Clic-Actor`), `Construir-UI` (monta la skin) |

## Cómo funciona una skin

Cada skin es una entrada de `$Skins` con, entre otros:
- `Estilo`: palabra corta y **única** (`'punk'`, `'pizza'`, `'mew'`…). Es la llave que usan todos los `switch` del código.
- Colores (`Fondo`, `Borde`, `Btn*`…), `Ancho`/`Alto`, `Fuente`, `Burbuja` (rectángulo del bocadillo).
- `Actores`: los personajes dibujados en el panel, con su `Gif` principal, `Rect` y `Extra` (más poses: `Actor-Pose 'Id' 'pose' ms`).
- `Sonidos`: `clave = @('ruta.wav', ...)`; se reproducen con `Sonido 'clave'` (o `Sonido-De 'Skin' 'clave'`).
- Campos propios de su mecánica que no son frases (por ejemplo `Canciones`, `Videos`, `Ingredientes`…).
- **Las frases NO están en el código**: van en `dialogos\<nombre de la skin>.json` (ver abajo).

Para añadir una skin hay una lista paso a paso al principio de la sección SKINS. En resumen, el `Estilo` nuevo tiene que añadirse en: `Fondo-Escena`, `Pintar-Burbuja`, `Pintar-Boton`, la lista de estilos del `Paint` de `$form` y su `switch`, `Lanzar` (abrir app, web y error), `Clic-Actor`, `Efecto-Entrada`, `$idleTimer`, `$ambTimer`, `Abrir-Invitado` y `Pintar-Invitado`, y el manejador de errores (`add_ThreadException`). Después: su línea en `$GruposSkins`, su archivo `dialogos\<nombre>.json`, su `Opina`/`AlVenirDe` en el JSON de **todas** las demás skins y charlas nuevas en `dialogos\_charlas.json`.

## Diálogos (carpeta `dialogos`)

- Cada skin tiene `dialogos\<nombre exacto de la skin>.json` con sus frases: `Hola`, `Yo`, `Frases`, `Idle`, `Clic`, `PorApp` (por nombre de botón), `AlVenirDe` y `Opina` (una entrada por **cada** otra skin) y las frases de su mecánica (`Stall`, `Gato`, `Roaring`, `Mimos1`, `Toque1`…).
- Las charlas entre skins están en `dialogos\_charlas.json` → `"charlas"`: cada charla es una lista de `["quién", "qué dice"]`. Una charla sale con las dos skins: cuando una es la activa, la otra viene de invitada.
- `Cargar-Dialogos` (justo después de `$Discusiones`) los lee al arrancar y los mete en `$Skins[nombre]` y `$Discusiones`; `Json-A-Datos` hace que las listas sigan siendo listas aunque tengan una sola frase.
- Los archivos son UTF-8. En los textos de una lista puede haber un solo texto o varios; en `Opina` cada valor es una lista.
- **Skins archivadas**: `archivadas.txt` (un nombre por línea). No salen en el menú Skins (`Paginas-Skins`) ni en charlas, ni como skin activa ni como invitadas (`Iniciar-Discusion`); conservan sus frases y opiniones. Se ponen, devuelven o archivan desde Ajustes > "Skins archivadas" (`Mostrar-Archivadas`). Funciones: `Cargar-Archivadas`, `Guardar-Archivadas`, `Es-Archivada`. Sus charlas se quedan en `_charlas.json` por si vuelven. El editor de diálogos las pone en el grupo "Archivadas".
- **Editor de diálogos**: `editor_dialogos.ps1` (se abre con `editor_dialogos.vbs`). Programa aparte: lee la lista de skins y grupos del código con el parser de PowerShell (sin ejecutarlo), el estado de `lore\estado.md` y la ficha de `lore\personajes\`. Pestañas: Ficha, Frases, Apps, Otras skins (AlVenirDe + Opina), Charlas, Mecánica (campos propios). Guarda en el mismo formato que los JSON (guardar sin cambios deja los archivos idénticos). El panel lee los cambios al volver a abrirse. Para probarlo: `-Prueba <script>` carga un script antes de abrir la ventana.
- **Antes de escribir frases de una skin, leer su ficha en `lore\personajes\`** (y en una charla, las fichas de los dos). Estado de cada skin en `lore\estado.md`.

## Intros

- `Intro-Overlay $total $pintar $alTick $final` pone un panel encima del formulario y llama a `$pintar` (dibujo) y `$alTick` (lógica) cada 45 ms.
- Las intros con audio largo van **sincronizadas con el reloj** (`[Environment]::TickCount` desde el inicio), no con el número de fotograma, porque los fotogramas reales van más lentos que lo previsto. Los momentos importantes están en una tabla al principio de cada intro (`$GuiTiempos`, `$KyIntro`) para ajustarlos fácilmente.
- Para acabar antes: poner `$script:iPaso` cerca de `$script:iTotal`. La de Guillotina se salta con un clic.
- Funciones útiles: `Dibujar-Cubriendo` (imagen a pantalla completa con zoom), `Gif-Frame` (fotograma de un GIF según el tiempo), `Texto-Contorno`, `Texto-Color`, `Ruta-Redonda`, `Degradado`, `Imagen-Cubrir`.

## Cómo probar sin molestar al usuario

No abras ventanas en medio de su pantalla (sus clics acaban dentro). Haz una copia de prueba:
1. Guarda una copia de `skin.txt`, `ajustes.txt` y `botones.txt`; pon en `skin.txt` la skin a probar.
2. Crea `_prueba.ps1` = `c00lgui.ps1` sin su última línea (`[void]$form.ShowDialog()`) + un trozo de prueba que:
   - redefina `function Mostrar-Aviso { Arranque }` (si no, el **aviso de epilepsia** del arranque espera un clic),
   - ponga `$script:aj.Guia = $true` (si no, en un PC donde nunca se ha abierto el panel sale la **guía del panda**, que espera un clic: la prueba parece colgada y no lo está),
   - quite el sonido (`$script:aj.Sonido = $false`) y mueva la ventana fuera de la pantalla (`$form.Location = (-5000, 100)`),
   - con un `Timer` vaya llamando a funciones (`Aplicar-Skin`, `Clic-Actor`, `Lanzar`, `Iniciar-Discusion`…),
   - saque capturas con `$form.DrawToBitmap(...)` (y `$script:iOv.DrawToBitmap` durante una intro),
   - al cerrar, escriba `$Error` en un archivo de texto.
3. Ejecútalo con `powershell -NoProfile -ExecutionPolicy Bypass -File _prueba.ps1`, revisa errores y capturas, y **borra `_prueba.ps1` y restaura los tres archivos** al terminar.
4. Haz siempre un repaso final pasando por **todas** las skins (aplicar, clic en el personaje, discusión) para ver que no se ha roto ninguna.

## Herramientas para imágenes

PowerShell no basta para recortar fondos o editar imágenes. Lo que ha funcionado:
- Un entorno de Python aparte (venv) con **Pillow** (recortar, redimensionar, montar fotogramas), **rembg** (quitar fondos) y **soundfile** (convertir OGG→WAV).
- Los GIF de Tenor se bajan de `media.tenor.com/<id>AAAAC/...gif` (la versión grande).
- Las imágenes de Fandom bloquean la descarga normal: hace falta una cabecera de navegador (User-Agent, `Referer` de la wiki y `Accept: image/webp`).
- Reduce los GIF (menos fotogramas, ~300 px, ~100 colores) para que el repositorio no pese demasiado.
- Las wikis de **Miraheze** (p. ej. `enfosi.miraheze.org`) no abren con curl ni PowerShell en Windows 10 (error de TLS). Usa Edge sin ventana: `msedge --headless=new --dump-dom "https://<wiki>/w/api.php?action=query&list=allimages&ailimit=500&format=json"`. Las imágenes (`static.wikitide.net`) sí se bajan con curl.
- Las portadas de Bandcamp se bajan en grande cambiando `_2.jpg` por `_10.jpg` (`f4.bcbits.com/img/a<id>_10.jpg`).
- Cuidado: en una lista `[ordered]@{ 1 = ...; 2 = ... }` el índice `[1]` es la **posición**, no la clave. Para listas numeradas usa un array normal.

## Actualización de Halloween

- Los avances de Halloween van en la rama local `halloween` y se suben al repo privado https://github.com/josepablini777-cmd/ASSISTENTE-NS-HALLOWEEN (remoto `halloween`, rama `main`): `git push halloween halloween:main`.
- Evil Scary usa Estilo `evil`: estado en `$script:es`, funciones `Es-Reset, Es-Rebote, Es-Susto, Es-App, Es-Clic, Es-Tick`, tiempos en `$EsTiempos`, intro `Transicion-Evil` con tiempos en `$EsIntro`.
- Soft Fuzzy Man usa Estilo `niebla`: estado en `$script:sf`, funciones `Sf-Reset, Sf-Existir, Sf-Niebla, Sf-Espesor, Sf-App, Sf-Clic, Sf-Gato, Sf-Tick, Pintar-Niebla`, tiempos en `$SfTiempos`. Actores 'F' (él) y 'G' (Orange Cat).
- Intro de vídeo (`Transicion-Fuzzy`, tiempos en `$SfIntro`): los fotogramas son JPG sueltos en `skins\softfuzzy\intro` (campos `IntroCarpeta`, `IntroFotos`, `IntroFps` de la ficha) y se carga solo el que toca según el reloj; el audio es `intro.mp3`. Para hacer otra intro igual: sacar fotogramas y audio del vídeo con ffmpeg y copiar ese patrón.

## Roaring Knight (Deltarune) y su minijuego

- Estilo `knight`: estado en `$script:kn` (`Kn-Reset, Kn-App, Kn-Clic, Kn-Tick`), botón FIGHT dibujado (`Kn-Fight-Rect`, `Kn-Fight-En-Raton`, enganchado en `$mDown` y `$mMove`), intro `Transicion-Knight` (`$KnIntro`).
- Actores de pixel art: poner `Pixel = $true` en el actor y se dibuja sin suavizar (`Pintar-Actores`).
- Minijuego: `Kn-Combate` crea un Panel encima del formulario (no usa Intro-Overlay) con su propio timer `$kgTimer` (20 ms). Estado en `$script:kg`; lógica en `Kg-Tick`, dibujo en `Kg-Pintar`, salida en `Kg-Salir`. Tiempos y dificultad en `$KgTiempos`, caja en `$KgCaja`.
- Teclado: se lee con `GetAsyncKeyState` (tipo `C00l.Teclas`, se compila la primera vez con `Kg-Teclas`) y solo si el panel es la ventana activa; las flechas no llegan a KeyDown porque los botones se las quedan.
- Las victorias se guardan en `ajustes.txt` (`KnightVictorias`).
- OJO: en PowerShell `$T` y `$t` son la misma variable; en el minijuego los tiempos van en `$KT`.
- Prueba: el script de prueba se pausa mientras `$script:transicion` es true; para el minijuego, usar `if ($script:transicion -and -not $script:kg)` y fotografiar `$script:kgOv` directamente.
