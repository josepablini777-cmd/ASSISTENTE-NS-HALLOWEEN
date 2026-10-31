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
- Dybbuk (Mewgenics) usa Estilo `boneyard`: estado en `$script:dy` (`HP, Max, Estado` = vivo/posee/muerto, `Fin, Hasta, Mana, Apps, WispsHasta`), funciones `Dy-Reset, Dy-Base, Dy-Clic, Dy-Posee, Dy-Muere, Dy-Wisps, Dy-App, Dy-Tick, Dy-Img`, tiempos en `$DyTiempos`. Actor 'D'. Sus GIF (`skins\dybbuk\*.gif`) están normalizados: todos miden 356×224 (lo mismo que su `Rect`) y tienen los pies en el mismo sitio, así no cambia de tamaño al cambiar de pose.
- Intro `Transicion-Dybbuk` (tiempos en `$DyIntro`, `Dy-Asoma` para cuando se asoma detrás de las lápidas); música `skins\dybbuk\intro.mp3` = 18 s de "Them Kitty Bones" (desde el segundo 5).


## Tetra (YonKaGor) · arreglada

- Sigue con Estilo `pop` y sus mecánicas de siempre (`Tetra-Mensaje`, `Tetra-Clic`, No molestar), pero la escena es ahora un acuario dibujado en `Fondo-Escena` (agua, rayos de luz, plantas, grava, burbujeador) y el logo "Failure" va en la barra de arriba.
- `Tetra-Tick`: bancos de tetras neón que nadan en las dos direcciones (`Tetra-Pez-Nuevo`, `Dibujar-Tetra-Pez` con escala negativa = mira a la izquierda), burbujas (`$script:burbujas`) y el baile (`$script:popBaila`, activa `Baila` del actor un rato).
- Los peces se recortan al acuario y Tetra se vuelve a pintar encima (nadan por detrás de ella).
- Dibujo del panel: `skins\tetra\lamina.png` = fanart de Lovavavavania (X: @Lovavavavania), horneado como lámina inclinada con marco blanco y halo neón (el fondo del dibujo está pintado: ni remove.bg ni Canva gratis lo recortan). Como invitada sigue usando la ficha oficial recortada (`Gif` = `tetra.png`).
- Intro (`Transicion-Pop`): el principio del videoclip oficial (YouTube `IYCPzZtDj98`, segundos 3,8 a 24, sin el aviso de epilepsia) en `intro.gif` (480 px, 15 fps) + su audio en `intro.mp3`. Va como la de Gran pero el reloj es la posición del audio (`Tetra-Intro-Ms`). Al acabar o con SALTAR, `Tetra-Intro-Terminar` calla el audio y arranca la instrumental por el mismo punto.
- Música: `skins\tetra\cancion.mp3` = "You're Just Like Pop Music" (instrumental oficial de YonKaGor), `Tetra-Musica-On($desdeMs)/Off`. La instrumental va `$TetraDesfase` = 4805 ms por detrás del vídeo (medido correlando las dos pistas). Los primeros 3 s `Tetra-Tick` la recoloca si el mp3 arrancó tarde. Durante la intro no la arranca.

## Velvet (Gunsaw) · rehecha

- Estilo propio `arana` (antes compartía `gunsaw` con Dune; Dune sigue igual con `gunsaw` y `Transicion-Gunsaw`). Ficha en `lore\personajes\Velvet.md` (descripción oficial de la especie en Gunsaw, de Orsoniks).
- Estado en `$script:vv` (`Seda, Hambre, Confianza, Capullos, Visitas, TrampaT, Mueve, MueveT, Fx`), funciones `Vv-Reset, Vv-Musica-On/Off, Vv-Escupir, Vv-App, Vv-Capullo, Vv-Clic, Vv-Trampa, Vv-Capullo-En-Raton, Vv-Tocar-Capullo, Vv-Tick, Vv-Red (telaraña en abanico), Vv-Dibujar-Capullo, Vv-Pintar`; números en `$VvTiempos`, sitio de los capullos en `$VvCapullos`, ojos en el campo `Ojos` de la skin.
- Escupir sigue usando `Velvet-Escupir` / `$script:telarana` (el botón atrapado y el clic que lo rompe están en `Lanzar` y `Pintar-Boton`). En la trampa, `Pintar-Boton` cubre todos los botones de la cuadrícula.
- Música: `skins\velvet\creeps.mp3` = "Night of the Creeps" de Karl Casey (suena en Gunsaw; White Bat Audio, libre de derechos).
- Solo hay un arte suyo (`velvet.png`, el de la selección de personaje, sin fondo): el balanceo, la embestida y el brillo de los ojos se hacen por código en `Vv-Tick` y `Vv-Pintar`.

## Angela (Lobotomy Corporation) · rehecha

- Sigue con Estilo `lobo`, pero ahora es una skin "nueva" (escena de 760 px con actores): ya no usa `Pb`, `Caras` ni `$script:energia`. Ficha en `lore\personajes\Angela.md`.
- Estado en `$script:ag` (`PE, Qli, Nivel, Brecha, Trompeta, Completa, FinT, Toques, Cara, CaraHasta, Ultimo, Golpe, Rojo, FiltroT, Reprimidas`), funciones `Ag-Reset, Ag-Musica-On/Off, Ag-Cara, Ag-Cara-Decir, Ag-App, Ag-Fusion, Ag-Brecha, Ag-Golpe, Ag-Reprimir, Ag-Cuota, Ag-Cuota-Completa, Ag-Nuevo-Dia, Ag-Clic, Ag-Filtro, Ag-Monitor-En-Raton, Ag-Tick, Ag-Pintar`; números en `$AgTiempos`; monitor en `$AgMonitor`.
- El día se guarda en `ajustes.txt` (`AngelaDia`); la cuota es `20 + 4 × (día − 1)`, máximo 60.
- Caras: actor 'A' con 11 sprites del juego (`a_*.png`). `Ag-Tick` mueve la boca mientras se escribe el bocadillo (`$AgBocas`: cada cara con su versión con la boca abierta). `Decir` llama a `Ag-Cara-Decir`: 'serio' = molesta, 'ojos' = ojos abiertos, 'enfado', 'sonrie', 'risa', 'sorpresa'.
- Música (`$AgCanciones`): Neutral01-04 según el nivel de Qliphoth y First/Second/Third Warning según la emergencia de la brecha (oficiales de Project Moon, mono 64 kbps).
- El clic en el monitor (brecha) va en `$mDown` antes que el de los actores.
- OJO: un campo de la skin no puede llamarse igual que una lista de su JSON (`Cargar-Dialogos` lo pisa). Por eso la imagen del filtro cognitivo es `FiltroImg` y las frases son `Filtro`.

## Weathergirl (FLAVOR FOLEY ft. Eleanor Forte)

- Estilo `clima`, grupo **YouTube** (junto a Static Miku, también de Flavor Foley). Ficha en `lore\personajes\Weathergirl.md`. Actor 'W' = arte oficial de la tienda de Flavor Foley recortado con rembg (`skins\weathergirl\eleanor.png`, 448×448, cuadrado como su `Rect`).
- Estado en `$script:wg` (`Cielo, Real, Temp, Desc, Lugar, Min, Max, MDesc, MCielo, Pedido, Palabras, Clics, Tormenta, Consuelo, Vivos, Paraguas, Rayo, Ticker, Gotas, Lagrimas, Letras, Pintado`), funciones `Wg-Reset, Wg-Cielo, Wg-Llora, Wg-Noche, Wg-Pedir, Wg-Revisar, Wg-Inventar, Wg-Parte, Wg-Manana, Wg-App, Wg-Tormenta, Wg-Rayo, Wg-Clic, Wg-Vivos, Wg-Letra, Wg-Paraguas-*, Wg-Dar-Paraguas, Wg-Tick, Wg-Pintar-Fondo, Wg-Icono, Wg-Dibujar-Paraguas, Wg-Pintar`; números en `$WgTiempos`, sitio de la tarjeta y del paraguas en `$WgTarjeta` / `$WgParaguasBtn`, ojos (lágrimas) en `$WgOjos`.
- **Tiempo de verdad**: `https://wttr.in/?format=j1&lang=es` con `WebClient.DownloadStringTaskAsync` (no bloquea; `Wg-Revisar` mira en cada tick si terminó; 15 s de espera; se repite cada 30 min). Sin conexión, `Wg-Inventar` y ella lo dice. `Wg-Codigo` pasa los códigos de wttr.in a sol/nubes/lluvia/tormenta/nieve/niebla.
- El fondo guardado (`$script:bmpEscena`) depende del cielo: `Wg-Tick` lo tira cuando cambia (`Pintado` = "cielo|noche") y `Fondo-Escena` lo vuelve a pintar con `Wg-Pintar-Fondo`.
- Mecánica: cada app suma una "palabra sin decir"; a 6 llora (tormenta, AVISO ROJO, la tarjeta enseña la portada); 3 clics la consuelan → cielos vivos (arcoíris) 90 s. 3 clics seguidos sin llorar = frase sincera (−2). Con lluvia sale "dale el paraguas" (clic en `$mDown`).
- Intro `Transicion-Clima` = dos trozos del videoclip (0-4,5 s y 153-169,5 s) en `intro.gif` + `intro.mp3`, como la de Tetra (el reloj es el audio). Música: instrumental oficial (Google Drive de flavorfoley.com), va 60 ms por detrás del vídeo (`$WgIntro`).
- OJO con las variables: `$w` y `$W` son la misma; en `Wg-Pintar` las palabras flotantes van en `$pal`.
- Herramienta nueva: `%USERPROFILE%\herramientas\rembg` (venv de Python 3.12 con rembg + Pillow, instalado con uv). Se usa desde Python (`from rembg import remove, new_session`; modelo `isnet-anime`), la línea de comandos de rembg no está instalada.

## Kennyoung (YouTube) · su vida en sus vídeos

- Estilo `punk`, grupo **YouTube**. Ficha en `lore\personajes\Kennyoung.md`. **No es su canal**: es él, viviendo en escenas de sus videoclips. Su ánimo decide en qué escena está y qué canción suena; tú le haces compañía, le animas o le dejas descansar.
- Escenas (`$KyEscenas`, imágenes 712×444 sin letras en `skins\kennyoung\escenas\*.jpg`, canciones en `\musica\*.mp3`): **animado** (atardecer con guitarra, Ready To Say), **tranquilo** (sillón, I Used To), **solo** (manta y portátil, Loner), **cansado** (Lethargy), **agobiado** (Get Away). Cada canción sigue donde se quedó (`$script:kyPosiciones`) y cambia con fundido (`kyMusicaVieja`).
- Ánimo en `$script:ky` (`Escena, Antes, CambioT, Energia, Compania, Agobio, Ult, Amp, Rotas, Fx, Flash, Desde, DesdeT, Fade`); números en `$KyTiempos`. Cada app: −energía, +compañía y +agobio; sin apps ni clics durante 40 s (`Descanso`) recupera energía (y la compañía baja más deprisa); el agobio baja solo poco a poco. `Ky-Escena-Deseada`: agobio ≥ 70 → agobiado; energía < 25 → cansado; compañía < 25 → solo; energía ≥ 60 y compañía ≥ 55 → animado; si no, tranquilo. Mínimo 6 s entre cambios (`CambioMin`).
- Clic izquierdo en la escena (`Ky-Clic`): animado = toca la guitarra (AMPLI; al 100 % explota, `Kaboom`); agobiado = −15 agobio; cansado = +3 energía; solo = +6 compañía y un corazón; tranquilo = habla. Clic derecho = charla con otro personaje.
- Funciones: `Ky-Reset, Ky-Volumen, Ky-Musica-Off, Ky-Poner-Musica, Ky-Escena-Deseada, Ky-Cambiar, Ky-App, Ky-Clic, Ky-Tick, Ky-Img, Ky-Dibujar-Escena, Ky-Ambiente, Ky-Pintar, Ky-En-Escena` (+ `Dibujar-Pegatina` y `Dibujar-Cuadros` para el fondo). `Ky-Pintar` dibuja la escena (zoom lento, fundido de 900 ms), partículas según la escena, la pegatina "Kenny está X / ♪ canción" y las barras de energía, compañía y agobio (+ AMP en animado).
- Frases del JSON por escena: `Entra<Escena>`, `Idle<Escena>`, `Clic<Escena>` (menos animado, que usa `Clic`), `AppAgobiado`, `AppCansado`.
- Intro `Transicion-Punk` (`$KyIntro`, ~10,4 s): **tablero de pegatinas**. A oscuras, clic del flexo (`flexo.wav`) y se enciende una lámpara verde que se balancea sobre la pared de cuadros de su camisa; al ritmo de **Ready To Say** (desde el segundo 0, golpes medidos: compás ≈ 2760 ms) las 5 escenas caen y se pegan como pegatinas con borde verde y etiqueta escrita a mano (`pegar.wav`, chispas, la pared tiembla); a los 7,3 s se pega él (`intro_kenny.png` con borde verde, destello, la luz sube y late con la música), luego KENNYOUNG y MUSIC · ART · VIDEO. El reloj es la posición del audio (`Ky-Intro-Ms`). Todo se prepara en bitmaps antes de empezar (`Ky-Con-Sombra, Ky-Pegatina-Escena, Ky-Pegatina-Recorte, Ky-Pegatina-Nombre, Ky-Etiqueta`; se dibuja con `Ky-Pegar, Ky-Chispas, Ky-Flexo`). La canción sigue sonando después sin corte si su escena es animado (`Ky-Poner-Musica` no reinicia la que ya suena). Ojo: una lista de un solo evento se escribe `@(, @(...))` o PowerShell la aplana.
- Sus frases hablan de sus canciones, **nunca citan sus letras**.
## Painter (Pressure)

- Estilo `pintor`, grupo **Roblox** (junto a Sebastian Solace). Skin llamada `Painter` (Z-779, "the_p.AI.nter"). Ficha en `lore\personajes\Painter.md` (datos de la wiki oficial de Pressure: urbanshade.org/wiki/The_p.AI.nter).
- **Aspecto de programa de dibujo clásico de Windows** (todo dibujado para la skin): panel gris con relieve, barra de arriba azul, botones grises en relieve (azules al pasar el ratón, `Pintar-Boton`), bocadillo amarillo de aviso, escritorio verde azulado. Letra Tahoma. `Pr-Bisel` dibuja el relieve.
- **Painter es su programa**: `skins\painter\programa.png` (680×372 = 340×186 en la escena; lo genera `programa2.ps1` con System.Drawing): barra de título "sin título - the_p.AI.nter", menús, caja de herramientas (2×6), lienzo blanco, su panel (pantallita para la cara + datos), paleta de 2×14 colores y barra de estado. `painter_cara.png` = la misma ventana con cara y dibujos (invitado). Actor 'P', Rect 412,60,340,186; bocadillo 424,250,322,64.
- `$PrCanvas` / `$PrPanel` = lienzo y panel dentro de la ventana; el resto de medidas van fijas en `Pr-Pintar` (pantallita de la cara 253,30,81,51; datos desde y=89; herramientas `Pr-Herramienta`; paleta x=28+i·8, y=160; barra de estado y=177).
- **Su cara viva** (`Pr-Cara-Viva`, `Pr-Pintar-Cara`; diseño propio, no copia la cara del juego: estilo garabato hecho con el ratón sobre la pantallita blanca. `Pr-GE` = círculo rayado a varias vueltas, `Pr-GL` = línea temblona, `Pr-GArco` = arco temblón, `Pr-GBlob` = borrón relleno. El trazo "tiembla": 3 versiones que se alternan cada 170 ms, semilla `$sb`): 21 expresiones en `$PrExpresiones` (ojos, cejas, boca y extra: rubor, gota, lágrimas, zzz, ?, !, notas, vapor, brillos). Mira al lápiz cuando dibuja, a tu ratón si está encima del panel y si no, a su aire; parpadea; mueve la boca mientras se escribe el bocadillo o suena su voz. Su humor cambia solo cada 5-11 s (`$PrHumores`); pone cara de "concentrado" mientras dibuja, reacciona al acabar un dibujo y a los clics, y se duerme (`dormido`) si pasan 75 s sin apps ni clics (`Ult`); dormido tampoco dibuja. `Pr-Cara $nombre $ms [$silencio]` pone una expresión un rato.
- Estado en `$script:pr` (`Calor, Paisaje, Terminados, Cara, CaraT, CaraHasta, ElemT, Mina, MinaIni, MinaDicho, Enfria, Listo, Ciclo, Hex, Saludado`), funciones `Pr-Reset, Pr-Mina-Activa, Pr-Musica-On/Off, Pr-Cara, Pr-App, Pr-Mina, Pr-Listo, Pr-Clic, Pr-Tick, Pr-Garabato, Pr-Curva, Pr-Recta, Pr-Trazos, Pr-Dibujar-Cara (devuelve la punta del lápiz mientras dibuja), Pr-Lapiz, Pr-Flecha, Pr-Dibujar-Paisaje, Pr-Geometria, Pr-Pintar-Fondo, Pr-Pintar`; números en `$PrTiempos`.
- **Él dibuja, no se dibuja a sí mismo**: su cara va en la pantallita del panel (arriba a la derecha de la ventana; `Pr-Pintar-Cara`, trazos claros, parpadea cada 4,2 s; caras en `Pr-Trazos`: feliz, triste, llora, enfado, susto, mareo, neutra, guiño, parpadeo). En el lienzo hace garabatos de colores (`Pr-Garabatos`: sol, flor, gato, estrella, corazón, pez, nube, árbol, casita; `$PrDibujosLista`, `$PrHuecos` = 6 huecos) trazo a trazo con el lápiz (`Pr-Nuevo-Dibujo`, `Pr-Dibujar-Dibujo`, puntos guardados en `Pr-Dibujo-Cache`); con 6 dibujos, lo borra con la goma (`Borra`, `Pr-Goma`). El color que usa se marca en la paleta (`$PrPaleta`) y la barra de estado dice lo que hace. Frases al empezar un dibujo: lista `Garabato` del JSON ({0} = "un gato"...).
- Mecánica: cada app = un elemento del paisaje (cielo, sol, colinas, árbol, río, casita) y +22° de OVERCLOCK. A la 6ª lo termina (`Pr-Listo`, va antes de sobrecalentarse). A 100°: `Pr-Mina` (7,5 s de hashes, pierde el paisaje). Clic en él: −25° (espera 1,8 s). Se enfría solo 0,4°/s.
- **Voces del juego** (voz de artdstuf): `skins\painter\voces\*.mp3` + `skins\painter\voces.txt` (`categoría|archivo|ms|traducción`). Categorías: intro, hola, idle, clic, enfriar, calor, mina, perdon, minafin, listo, app. `Pr-Voz $cat [$fijo]` suena la voz y pone la traducción en el bocadillo; devuelve `$false` si no hay sonido o ya está hablando (entonces sale la frase escrita del JSON). La música baja mientras habla (`Pr-Voz-Suena`). Se sacaron de un vídeo con sus frases, transcrito con faster-whisper (instalado en el venv `herramientas\rembg`; leer el audio con `wave` + numpy, el lector propio falla con esta versión de `av`).
- Música: `skins\painter\cancion.mp3` = "roblox pressure speaker (Z-779) music" (YouTube, +6 dB). Sonidos sintetizados con ffmpeg (`aevalsrc` NO admite `<`: usar `lt()`, `between()`, `gte()`).
- Intro `Transicion-Pintor` (tiempos en `$PrIntro`, ~13,6 s, por el reloj): arranque del ordenador con la lista de sistemas secuestrados → "ABRIENDO the_p.AI.nter.exe" → se abre su programa en el centro, el lápiz dibuja la sonrisa (con su voz "¡Uy, una visita!") → la ventana se aparta a la derecha, título y "¡Vámonos, pequeño ordenador!" → guiño.
- OJO: no meter opiniones sobre Ellie (a propósito nadie opina de ella).

## Malkuth (Library of Ruina)

- Estilo `historia`, grupo **Videojuegos**. Ficha en `lore\personajes\Malkuth.md`. Estado en `$script:mk` (`Libros, Mesa, Estantes, Nivel, Puntos, Animo, Toques, Hundida, Respira, Fx, EgoT`), funciones `Mk-Reset, Mk-Musica-On/Off, Mk-Base, Mk-Cara, Mk-Animo, Mk-App, Mk-Realizacion, Mk-Fallo, Mk-Clic, Mk-Tick, Mk-Pintar-Mesa`; números en `$MkTiempos`. Actor 'M' con sus 6 caras del juego (`main, feliz, respira, decidida, enfado, sombria`) y 3 sprites de combate (`tropiezo, herida, combate`).
- **Música de fondo** como Gran, pero cambia con el NIVEL DE EMOCIÓN (`$MkMusica`): Malkuth Story → Battle 1 → Battle 2 → Battle 3 (bajados de YouTube con yt-dlp, mono 96 kbps). La intro (`Transicion-Malkuth`, tiempos en `$MkIntro`) arranca la música y sigue sonando después.
- Mecánica: cada app = un libro (6 en la mesa → estantería); cada 3 libros sube la emoción; a 5, Realización (carta `ego.jpg`). ÁNIMO: baja con fallos, clics seguidos y prisas; por debajo de 30 se hunde y con un clic hacéis el ejercicio de respiración.
- Herramientas que se instalaron para esto: `%USERPROFILE%\herramientas\yt-dlp\yt-dlp.exe` y `%USERPROFILE%\herramientas\ffmpeg\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe`.

## Ellie Velázquez (self insert de Ale)

- Estilo `corrupta`, grupo **Amigos**. Estado en `$script:el` (`Rabia, Glitch, GlitchHasta, Veces, Natillas, NatHasta, TeleHasta, InvHasta, Fx, Bloques`), funciones `El-Reset, El-Bloques, El-Centro, El-Rabia, El-Glitch, El-Fin-Glitch, El-Pinchar, El-Natillas, El-Teleport, El-App, El-Tick`, números y tiempos en `$ElTiempos`. Actores 'E' (ella) y 'N' (natillas, clicables).
- Intro `Transicion-Ellie` (tiempos en `$ElIntro`): alarma, el usuario de Ale (`skins\ellie\user.png`) con círculo y flecha, glitch. Sus sonidos están sintetizados con ffmpeg.
- **A propósito no tiene charlas ni opiniones cruzadas** (ni ella de las demás ni las demás de ella). `Opinion-Azar` solo elige skins con opinión escrita, así no salen bocadillos vacíos. No añadirle charlas sin que el usuario lo pida.

## Roaring Knight (Deltarune) y su minijuego

- Estilo `knight`: estado en `$script:kn` (`Kn-Reset, Kn-App, Kn-Clic, Kn-Tick`), botón FIGHT dibujado (`Kn-Fight-Rect`, `Kn-Fight-En-Raton`, enganchado en `$mDown` y `$mMove`), intro `Transicion-Knight` (`$KnIntro`).
- Actores de pixel art: poner `Pixel = $true` en el actor y se dibuja sin suavizar (`Pintar-Actores`).
- Minijuego: `Kn-Combate` crea un Panel encima del formulario (no usa Intro-Overlay) con su propio timer `$kgTimer` (20 ms). Estado en `$script:kg`; lógica en `Kg-Tick`, dibujo en `Kg-Pintar`, salida en `Kg-Salir`. Tiempos y dificultad en `$KgTiempos`, caja en `$KgCaja`.
- Teclado: se lee con `GetAsyncKeyState` (tipo `C00l.Teclas`, se compila la primera vez con `Kg-Teclas`) y solo si el panel es la ventana activa; las flechas no llegan a KeyDown porque los botones se las quedan.
- Las victorias se guardan en `ajustes.txt` (`KnightVictorias`).
- OJO: en PowerShell `$T` y `$t` son la misma variable; en el minijuego los tiempos van en `$KT`.
- Prueba: el script de prueba se pausa mientras `$script:transicion` es true; para el minijuego, usar `if ($script:transicion -and -not $script:kg)` y fotografiar `$script:kgOv` directamente.
