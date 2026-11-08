# Efectos de sonido

Los efectos de `assets/audio/sfx` se arman con estos scripts (Python 3 + numpy), sintetizados por capas:
un golpe inicial, el cuerpo del sonido y una cola, con filtros, FM, cuerdas pulsadas, parciales de metal
y madera, un poco de saturación y el eco tipo SNES en los sonidos mágicos y en el castillo.

    python3 build.py ../../assets/audio/sfx_original ../../assets/audio/sfx            # todos
    python3 build.py ../../assets/audio/sfx_original ../../assets/audio/sfx moneda dash  # algunos

`build.py` iguala la sonoridad de cada uno con la del sonido original del mismo nombre (los jsfxr del
juego web quedaron en `assets/audio/sfx_original`), así los volúmenes del código siguen andando.
Para volver a los originales alcanza con copiar esos `.wav` encima de los de `assets/audio/sfx`.
