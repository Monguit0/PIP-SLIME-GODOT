# Héroes (caballero, bárbaro y sus evoluciones)

Los cuadros salen de **PixelLab** (personajes de 48 px, vista lateral, mirando al este), animados con
`animate_character` en modo v3 (lienzo de 68×68). `cuadros.py` los pasa a la paleta de 9 bits, saca el
fondo, deja los pies en la fila 56 y los guarda en `assets/sprites/<héroe>/<animación>/frame_NNN.png`.

    python3 tools/heroes/cuadros.py tools/heroes/recetas/caballero.json [--hojas carpeta] [animaciones...]

La receta dice de qué hoja, fila y cuadros sale cada animación. Las hojas son las del `pixelart_workbench`
de PixelLab (`join character:<id>:east:<anim> ... --as rows`, o `--as sheet --columns N` para una grilla), que
hay que bajar al lado de la receta (o en la carpeta de `--hojas`). Se pueden pasar solo algunas animaciones.

El tajo, el espadazo y el salto del caballero y del Paladín van en un lienzo más grande que 68×68 cuando
hace falta (la hoja y la media luna se salen), con el mismo centro para que el sprite no salte. Se generaron
arrancando del cuadro quieto pegado en un lienzo más grande (104×80 los golpes, 104×104 el salto) para que
PixelLab no corte la punta de la espada. La estela clara que dibuja PixelLab pasa a la rampa del héroe (roja
el caballero, dorada el Paladín) con dos bordes de color por fuera (`estelas` en la receta). En el salto cada
cuadro se acomoda con la cabeza y el torso donde están en el quieto (`"alinear": "torso"`).

Animaciones que usa `scripts/player.gd`:

| carpeta  | caballero                         | bárbaro                              |
|----------|-----------------------------------|--------------------------------------|
| idle     | respira con la espada baja        | respira con el hacha                 |
| run      | corre con el mandoble en alto     | corre                                |
| jump/fall| salto: despega estirado, encoge las piernas al subir; arriba la capa vuela y cae con las piernas estiradas (el cuadro sale de la velocidad) | el mismo salto completo, con el hacha al hombro |
| land     | se agacha al aterrizar            | se agacha al aterrizar               |
| attack   | tajo con media luna (roja / dorada) | hachazo de 11 cuadros a 32 por segundo: levanta, baja con estela (naranja / roja) y muerde el piso |
| charge   | levanta la espada (carga)         | lleva el hacha atrás (carga)         |
| charge_hold | sostiene el mandoble en alto (loop) | sostiene el hacha atrás, tenso (loop) |
| charge_walk | camina con el mandoble en alto (loop) | —                               |
| big      | espadazo cargado de arriba abajo con un arco grande | —                  |
| spin     | —                                 | giro de 12 cuadros: dos barridos con el cuerpo dando la vuelta y la capa abierta; el barrido del arma se tiñe con la rampa (`"barrido"` en la receta) |
| shield   | levanta el escudo adelante        | —                                    |
| flourish | floreo con el mandoble (quieto 5 s) | —                                  |
| fury     | —                                 | ruge (furia)                         |
| hurt     | recibe un golpe                   | recibe un golpe                      |
| death    | cae                               | cae                                  |

Las evoluciones van en `assets/sprites/paladin/` y `assets/sprites/warlord/` con las mismas carpetas
(recetas `paladin.json` y `warlord.json`). Son el estado "Paladin" del caballero (armadura blanca y dorada,
penacho dorado, capa blanca y escudo blanco con cruz) y el estado "Warlord" del bárbaro (casco con cuernos,
capa de piel negra y martillo de guerra, como en el juego web). Al evolucionar, `player.gd` cambia los
cuadros en el mismo punto de la misma animación.

El caballero y el Paladín llevan un mandoble (estados "Espada grande" y "Paladin espada grande" en PixelLab).
`charge_hold`, `charge_walk` y `run` se animaron desde un cuadro propio (el último o el segundo de `charge`),
así que vienen en otro lienzo: la receta da el tamaño de esas hojas y con qué cuadro tienen que calzar.
