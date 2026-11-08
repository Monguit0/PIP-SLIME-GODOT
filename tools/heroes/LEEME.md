# Héroes (caballero, bárbaro y sus evoluciones)

Los cuadros salen de **PixelLab** (personajes de 48 px, vista lateral, mirando al este), animados con
`animate_character` en modo v3 (lienzo de 68×68). `cuadros.py` los pasa a la paleta de 9 bits, saca el
fondo, deja los pies en la fila 56 y los guarda en `assets/sprites/<héroe>/<animación>/frame_NNN.png`.

    python3 tools/heroes/cuadros.py tools/heroes/recetas/caballero.json

La receta dice de qué hoja, fila y cuadros sale cada animación. Las hojas son las del `pixelart_workbench`
de PixelLab (`join character:<id>:east:<anim> ... --as rows`), que hay que bajar al lado de la receta.

Animaciones que usa `scripts/player.gd`:

| carpeta  | caballero                         | bárbaro                              |
|----------|-----------------------------------|--------------------------------------|
| idle     | respira con la espada baja        | respira con el hacha                 |
| run      | corre con el mandoble en alto     | corre                                |
| jump/fall| salto (subiendo / bajando)        | salto (subiendo / bajando)           |
| attack   | espadazo                          | hachazo                              |
| charge   | levanta la espada (carga)         | levanta el hacha (carga)             |
| charge_hold | sostiene el mandoble en alto (loop) | —                                 |
| charge_walk | camina con el mandoble en alto (loop) | —                               |
| big      | espadazo cargado                  | —                                    |
| spin     | —                                 | giro con el hacha (el brillo verde o celeste de PixelLab pasa a fuego) |
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
