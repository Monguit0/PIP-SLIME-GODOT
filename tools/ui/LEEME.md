# HUD en HD

Todo se dibuja a la resolución HD del juego (1 píxel = medio píxel lógico) y con la paleta de 9 bits.

- `hud_parts.py`: marcos de las barras de energía (`bar_energia.png`) y experiencia (`bar_exp.png`) con su medallón,
  la barra del jefe (`bar_jefe.png`), el marco de las cartas (`carta.png`, con 2 px de margen) y el brillo de la carta
  elegida (`carta_brillo.png`). El hueco de cada barra empieza donde dice el script; `hud.gd` corre la textura para que
  el relleno caiga justo en `EN`, `XPB` y `BOSS`.
- Los íconos (rayo, estrella y yelmo de los medallones, los 8 dibujos de las cartas a 48×48, corazón, moneda y el
  aviso) son de PixelLab (Create Image Pro con la paleta de 9 bits): de cada tanda de candidatos se eligió uno y se
  pasó a 9 bits. El corazón vacío es el mismo dibujo apagado en azul noche.
- `coin_spin.py`: la moneda girando (8 cuadros de media vuelta, con el canto) a partir de la cara de frente.

```
python3 tools/ui/hud_parts.py assets/sprites/ui/
python3 tools/ui/coin_spin.py assets/sprites/items/coin.png assets/sprites/items/coin_spin.png
```
