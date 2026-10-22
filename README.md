# c00lgui v3 – panel lanzador con skins de asistentes

Panel para Windows que abre YouTube, las apps de Office y otros programas con un clic.
Tiene nueve skins, cada una con su propio estilo, animaciones y diálogos:

| Skin | Estilo | Efecto al entrar |
|---|---|---|
| **c00lgui** | Panel hacker de c00lkidd (Roblox): negro y rojo | Glitch: la ventana tiembla y salen errores falsos |
| **SeaDrive** | Asistente de YonKaGor, con aspecto de página web | Carga como una web: URL, barra de progreso… |
| **Static Miku** | Miku de Flavor Foley, como un dibujo animado en una tele vieja | Estática de tele y encendido desde el centro |
| **Guillotina** | Jefa de Mewgenics, sobre papel y tinta | Cartel "GUILLOTINA IS COMING FOR YOU!" con su rugido |
| **Angela** | IA de Lobotomy Corporation, con la interfaz de L Corp | Inicio de jornada: "Face the Fear, Build the Future" y el día |
| **Mikaela** | Francotiradora de PURSUITCORE, estilo MLG | Mira del francotirador, disparo y hitmarker |
| **Zodiac** | Pistolero loco del desierto de Mewgenics | Cartel de WANTED con "DON'T MOVE!" y balazos |
| **Velvet** | Araña de Gunsaw, en la pantalla CRT del juego | Pantalla de selección de personaje que se apaga como un monitor viejo |
| **Dune** | Criatura acuática de Gunsaw que habla como un cavernícola | Igual, con su ficha y sus estadísticas |

Cada skin opina de las demás. Pasa el ratón por los botones del menú **Skins** para oír lo que piensa el asistente de cada una. De vez en cuando, además, **discuten entre ellos**: el otro personaje aparece en su propia ventanita pegada al panel, con su estilo y su bocadillo. Lo que dicen tiene efectos: los disparos suenan y hacen temblar las ventanas, las Smokebomb las vuelven transparentes y los mordiscos suenan. **Haz clic derecho sobre el personaje** para empezar una discusión cuando quieras.

**Tamaño:** el panel se adapta solo al escalado de tu pantalla. Para hacerlo más grande o más pequeño, cambia `$Tamano = 1.2` al principio de `c00lgui.ps1` (1.0 = normal, 1.5 = grande).

## Cómo descargarlo

1. Pulsa el botón verde **Code** → **Download ZIP**.
2. Haz clic derecho en el ZIP → **Extraer todo**.
3. Haz doble clic en **`c00lgui.vbs`**.

Si Windows muestra un aviso de seguridad, pulsa **Más información → Ejecutar de todas formas**.

No hace falta instalar nada: funciona con PowerShell, que ya viene con Windows 10 y 11.

## Cómo se usa

- **Botones:** abren la app. Si una app de Office no está instalada, se abre su versión web.
- **`<` y `>`:** cambian de página.
- **Skins:** elige otra skin. Se recuerda para la próxima vez.
- **Mover la ventana:** arrástrala desde el título.
- **Asistente:** haz clic en el personaje y te contesta.
  - **Guillotina:** cada clic le quita vida. Con 200 o menos se enfurece, como en el juego. Si la derrotas, vuelve buscando venganza.
  - **Angela:** cada app que abres suma a la cuota de energía del día.
  - **Mikaela:** mantén pulsado sobre ella para cargar el Snipe y suelta para disparar (2 s: cargado, 6 s: sobrecargado).
  - **Zodiac:** gasta una bala con cada app y si mueves la ventana. Haz clic en él para recargar.
  - **Velvet:** haz clic en ella y escupe una telaraña sobre un botón. El primer clic en ese botón rompe la telaraña.
  - **Dune:** le entra hambre con el tiempo y con cada app que abres. Haz clic en él para darle de comer.

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
- **Guillotina:** jefa de *Mewgenics* (Edmund McMillen y Tyler Glaiel). Imágenes y sonidos de la [wiki de Mewgenics](https://mewgenics.wiki.gg/wiki/Guillotina).
- **Angela:** personaje de *Lobotomy Corporation* (Project Moon). Sprites de la [wiki de Lobotomy Corporation](https://lobotomycorporation.wiki.gg/wiki/Angela/Gallery).

- **Mikaela:** personaje de *PURSUITCORE* (Roblox). Imágenes y sonidos de la [wiki de PURSUITCORE](https://pursuitcore.miraheze.org/wiki/Mikaela).
- **Zodiac:** jefe de *Mewgenics*. Imágenes y sonidos de la [wiki de Mewgenics](https://mewgenics.wiki.gg/wiki/Zodiac).

- **Velvet y Dune:** personajes de *Gunsaw* (Orsoniks). Imágenes de la [wiki de Casualties: Unknown](https://scavprototype.wiki.gg/wiki/Gunsaw).

Proyecto de fans sin ánimo de lucro. Los personajes pertenecen a sus autores.
