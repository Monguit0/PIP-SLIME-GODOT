# Pip y los Slimes · versión Godot

La nueva versión de **Pip y los Slimes** hecha en **Godot 4** con sprites de **PixelLab**.
El juego web original sigue en [Monguit0/pip-slimes](https://github.com/Monguit0/pip-slimes) y no se toca.

## Abrirlo
1. Bajá Godot 4.5 o más nuevo (versión estándar, no hace falta la .NET) desde https://godotengine.org/download
2. En Godot: **Importar** → elegí el `project.godot` de esta carpeta → **Importar y editar**.
3. Apretá **F5** (o el ▶ de arriba a la derecha) para jugar.

La primera vez Godot tarda unos segundos en importar las imágenes.

## Qué hay (etapa 1)
El **Nivel 1 (El Reino)** igual que en el juego web: **Pradera**, **Ruinas** y **Murallas**, con las mismas plataformas,
el mismo dibujo (las imágenes del suelo, el cielo de noche con luna, las montañas y las murallas salen del `index.html` original)
y los **portones** que se abren cuando limpiás la zona. Al pasar a la zona siguiente el portón de atrás se cierra y recuperás un corazón.
Al final está el **Salón del Trono**; el Mega Caballero llega en la próxima etapa.

- Se ve como el original: el mundo es de 256×144 y los sprites HD (Pip y slimes) se dibujan con el doble de detalle.
- **Pip arquero** con los números del juego web: velocidad, salto, **doble salto**, coyote time, salto corto
  si soltás el botón, y caída un poco más pesada.
- **Dash** (gasta energía, un dash por salto): por un instante es intangible y atraviesa slimes.
- **Arco**: tocá atacar para una flecha; mantenelo para tensar (Pip se queda quieto apuntando) y soltá cuando brille
  para el **flechazo cargado** (más rápido, 3 de daño, atraviesa). Saltar cancela.
- **Slime verde** (1 de vida): patrulla su plataforma a saltitos. **Slime rojo** (2 de vida): te persigue por la zona y salta para alcanzarte.
  Cada zona trae los mismos que el original (4+1, 4+2, 3+3). Si les caés encima los pisás y rebotás (con salto apretado, más alto).
- Juice: estirar y aplastar, chispas, temblor, hitstop, estela del dash, números de daño.

## Controles
| Acción | Teclado | Joystick |
|---|---|---|
| Moverse | ← → (o A D) | Cruceta o stick |
| Saltar / doble salto | Espacio (o Z, K) | A |
| Atacar (mantené para cargar) | X (o J) | X |
| Dash | Shift (o V, L) | B |
| Bajar de la plataforma | ↓ + salto | Abajo + A |
| Reiniciar | R | Start |

## Cómo está armado
- `scenes/main.tscn`: la escena principal; el nivel se arma por código en `scripts/main.gd` (zonas, plataformas,
  portones y antorchas están en constantes arriba de todo, copiadas del original).
- `assets/level1/`: el dibujo del Reino exportado del juego web (suelo y plataformas, cielo, montañas, cerros/ruinas/murallas, nubes y salón).
- `scripts/player.gd`: Pip arquero. Las constantes vienen de `CHARS.archer` y `SK` del `index.html` original.
- `scripts/slime.gd`: slime verde y rojo (`updateGreen` y `updateRed` del original). Ya lee las cuatro filas de la hoja (verde, rojo, tóxico, hielo).
- `scripts/pal.gd`: la paleta de 9 bits del original (`Pal.K`, `Pal.Y`...).
- `scripts/arrow.gd`, `scripts/fx.gd` (autoload `Fx`: partículas, temblor, hitstop), `scripts/hud.gd`, `scripts/background.gd`.
- `assets/sprites/slimes.png`: la hoja de slimes de 32 bits sacada tal cual del juego web.
- `assets/sprites/pip/`: Pip hecho con **PixelLab** (personaje "Pip arquero", vista lateral, 48×48):
  `east.png` y las carpetas `idle/`, `run/`, `jump/`, `fall/` y `shoot/` (tensar y soltar el arco) con un PNG por cuadro. Mira a la derecha; para la izquierda se espeja.
  Si falta alguna carpeta, el juego usa el cuadro quieto.

## Plan
1. **Base** (esto): proyecto, Pip arquero, slime verde y un nivel de prueba.
2. **Nivel 1 completo**: los cuatro héroes (caballero, bárbaro, mago), slime rojo, esqueletos, portones por zona, Mega Caballero, cartas, sonido y música.
3. **Niveles 2 a 4** con sus bichos y jefes (Campeón, Yeti, Kraken), experiencia y evoluciones.
4. **Sillón** (varios joysticks en la misma pantalla) y después el **online**.
