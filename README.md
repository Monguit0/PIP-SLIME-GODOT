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
**Murallas** con sus slimes, monedas y flechas que caen, y el **Salón del Trono** con el **Mega Caballero**. Al ganar o perder,
la pantalla de fin con tus **puntos** y el **récord** (se guarda en la compu).

- Se ve como el original: el mundo es de 256×144, los sprites HD (Pip, slimes, el jefe) se dibujan con el doble de detalle y
  los textos usan la misma fuente de 5×7 del juego web.
- **Música y sonidos del original**: la misma canción en sus ánimos (título, cartas, una por zona, entrada del jefe, jefe,
  furia, sin casco, victoria y derrota), que cambia a tiempo, cada medio compás; con un solo corazón suena apagada,
  como debajo del agua. Los efectos son los mismos sonidos jsfxr, con un poco de variación de tono.
- **Pip arquero** con los números del juego web: doble salto, coyote time, salto corto, **dash** intangible, flecha
  normal y **flechazo cargado** (3 de daño, atraviesa). Máximo cuatro flechas en el aire.
- **Críticos** (20%): triple daño, congelado, cámara lenta, zoom, cuadro de impacto en blanco y negro, ¡CRÍTICO!, bombo y chispas.
- **Puntos y combo**: monedas seguidas suben el combo (y la nota, por la escala mayor); pisar slimes da más que flecharlos.
- **Experiencia**: monedas, slimes y el jefe dan EXP; al llenar la barra Pip **evoluciona a Cazador**: vida llena,
  **dos flechas por disparo** y **veneno** (C): mientras está prendido gasta energía y las flechas envenenan (1 de daño cada 0,7 s).
- **Cartas** (8 del arquero): corazón extra, arco reforzado, poción de emergencia, cristal de maná, botas ligeras,
  concentración, flecha triple y paso fantasma.
- **Flechas que caen** del cielo con aviso (más seguido en cada zona; de a tres en las murallas). Si le caen a un slime, lo aplastan.
- **Mega Caballero** (arte de PixelLab, la espada se dibuja en código porque gira con cada ataque): cae del techo, ruge y
  pelea con **barrido**, **salto con ondas de choque**, **embestida** (si choca contra la pared queda mareado y recibe 50% más
  de daño) y **lluvia de espadas** con un hueco para esquivar. Al 50% se enfurece (repite y encadena ataques) y al 25%
  **pierde el casco**. Se le pega con flechas o pisándole la cabeza. Al caer explota y su espada queda clavada en el piso.

## Cómo está armado
- `scenes/main.tscn`: la escena principal; el nivel se arma por código en `scripts/main.gd` (zonas, plataformas,
  portones y antorchas están en constantes arriba de todo, copiadas del original).
- `assets/level1/`: el dibujo del Reino exportado del juego web (suelo y plataformas, cielo, montañas, cerros/ruinas/murallas, nubes y salón).
- `scripts/player.gd`: Pip arquero. Las constantes vienen de `CHARS.archer` y `SK` del `index.html` original.
- `scripts/slime.gd`: slime verde y rojo (`updateGreen` y `updateRed` del original). Ya lee las cuatro filas de la hoja (verde, rojo, tóxico, hielo).
- `scripts/pal.gd`: la paleta de 9 bits del original (`Pal.K`, `Pal.Y`...).
- `scripts/boss.gd`: el Mega Caballero (`updateBoss`, `bossTele`, `bossAct`, `damageBoss` del original).
- `scripts/coin.gd`, `scripts/hazard.gd` (flechas y espadas que caen), `scripts/wave.gd` (ondas de choque), `scripts/arrow.gd`.
- `scripts/fx.gd` (autoload `Fx`: partículas, temblor, hitstop, cámara lenta, críticos), `scripts/snd.gd` (autoload `Snd`:
  efectos y música), `scripts/ptext.gd` (la fuente del original), `scripts/hud.gd`, `scripts/background.gd`.
- `assets/audio/`: los sonidos (`sfx/`, WAV) y la música (`music/`, OGG, una vuelta de la canción por ánimo), exportados del juego web.
- `assets/sprites/items/`: moneda, corazones, flecha y espada que caen, y los dibujos de las cartas (sacados del original).
- `assets/sprites/boss/`: el Mega Caballero hecho con **PixelLab** (`helm.png` con casco y `bare.png` sin casco).
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
