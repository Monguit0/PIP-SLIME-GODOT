# Cuadros de `assets/sprites/bosque/planta/rise` (el mordisco hacia arriba)

Salen de una animación de PixelLab (Animate Image, 64x128, la planta abajo y lugar libre arriba) en la que la
planta estira el tallo y abre la boca hacia el costado. Para que la boca mire hacia arriba y el cuello sea
corto, a los cuadros con la boca abierta se les hizo, con PIL:

1. cortar la cabeza (todo lo que está arriba del cuello) y girarla 90° en sentido antihorario (giro exacto,
   sin redibujar);
2. dejar solo 5 filas de tallo sobre los brazos (fila 80) y apoyar ahí la cabeza girada, centrada en el tallo.

Orden: 0 saliendo (sin girar) · 1, 2, 3 abriendo la boca · 4, 5 cerrando · 6, 7 la cabeza vuelve (sin girar).
