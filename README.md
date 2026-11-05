# Pip y los Slimes · versión Godot

La nueva versión de **Pip y los Slimes** hecha en **Godot 4** con sprites de **PixelLab**.
El juego web original sigue en [Monguit0/pip-slimes](https://github.com/Monguit0/pip-slimes) y no se toca.

## Abrirlo
1. Bajá Godot 4.5 o más nuevo (versión estándar, no hace falta la .NET) desde https://godotengine.org/download
2. En Godot: **Importar** → elegí el `project.godot` de esta carpeta → **Importar y editar**.
3. Apretá **F5** (o el ▶ de arriba a la derecha) para jugar.

La primera vez Godot tarda unos segundos en importar las imágenes.

## Qué hay (etapa 1)
Un nivel de prueba en la Pradera con **Pip arquero** y **slimes verdes**, a 256×144 escalado sin borronear (igual que el juego web).
Gana el que limpia todos los slimes.

- **Pip** se mueve con los mismos números del juego web: velocidad, salto, **doble salto**, coyote time,
  salto corto si soltás el botón, y caída un poco más pesada.
- **Dash** (gasta energía, un dash por salto): por un instante es intangible y atraviesa slimes.
- **Arco**: tocá atacar para una flecha; mantenelo hasta que Pip brille y soltá para el **flechazo cargado**
  (más rápido, 3 de daño, atraviesa). Mientras carga no se mueve; saltar cancela.
- **Slimes verdes**: patrullan su plataforma a saltitos. Te pegan si los tocás; si les caés encima, los pisás y rebotás.
- Juice: estirar y aplastar, chispas, temblor, hitstop, estela del dash, números de daño.
- Plataformas que se atraviesan desde abajo (abajo + salto para bajar) y pozos.

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
- `scenes/main.tscn`: la escena principal; el nivel se arma por código en `scripts/main.gd` (tramos de suelo,
  plataformas y dónde aparece cada slime están en constantes arriba de todo, fáciles de cambiar).
- `scripts/player.gd`: Pip arquero. Las constantes vienen de `CHARS.archer` y `SK` del `index.html` original.
- `scripts/slime.gd`: slime verde (`updateGreen` del original). Ya lee las cuatro filas de la hoja (verde, rojo, tóxico, hielo).
- `scripts/arrow.gd`, `scripts/fx.gd` (autoload `Fx`: partículas, temblor, hitstop), `scripts/hud.gd`, `scripts/background.gd`.
- `assets/sprites/slimes.png`: la hoja de slimes de 32 bits sacada tal cual del juego web.
- `assets/sprites/pip/`: Pip hecho con **PixelLab** (personaje "Pip arquero", vista lateral, 48×48):
  `east.png` y las carpetas `idle/`, `run/`, `jump/`, `fall/` con un PNG por cuadro. Mira a la derecha; para la izquierda se espeja.
  Si falta alguna carpeta, el juego usa el cuadro quieto.

## Plan
1. **Base** (esto): proyecto, Pip arquero, slime verde y un nivel de prueba.
2. **Nivel 1 completo**: los cuatro héroes (caballero, bárbaro, mago), slime rojo, esqueletos, portones por zona, Mega Caballero, cartas, sonido y música.
3. **Niveles 2 a 4** con sus bichos y jefes (Campeón, Yeti, Kraken), experiencia y evoluciones.
4. **Sillón** (varios joysticks en la misma pantalla) y después el **online**.
