# Héroes (caballero y bárbaro)

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
| run      | corre                             | corre                                |
| jump/fall| salto (subiendo / bajando)        | salto (subiendo / bajando)           |
| attack   | espadazo                          | hachazo                              |
| charge   | levanta la espada (carga)         | levanta el hacha (carga)             |
| big      | espadazo cargado                  | —                                    |
| spin     | —                                 | giro con el hacha (el brillo verde de PixelLab pasa a fuego) |
| shield   | levanta el escudo                 | —                                    |
| fury     | —                                 | ruge (furia)                         |
| hurt     | recibe un golpe                   | recibe un golpe                      |
| death    | cae                               | cae                                  |

Las evoluciones van en `assets/sprites/paladin/` y `assets/sprites/warlord/` con las mismas carpetas.
