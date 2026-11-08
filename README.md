# Pip y los Slimes · versión Godot

La nueva versión de **Pip y los Slimes** hecha en **Godot 4** con sprites de **PixelLab**.
El juego web original sigue en [Monguit0/pip-slimes](https://github.com/Monguit0/pip-slimes) y no se toca.

## Abrirlo
1. Bajá Godot 4.5 o más nuevo (versión estándar, no hace falta la .NET) desde https://godotengine.org/download
2. En Godot: **Importar** → elegí el `project.godot` de esta carpeta → **Importar y editar**.
3. Apretá **F5** (o el ▶ de arriba a la derecha) para jugar.

La primera vez Godot tarda unos segundos en importar las imágenes.

## Qué hay: el Nivel 1 completo con el arquero
El **Nivel 1 (El Reino)** igual que en el juego web: **título**, una **carta** para elegir al empezar, **Pradera**, **Ruinas** y
**Murallas** con sus slimes y esqueletos, monedas y flechas que caen, y el **Salón del Trono** con el **Mega Caballero**. Al ganar o perder,
la pantalla de fin con tus **puntos** y el **récord** (se guarda en la compu).

- Se ve como el original: el mundo es de 256×144, los sprites HD (Pip, slimes, el jefe) se dibujan con el doble de detalle y
  los textos usan la misma fuente de 5×7 del juego web.
- **Música del original**: la misma canción en sus ánimos (título, cartas, una por zona, entrada del jefe, jefe,
  furia, sin casco, victoria y derrota), que cambia a tiempo, cada medio compás; con un solo corazón suena apagada,
  como debajo del agua.
- **Efectos de sonido nuevos**, hechos para el estilo HD: cada uno tiene golpe, cuerpo y cola (la cuerda del arco que
  vibra, la flecha que queda temblando al clavarse, el slime que revienta en gotas, la armadura que suena a metal, el
  rugido con eco de castillo, las pisadas pesadas del caballero), con eco tipo SNES en lo mágico. Suenan tan fuerte
  como los originales y con un poco de variación de tono. Los jsfxr del juego web quedaron en `assets/audio/sfx_original`.
- **Fondos pintados con PixelLab**: cielo con luna, cordillera con el castillo del rey a lo lejos, y adelante el bosque
  de la Pradera, las ruinas con arcos y enredaderas y las murallas con ventanas encendidas; el Salón del Trono tiene
  rosetón, estandartes, trono y antorchas que chisporrotean. Las capas de atrás se oscurecen para que se vean lejos.
- **Sin tirones**: los cuadros del jefe y de los esqueletos y la música se cargan en segundo plano desde el título, y
  los shaders se compilan al arrancar (antes el primer dash y la entrada al castillo trababan un instante).
- **Pip arquero** con los números del juego web: doble salto, coyote time, salto corto, **dash** intangible, flecha
  normal y **flechazo cargado** (3 de daño, atraviesa). Máximo cuatro flechas en el aire.
- **Las flechas se clavan** donde pegan (las de Pip y las del esqueleto): en el piso, en las paredes, en los portones
  y en las plataformas si les caen desde arriba. La punta queda adentro, vibran un instante y quedan ahí un rato;
  si el portón sube, la flecha sube con las rejas y se cae al llegar al arco.
- **Críticos** (20%): triple daño, congelado, cámara lenta, zoom, cuadro de impacto en blanco y negro, ¡CRÍTICO!, bombo y chispas.
- **Efectos a medio píxel**, con el mismo píxel que los sprites HD y las rampas de la paleta: las chispas nacen blancas y
  se enfrían hacia su color, el polvo son bollitos que crecen y se deshacen en damero, los cascotes y huesitos rebotan,
  el slime salpica gotas y deja un charco, cada golpe tiene su **estrella** (destello blanco y rayos hacia donde iba el
  golpe), el barrido del jefe deja una **media luna** que sigue a la espada, las explosiones son bollos de fuego, los
  anillos y las ondas en el piso son de píxeles y los números saltan con borde (los grandes con degradé). Al recibir un
  golpe la silueta entera se pone blanca.
- **Juice**: polvo al saltar, caer, correr y derrapar; anillo de aire en el doble salto; líneas de velocidad y estela de
  silueta en el dash; chispitas que se juntan en el arco mientras carga y destello cuando está listo; retroceso de cámara
  al disparar y al recibir golpes; destellito en las monedas; el jefe ruge con ondas, embiste levantando polvo, choca
  contra la pared largando piedras y al caer de un salto parte el piso con dos ondas. Los slimes se agachan antes de
  saltar, suben con la boca abierta y parpadean cada tanto; la carrera de Pip va al ritmo de su velocidad.
- **Puntos y combo**: monedas seguidas suben el combo (y la nota, por la escala mayor); pisar slimes da más que flecharlos.
- **Experiencia**: monedas, slimes y el jefe dan EXP; al llenar la barra Pip **evoluciona a Cazador**: vida llena,
  **dos flechas por disparo** y **veneno** (C): mientras está prendido gasta energía y las flechas envenenan (1 de daño cada 0,7 s).
- **Cartas** (8 del arquero): corazón extra, arco reforzado, poción de emergencia, cristal de maná, botas ligeras,
  concentración, flecha triple y paso fantasma.
- **Esqueletos** (los del modo villano del original, hechos con PixelLab): el **arquero** guarda distancia y te tira
  flechas rectas; el **hachero** te persigue, levanta el hacha (titila) y pega un hachazo adelante. Salen de la tierra,
  respiran mientras esperan, se doblan con cada golpe, se pueden pisar o flechar y se desarman en una pila de huesos. Uno en la Pradera, tres en las Ruinas, cuatro en las Murallas.
- **Flechas que caen** del cielo con aviso (más seguido en cada zona; de a tres en las murallas). Si le caen a un enemigo, lo aplastan.
- **Mega Caballero** (animado con PixelLab, en ciclos de 12 cuadros: respira, camina al paso de lo que avanza, embiste
  corriendo, se marea, cae de rodillas, **ruge con el puño en alto** y **salta entero**: se agacha, despega, encoge las
  piernas, levanta la espada, cae con todo y se levanta. En el barrido el brazo toma 19 poses según el ángulo de la espada).
  La espada se dibuja en código porque gira con cada ataque, pero **se ve agarrada** (los dedos se dibujan encima del mango)
  y es **firme**: va rígida con el brazo, entre dos poses gira rápido sin pasarse y el espadazo se clava de golpe. En la
  lluvia de espadas la levanta, destella con la orden y la deja quieta en alto. Cae del techo, ruge y
  pelea con **barrido**, **salto con ondas de choque**, **embestida** (si choca contra la pared queda mareado y recibe 50% más
  de daño) y **lluvia de espadas** con un hueco para esquivar. Al 50% se enfurece (repite y encadena ataques) y al 25%
  **pierde el casco**. Se le pega con flechas o pisándole la cabeza. Al caer explota y su espada queda clavada en el piso.

## Cómo está armado
- `scenes/main.tscn`: la escena principal; el nivel se arma por código en `scripts/main.gd` (zonas, plataformas,
  portones y antorchas están en constantes arriba de todo, copiadas del original).
- `assets/level1/`: el Reino. `level.png` (suelo y plataformas) y las nubes vienen del juego web; el cielo, las montañas,
  la capa del medio y el salón los arma `tools/bg/compose.py` con piezas de PixelLab (las capas viejas, en `original/`).
- `scripts/player.gd`: Pip arquero. Las constantes vienen de `CHARS.archer` y `SK` del `index.html` original.
- `scripts/slime.gd`: slime verde y rojo (`updateGreen` y `updateRed` del original). Ya lee las cuatro filas de la hoja (verde, rojo, tóxico, hielo).
- `scripts/pal.gd`: la paleta de 9 bits del original (`Pal.K`, `Pal.Y`...).
- `scripts/boss.gd`: el Mega Caballero (`updateBoss`, `bossTele`, `bossAct`, `damageBoss` del original).
- `scripts/skeleton.gd`: esqueleto arquero y hachero (`aiMob`, `mobShoot` y `mobSwing` del original); `scripts/enemy_arrow.gd` su flecha.
- `scripts/coin.gd`, `scripts/hazard.gd` (flechas y espadas que caen), `scripts/wave.gd` (ondas de choque), `scripts/arrow.gd`,
  `scripts/stick.gd` (dónde se clavan las flechas).
- `scripts/fx.gd` (autoload `Fx`: partículas, polvo, cascotes, gotas, estrellas de golpe, tajos, explosiones, anillos,
  textos, temblor y empujón de cámara, hitstop, cámara lenta, críticos), `scripts/pix.gd` (dibujo a medio píxel y rampas
  de color para los efectos), `scripts/snd.gd` (autoload `Snd`:
  efectos y música), `scripts/ptext.gd` (la fuente del original), `scripts/hud.gd`, `scripts/background.gd`.
- `assets/audio/`: los sonidos (`sfx/`, WAV, sintetizados por `tools/sfx`) y la música (`music/`, OGG, una vuelta de la
  canción por ánimo, exportada del juego web).
- `assets/sprites/items/`: moneda (y `coin_spin.png`, la moneda girando con su canto, que arma `tools/ui/coin_spin.py`),
  corazones, flecha y espada que caen, y los dibujos de las cartas.
- `assets/sprites/ui/`: el HUD en HD. Marcos de las barras de energía, experiencia y del jefe con su medallón, el marco
  de las cartas con su brillo (los dibuja `tools/ui/hud_parts.py`) y los íconos del rayo, la estrella y el yelmo
  (`tools/ui/icons.py`). Si hay un `carta_<id>.png` acá, la carta lo usa en vez del dibujo de `items/`.
- `assets/sprites/boss/`: el Mega Caballero hecho con **PixelLab**, `helm/` con casco y `bare/` sin casco, cada uno con
  `idle/`, `walk/`, `charge/` (12 cuadros), `dazed/`, `death/`, `jump/` (14 cuadros del salto con espadazo), `roar/` y
  `arc/` (19 poses del brazo, de atrás de la cabeza hasta adelante). Lienzo de 144×144 con los pies en (72, 118); dónde
  está el puño en cada cuadro va en `HANDS` (y el ángulo de la espada de cada pose en `ANGS`), arriba de `boss.gd`.
  Cada carpeta tiene además `fist.png`: el puño de cada cuadro recortado (14×14), que se dibuja encima del mango.
- `assets/sprites/skel/`: los esqueletos de **PixelLab** (`arch/` y `axe/`, con `idle/` (respira), `walk/`, `atk/`, `hurt/` y `death/`, lienzo de 68×68).
- `assets/sprites/slimes.png`: la hoja de slimes de 32 bits sacada tal cual del juego web.
- `assets/sprites/pip/`: Pip hecho con **PixelLab** (personaje "Pip arquero", vista lateral, 48×48):
  `east.png` y las carpetas `idle/`, `run/`, `jump/`, `fall/`, `shoot/` (tensar el arco), `aim/` (apuntando en loop, con la capa al viento), `release/` (soltar con retroceso), `dash/`, `hurt/` y `death/` con un PNG por cuadro. Mira a la derecha; para la izquierda se espeja.
  Si falta alguna carpeta, el juego usa el cuadro quieto.

## Plan
1. **Base**: proyecto, Pip arquero, slimes y el Reino. ✔
2. **Nivel 1 completo con el arquero**: música, sonidos, juice, monedas, cartas, evolución y Mega Caballero. ✔
   Falta: los otros tres héroes (caballero, bárbaro, mago) y el aspecto propio del Cazador.
3. **Niveles 2 a 4** con sus bichos y jefes (Campeón, Yeti, Kraken), experiencia y evoluciones.
4. **Sillón** (varios joysticks en la misma pantalla) y después el **online**.
