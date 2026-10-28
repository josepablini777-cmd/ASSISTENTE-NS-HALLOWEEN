# Lore de las skins

Una ficha por personaje para que cada skin **hable y reaccione según su personalidad**, siempre igual,
la escriba quien la escriba. Los personajes **no recuerdan** lo que pasó en otras discusiones: cada frase sale
solo de cómo es el personaje y de quién tiene delante.

**Antes de escribir cualquier frase de una skin (opiniones, discusiones, frases sueltas), lee su ficha.**
En una discusión, lee las fichas de los dos.

## Esquema de diálogos de cada skin

Todas las skins tienen exactamente las mismas piezas:

```
SKIN
├── Entrada ........ lo que dice al aparecer (Hola)
├── Al venir de .... lo que dice cuando sustituye a cada una de las otras skins (AlVenirDe, una por skin)
├── Opiniones ...... lo que piensa de cada una de las otras skins (Opina, una por skin)
├── Frases sueltas . al abrir apps, al hacerle clic, cuando está quieta (Frases, Clic, Idle, PorApp)
└── 5 charlas ...... 5 discusiones con 5 invitados elegidos por ella
                     (cada charla sale igual en las dos skins: cuando A es la skin activa, B viene de invitado,
                      y cuando B es la activa, viene A. Así cada skin aparece en sus 5 charlas + las de las demás)
```

Al escribir una charla entre A y B: leer las dos fichas; cada uno habla y reacciona como dice su ficha.
El estado de cada skin (bien / revisar / sin revisar) está en `estado.md`.

## Qué lleva cada ficha (`personajes/<nombre>.md`)

1. **Quién es** – de dónde viene y qué es, con los datos de su lore original que no se pueden contradecir.
2. **Personalidad** – 3 a 5 rasgos claros (por ejemplo: cansada, sarcástica, cariñosa con los gatos).
3. **Cómo habla** – tono, longitud de las frases, muletillas, formato (mayúsculas, *acciones entre asteriscos*,
   "* textos de combate"...), si habla o no habla, y cómo se le nombra (masculino, femenino o neutro).
4. **Cómo trata a los demás** – su actitud general con otros personajes y cómo reacciona según quién sea
   (alguien que le cae bien, alguien que le da miedo, alguien que le parece comida...).
5. **Nunca** – lo que este personaje no haría ni diría (para que no se vuelva aleatorio).
6. **Frases modelo** – 4 o 5 frases que suenan exactamente a él/ella, para copiar el tono.
7. **Fuentes** – de dónde sale el lore (wiki, vídeo...).
