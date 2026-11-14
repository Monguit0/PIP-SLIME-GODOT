# Fondos

Las piezas de `piezas/` salieron de PixelLab (Create Image Pro, con la paleta de 9 bits del juego):
cielo, cordillera, castillo del rey, bosque, ruinas, murallas y el salón del trono.
`compose.py` arma con ellas las capas que usa el juego en `assets/level1`:

- `sky.png` (fijo), `far.png` (parallax 0.25: montañas con el castillo del rey tapando la unión),
  `mid.png` (parallax 0.5: bosque, ruinas y murallas, según la zona) y `arena.png` (salón del trono).
- Las capas de atrás se oscurecen y se tiñen de azul noche para que se vean lejos; las ventanas
  encendidas siguen brillando. Todo queda en la paleta de 9 bits como el resto del arte.

    python3 compose.py            # escribe en ../../assets/level1

Las capas anteriores quedaron en `assets/level1/original`.
