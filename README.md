# Pip y los Slimes · versión Godot

La nueva versión de **Pip y los Slimes** hecha en **Godot 4** con sprites de **PixelLab**.
El juego web original sigue en [Monguit0/pip-slimes](https://github.com/Monguit0/pip-slimes) y no se toca.

## Abrirlo
1. Bajá Godot 4.5 o más nuevo (versión estándar, no hace falta la .NET) desde https://godotengine.org/download
2. En Godot: **Importar** → elegí el `project.godot` de esta carpeta → **Importar y editar**.
3. Apretá **F5** (o el ▶ de arriba a la derecha) para jugar.

La primera vez Godot tarda unos segundos en importar las imágenes.

## Qué hay: el Nivel 1 completo con cuatro héroes
El **Nivel 1 (El Reino)** igual que en el juego web: **título** (con ← y → elegís héroe: arquero, caballero, bárbaro o mago), una **carta** para elegir al empezar, **Pradera**, **Ruinas** y
**Murallas** con sus slimes y esqueletos, monedas y flechas que caen, y el **Salón del Trono** con el **Mega Caballero**. Al ganar o perder,
la pantalla de fin con tus **puntos** y el **récord** (se guarda en la compu); salto vuelve al título para elegir otro
héroe y R reintenta con el mismo.

- Se ve como el original: el mundo es de 256×144, los sprites HD (Pip, slimes, el jefe) se dibujan con el doble de detalle y
  los textos usan la misma fuente de 5×7 del juego web.
- **Música del original**: la misma canción en sus ánimos (título, cartas, una por zona, entrada del jefe, jefe,
  furia, sin casco, victoria y derrota), que cambia a tiempo, cada medio compás; con un solo corazón suena apagada,
  como debajo del agua.
- **Efectos de sonido nuevos**, hechos para el estilo HD: cada uno tiene golpe, cuerpo y cola (la cuerda del arco que
  vibra, la flecha que queda temblando al clavarse, el slime que revienta en gotas, la armadura que suena a metal, el
  rugido con eco de castillo, las pisadas pesadas del caballero), con eco tipo SNES en lo mágico. Suenan tan fuerte
  como los originales y con un poco de variación de tono. Los jsfxr del juego web quedaron en `assets/audio/sfx_original`.
- **Fondos pintados con PixelLab**: cielo con luna, cordillera con el castillo del rey a lo lejos, y adelante el bosque
  de la Pradera, las ruinas con arcos y enredaderas y las murallas con ventanas encendidas; el Salón del Trono tiene
  rosetón, estandartes, trono y antorchas que chisporrotean. Las capas de atrás se oscurecen para que se vean lejos.
- **Sin tirones**: los cuadros de los otros héroes, del jefe y de los esqueletos y la música se cargan en segundo plano
  desde el título (cambiar de héroe no frena), y
  los shaders se compilan al arrancar (antes el primer dash y la entrada al castillo trababan un instante).
- **Pip arquero** con los números del juego web: doble salto, coyote time, salto corto, **dash** intangible, flecha
  normal y **flechazo cargado** (3 de daño, atraviesa). Máximo cuatro flechas en el aire.
- **Caballero** (4 corazones, más lento) con un **mandoble** que llega más lejos: **tajo** (X: corte horizontal con una
  media luna roja, dorada en el Paladín, polvo del pie de atrás y líneas de velocidad), **espadazo** cargado (mantené X: levanta
  el mandoble detrás de la cabeza y lo sostiene, quieto o caminando; al soltar lo baja con todo en un arco grande, pega
  fuerte, atraviesa y corta flechas y ondas, y donde la hoja toca el piso salen un destello, chispas, cascotes, polvo, un
  aro y temblor) y **escudo** (Shift, gasta energía): se da vuelta hacia el golpe y lo para con el escudo adelante,
  y si lo levantás justo antes del golpe hace **PARRY**: devuelve flechas, ondas y espadas que caen, marea al que pegó y
  el contragolpe es crítico seguro (al jefe lo deja aturdido). Corre con el mandoble en alto y las pisadas suenan a
  armadura; si lo dejás quieto un rato hace un floreo con la espada. **Salta** con todo el cuerpo: despega estirado,
  encoge las piernas al subir, arriba la capa se le vuela, cae con las piernas estiradas y al aterrizar se agacha.
- **Bárbaro** (4 corazones, rápido): **hacha** (X, lenta pero pega 3), **giro** cargado (mantené X: tres vueltas que
  pegan alrededor) y **furia** (Shift con la barra llena): 5 segundos con más daño, ataques más rápidos y en rojo.
  Sus golpes tienen el doble de cuadros que antes: el hachazo sube, baja con su estela y **muerde el piso** (chispas,
  polvo, cascotes y un temblor corto); el giro da la vuelta de verdad, con la capa abierta y el barrido del arma en
  naranja (rojo el Warlord). Salta con un grito y el arma en alto, cae abierto listo para aplastar y aterriza con un
  hachazo al piso que sacude la pantalla; en el doble salto da una vuelta carnero con fantasmas.
  Corre embistiendo, con la capa volando, y **camina con el hacha atrás** mientras carga. La **furia** arranca con el
  juego congelado un instante, el piso que se rompe y una columna de brasas, y deja una estela roja al correr; el
  giro cargado sacude la cámara y tira viento y brasas en cada barrido.
- **Mago** (3 corazones): un brujo joven de abrigo rasgado y bastón torcido con una gema roja. **Bastón** (X: una
  estocada corta que pega 1, con la estela de la gema), **bastonazo de fuego** cargado (mantené X: cruza el bastón
  detrás de la cabeza, quieto o caminando, con la magia subiéndole del piso a la gema; al soltar lo baja con todo y
  la gema revienta contra el piso: pega 3, quema, rompe flechas y ondas, y larga un fogonazo, una columna de llamas,
  lenguas de fuego por el piso, cascotes y temblor) y **bola de fuego** (Shift, un poco menos de un tercio de la
  energía): estira el bastón, sale derecho con retroceso, explota al tocar un enemigo, al jefe, una pared o el
  piso, pega 2 al que toca y 1 a los de alrededor, y **quema**: 1 de vida cada 0,8 s durante 2,4 s (se ven las
  llamitas). **Camina como un galán**, con una mano en el pelo y el abrigo abriéndose a cada paso. **Salta como
  un vampiro**: despega sobre un aro con brasas que suben y sube envuelto en el abrigo, arriba de todo queda un
  instante flotando y lo abre de golpe como alas de murciélago (un destello en la gema), planea con las alas
  abiertas y al caer se vuelve a envolver; en caídas largas, una onda y líneas a los costados. En el **doble salto**
  pisa un círculo mágico y gira envuelto en el abrigo (también al rebotar en un bicho). La gema suelta chispas
  todo el tiempo (más cuando carga) y si lo dejás quieto hace un floreo con el bastón.
- Los cuatro hechos con **PixelLab** a 68×68 con los pies en la misma fila, así que comparten física y colisión.
- **Las flechas se clavan** donde pegan (las de Pip y las del esqueleto): en el piso, en las paredes, en los portones
  y en las plataformas si les caen desde arriba. La punta queda adentro, vibran un instante y quedan ahí un rato;
  si el portón sube, la flecha sube con las rejas y se cae al llegar al arco.
- **Críticos** (20%): triple daño, congelado, cámara lenta, zoom, cuadro de impacto en blanco y negro, ¡CRÍTICO!, bombo y chispas.
- **Efectos a medio píxel**, con el mismo píxel que los sprites HD y las rampas de la paleta: las chispas nacen blancas y
  se enfrían hacia su color, el polvo son bollitos que crecen y se deshacen en damero, los cascotes y huesitos rebotan,
  el slime salpica gotas y deja un charco, cada golpe tiene su **estrella** (destello blanco y rayos hacia donde iba el
  golpe), el barrido del jefe deja una **media luna** que sigue a la espada, las explosiones son bollos de fuego, los
  anillos y las ondas en el piso son de píxeles y los números saltan con borde (los grandes con degradé). Al recibir un
  golpe la silueta entera se pone blanca.
- **Juice**: polvo al saltar, caer, correr y derrapar; al despegar un aro de aire en el piso y líneas que quedan abajo;
  en el aire el héroe se estira un poco con la velocidad y cayendo rápido le pasa el viento por al lado; anillo de aire en el doble salto; líneas de velocidad y estela de
  silueta en el dash; chispitas que se juntan en el arco mientras carga y destello cuando está listo; retroceso de cámara
  al disparar y al recibir golpes; destellito en las monedas; el jefe ruge con ondas, embiste levantando polvo, choca
  contra la pared largando piedras y al caer de un salto parte el piso con dos ondas. Los slimes se agachan antes de
  saltar, suben con la boca abierta y parpadean cada tanto; la carrera de Pip va al ritmo de su velocidad.
- **Puntos y combo**: monedas seguidas suben el combo (y la nota, por la escala mayor); pisar slimes da más que flecharlos.
- **Experiencia**: monedas, slimes y el jefe dan EXP; al llenar la barra el héroe **evoluciona** y cambia de aspecto:
  el arquero pasa a **Cazador** (dos flechas por disparo y **veneno** con C, 1 de daño cada 0,7 s), el caballero a
  **Paladín** (armadura blanca y dorada, tajos más largos y cada parry cura un corazón) y el bárbaro a **Warlord**
  (casco con cuernos y martillo de guerra como en el original, giro más ancho y con furia el giro aturde) y el mago
  a **Nigromante** (capucha, máscara de calavera y bastón con una calavera en llamas verdes: su fuego pasa a ser
  verde y con C, por media barra de energía, **invoca dos esqueletos aliados** al azar, de hacha o de arco: salen de
  la tierra a sus costados, buscan al enemigo más cercano, lo siguen entre zonas, pegan de a 1 y duran 12 segundos
  o 2 golpes; si invoca de nuevo, los viejos se deshacen). Al evolucionar recupera la vida.
- **Cartas**: las comunes (corazón extra, poción de emergencia, cristal de maná, botas ligeras, concentración, paso
  fantasma), la de daño de cada uno (arco reforzado, espada afilada, hacha pesada, bastón rúnico) y las propias:
  flecha triple (arquero), escudo liviano (caballero), sangre caliente y remolino (bárbaro), gran bola y brasas
  eternas (mago). Solo te salen las de tu héroe.
- **Esqueletos** (los del modo villano del original, hechos con PixelLab): el **arquero** guarda distancia y te tira
  flechas rectas; el **hachero** te persigue, levanta el hacha (titila) y pega un hachazo adelante. Salen de la tierra,
  respiran mientras esperan, se doblan con cada golpe, se pueden pisar o flechar y se desarman en una pila de huesos. Uno en la Pradera, tres en las Ruinas, cuatro en las Murallas.
- **Flechas que caen** del cielo con aviso (más seguido en cada zona; de a tres en las murallas). Si le caen a un enemigo, lo aplastan.
- **Mega Caballero** (animado con PixelLab, en ciclos de 12 cuadros: respira, camina al paso de lo que avanza, embiste
  corriendo, se marea, cae de rodillas, **ruge con el puño en alto** y **salta entero**: se agacha, despega, encoge las
  piernas, levanta la espada, cae con todo y se levanta. En el barrido el brazo toma 19 poses según el ángulo de la espada).
  La espada se dibuja en código porque gira con cada ataque, pero **se ve agarrada** (los dedos se dibujan encima del mango)
  y es **firme**: va rígida con el brazo, entre dos poses gira rápido sin pasarse y el espadazo se clava de golpe. En la
  lluvia de espadas la levanta, destella con la orden y la deja quieta en alto. Cae del techo, ruge y
  pelea con **barrido**, **salto con ondas de choque**, **embestida** (si choca contra la pared queda mareado y recibe 50% más
  de daño) y **lluvia de espadas** con un hueco para esquivar. Al 50% se enfurece (repite y encadena ataques) y al 25%
  **pierde el casco**. Se le pega con flechas o pisándole la cabeza. Al caer explota y su espada queda clavada en el piso.

## Modo Villano

En el título, **arriba y abajo** cambian de modo: *Campaña* o *Villano*. En Villano sos el malo: manejás a los
bichos, de a uno, contra los **cuatro héroes** (arquero, caballero, bárbaro y mago), que maneja el juego.
Son tres zonas (Pradera, Ruinas y Murallas) y al final el Salón del Trono, donde manejás al Mega Caballero.

- **Controles del slime**: ← → mover, `Z` salto, abajo + `Z` bajar de la plataforma, y **mantener `X` y soltar**
  para escupir baba en arco: cuanto más la cargás (hasta 0,7 s; se ve la barrita y el slime se aplasta), más
  lejos llega. Mientras carga camina a la mitad. La baba le saca 1 al héroe que toca; el espadazo de un héroe la
  rompe y el escudo del caballero la frena. Tocar a un héroe también lo lastima, pero si te pisa, te revienta.
  Mientras cargás se ve la **guía del tiro**: puntitos por donde va a ir la baba y una marca donde va a caer.
  Manteniendo `Shift`, el **turbo de baba**: resbala sobre su propia baba 2,6 veces más rápido mientras le quede
  barra (1,8 s llena; se ve debajo del slime). Al soltarlo se recarga sola en unos 2,6 s; si la vaciás del todo
  (*¡SIN TURBO!*) queda bloqueada hasta que junte un cuarto.
- **Controles de los esqueletos** (Ruinas y Murallas): mover, salto, bajar y turbo igual que el slime. Con `X`
  el **arquero** tira una flecha (recarga 0,45 s) y el **hachero** pega el hachazo al toque, sin levantar antes
  el hacha (recarga 0,55 s); el hachazo saca 2 y le pega a todos los héroes que agarre. En cada zona empezás en
  un bicho distinto: slime en la Pradera, arquero en las Ruinas, hachero en las Murallas.
- **Ataques nuevos de los esqueletos** (también en la campaña, cuando los maneja el juego): el **hachero lanza
  el hacha** (`C`, o `Y` en joystick): sale girando, se frena a unos 90 px y vuelve sola a su mano; saca 1 a la
  ida y 1 a la vuelta y atraviesa plataformas. Mientras vuela queda con las manos vacías (cuadros `idle_bare` y
  `walk_bare`, hechos con PixelLab) y no puede pegar. El juego la tira a media distancia, avisando 0,45 s. El
  **arquero carga un tiro triple** manteniendo `X` 0,7 s (barrita arriba; camina a la mitad): al soltar salen
  tres flechas, arriba, medio y abajo. El juego lo usa en uno de cada tres tiros, tensando más y con chispas.
  Y al morir **revientan en huesos**: calavera, huesos largos, costillas y astillas que giran y rebotan
  (`scripts/bone.gd`, `scripts/axe.gd`).
- **El Mega Caballero** (Salón del Trono): ← → caminar, `X` **tajo** (saca 2, recarga 0,8 s), `Z`/espacio
  **salto** con ondas (1,6 s; mientras junta fuerza lo apuntás con ← →), `Shift` **carga** (3,2 s; no queda
  mareado contra la pared) y `C` **lluvia** de espadas apuntada: una sobre cada héroe y cuatro al azar (6,5 s).
  Abajo se ven los cuatro ataques: en amarillo el que está listo. Con media vida o menos (furia) las recargas
  bajan y podés **encadenar**: pedir otro ataque mientras se recupera del anterior lo saca sin pausa, con el
  aviso a la mitad y un punto más de daño (*COMBO x2, x3...*). Entre golpe y golpe que recibe tiene 0,2 s de
  respiro. Los héroes le pegan de cerca o de lejos según quién sea, se corren del tajo, saltan las ondas, a la
  embestida le pasan por arriba con un salto doble (7 de cada 10 veces; si caen sobre el yelmo, lo pisan) y se
  apartan de donde va a caer una espada, pero no siempre.
- **Posesión**: una flechita amarilla marca al que manejás. Cuando lo matan, tu alma queda suelta un segundo
  (*BUSCANDO OTRO CUERPO...*), viaja en un arco de chispas celestes y entra en el slime que esté más cerca de los
  héroes (*AHORA SOS...*). La cámara te sigue a vos.
- **Los demás slimes** los maneja el juego: el verde patrulla a saltitos y escupe al héroe que tenga a tiro; el
  rojo lo persigue, le salta encima y de lejos también escupe.
- **Los héroes** piensan cada 0,14 a 0,28 s: van al enemigo más cercano, el arquero y el mago guardan distancia
  (el mago tira bolas de fuego), el caballero y el bárbaro van al cuerpo a cuerpo, suben a las plataformas por la
  que les sirve de escalón, se dejan caer si el enemigo está abajo y esquivan la baba que les viene cayendo, pero
  no siempre.
- **Cómo sigue y cómo termina**: si caen los cuatro héroes, ganaste (*¡DETUVISTE A LOS HÉROES!*, o *¡DEFENDISTE
  EL TRONO!* si fue con el jefe). Si te quedás sin bichos, la zona está perdida: se abre el portón, los héroes
  cruzan, los que llegaron recuperan 2 corazones y los esperan los bichos de la zona que sigue. Al trono llegan
  curados del todo. Si tumban al Mega Caballero, ganaron ellos (*CAYÓ EL TRONO*). Al final te dice cuántos héroes
  tumbaste y cuántos corazones les sacaste. El récord de la campaña no se toca.
- **HUD**: arriba a la izquierda la vida de cada héroe (y una flecha de su color al borde si quedó fuera de la
  pantalla), arriba al medio los enemigos que te quedan y los refuerzos por llegar, abajo qué sos y cómo atacás.

Diferencias con el original, a propósito, porque acá los héroes limpian una zona mucho más rápido que en la web:
los slimes tienen **1 de vida más** (3 el verde, 4 el rojo), los héroes del bot **avanzan al 62%** de su velocidad
y pegan un poco más espaciado, hay **refuerzos** que van llegando de a uno cuando cae alguno (seis en la Pradera,
cuatro en las Ruinas y en las Murallas) y el Mega Caballero que manejás tiene **60 de vida** (42 en la web). Son
números para ajustar jugando. Todavía no hay cartas del villano, ni experiencia y evolución de los héroes.

Código: `scripts/hero_bot.gd` (el bot: `botThink`, `botClimb` y `botDodge`), `scripts/spit.gd` (la baba: `lob` y
`updateShots`), en `scripts/slime.gd` la parte "modo Villano" (`playerMob`, `aiMob`, `aiLob`), en `scripts/main.gd`
la parte "modo Villano" (`possessNext`, `enterInvadeZone`, los refuerzos y el final), en `scripts/skeleton.gd` y
`scripts/boss.gd` lo que va con `ctrl` (`mobShoot`, `mobSwing`, `updatePlayerBoss`), `scripts/turbo.gd` (el turbo
y las marcas del bicho que manejás) y en `scripts/player.gd`, `_down` y `_tap`: las
acciones del héroe salen del teclado o de lo que decide el bot.

## Multijugador local

Tercer modo del título (**arriba y abajo**): es el modo Villano, pero cada lugar lo puede manejar una persona, en
la misma compu, con el teclado y hasta ocho joysticks. Los lugares que nadie elige los maneja el juego.

- **La sala**: cinco lugares (Villano, Arquero, Caballero, Bárbaro, Mago). Cada control se suma con `A` (o
  espacio / `X` en el teclado) y cae en el primer lugar libre; con ← → se cambia a otro libre; `B` (o Esc) lo
  deja, y sin lugar cierra la sala. `START` (o Enter) arranca. Debajo de cada lugar dice quién lo tiene o *BOT*.
- **El villano también puede ser bot**: si nadie lo elige, los bichos y el Mega Caballero se manejan solos y
  todas las personas juegan de héroes, en cooperativo.
- **Joystick**: cruz o palanca mover · `A` saltar · `X` o `RB` atacar · `B` o `LB` especial (turbo del bicho,
  carga del jefe) · `Y` poder (lluvia del jefe) · `START` empezar. El teclado, igual que siempre.
- **La cámara**: si las personas se separan, se aleja apoyada en el piso hasta mostrar la zona entera (dos
  pantallas) y se acerca despacio cuando se juntan. Con la cámara ya lo más lejos posible, el que se sigue
  alejando espera a los demás. En el Salón del Trono vuelve a la normal.
- **Pasar de zona**: cuando un héroe cruza el portón abierto, cruzan todos: los demás aparecen a su lado.
  Hay **10 segundos** para cruzar (cuenta regresiva arriba, que late en rojo los últimos 3, y una flecha que
  parpadea hacia el portón). Si nadie cruza a tiempo, **llueven espadas**: una sobre cada héroe y otras al azar,
  cada vez más y con menos aviso; atraviesan las plataformas, así que no hay resguardo ni arriba ni abajo de
  una. Son **imparables** (rojas): ni un golpe las rompe ni el escudo las frena. A los **20 segundos** se suman
  espadas que cruzan la pantalla **de costado**, de un lado y del otro, a la altura de alguno de los que faltan,
  cada vez más seguido (`scripts/side_sword.gd`). Además, los que llegan tarde se quedan sin los 2 corazones de
  premio. Vale también en el modo Villano.
- **En pantalla**: sobre cada héroe manejado por una persona, una flechita con su control (*TEC*, *J1*...) y en
  la lista de arriba, su barra de energía. Los héroes de las personas corren a velocidad completa (los del bot
  siguen al 62%). El héroe que cae no vuelve en esa partida.
- **Final**: *¡GANARON LOS HÉROES!* si cae el Mega Caballero, *GANÓ EL VILLANO* si caen los cuatro. `R` es la
  revancha con los mismos lugares (solo en el teclado: ningún botón del joystick reinicia); volviendo al título se pasa otra vez por la sala.

Código: `scripts/ctl.gd` (los controles por dispositivo: cada uno tiene sus acciones, `kb_saltar`, `j0_saltar`...),
en `scripts/main.gd` la parte "multijugador local" (`lobby_step`, los lugares en `seats`, la cámara que se aleja
en `_update_camera`) y en `scripts/hud.gd`, `_draw_lobby`.

## Cómo está armado
- `scenes/main.tscn`: la escena principal; el nivel se arma por código en `scripts/main.gd` (zonas, plataformas,
  portones y antorchas están en constantes arriba de todo, copiadas del original).
- `assets/level1/`: el Reino. `level.png` (suelo y plataformas) y las nubes vienen del juego web; el cielo, las montañas,
  la capa del medio y el salón los arma `tools/bg/compose.py` con piezas de PixelLab (las capas viejas, en `original/`).
- `scripts/fireball.gd`: la bola de fuego del mago (`castFire`, `stepSpell` y `explodeSpell` del original) y su
  fogonazo; `scripts/ally.gd`: los esqueletos aliados del Nigromante (`summonSkeletons` y `updateAllies`). La
  quemadura es `apply_burn` en los slimes, los esqueletos y el jefe.
- `scripts/player.gd`: los cuatro héroes (`HEROES` arriba de todo: vida, velocidad, salto, carpeta de sprites y de la
  evolución). Las constantes vienen de `CHARS` y `SK` del `index.html` original.
- `scripts/slime.gd`: slime verde y rojo (`updateGreen` y `updateRed` del original). Ya lee las cuatro filas de la hoja (verde, rojo, tóxico, hielo).
- `scripts/pal.gd`: la paleta de 9 bits del original (`Pal.K`, `Pal.Y`...).
- `scripts/boss.gd`: el Mega Caballero (`updateBoss`, `bossTele`, `bossAct`, `damageBoss` del original).
- `scripts/skeleton.gd`: esqueleto arquero y hachero (`aiMob`, `mobShoot` y `mobSwing` del original); `scripts/enemy_arrow.gd` su flecha.
- `scripts/coin.gd`, `scripts/hazard.gd` (flechas y espadas que caen), `scripts/wave.gd` (ondas de choque), `scripts/arrow.gd`,
  `scripts/stick.gd` (dónde se clavan las flechas).
- `scripts/fx.gd` (autoload `Fx`: partículas, polvo, cascotes, gotas, estrellas de golpe, tajos, explosiones, anillos,
  textos, temblor y empujón de cámara, hitstop, cámara lenta, críticos), `scripts/pix.gd` (dibujo a medio píxel y rampas
  de color para los efectos), `scripts/snd.gd` (autoload `Snd`:
  efectos y música), `scripts/ptext.gd` (la fuente del original), `scripts/hud.gd`, `scripts/background.gd`.
- `assets/audio/`: los sonidos (`sfx/`, WAV, sintetizados por `tools/sfx`) y la música (`music/`, OGG, una vuelta de la
  canción por ánimo, exportada del juego web).
- `assets/sprites/items/`: moneda (y `coin_spin.png`, la moneda girando con su canto, que arma `tools/ui/coin_spin.py`),
  corazones, aviso, flecha y espada que caen, y los dibujos viejos de las cartas.
- `assets/sprites/ui/`: el HUD en HD. Marcos de las barras de energía, experiencia y del jefe con su medallón, el marco
  de las cartas con su brillo (los dibuja `tools/ui/hud_parts.py`), y de **PixelLab** los íconos del rayo, la estrella
  y el yelmo de los medallones y los dibujos de las 8 cartas (`carta_<id>.png`, 64×64). El corazón, la moneda y el
  aviso de lo que cae (`items/heart.png`, `coin.png`, `warn.png`) también son de PixelLab.
- `assets/sprites/boss/`: el Mega Caballero hecho con **PixelLab**, `helm/` con casco y `bare/` sin casco, cada uno con
  `idle/`, `walk/`, `charge/` (12 cuadros), `dazed/`, `death/`, `jump/` (14 cuadros del salto con espadazo), `roar/` y
  `arc/` (19 poses del brazo, de atrás de la cabeza hasta adelante). Lienzo de 144×144 con los pies en (72, 118); dónde
  está el puño en cada cuadro va en `HANDS` (y el ángulo de la espada de cada pose en `ANGS`), arriba de `boss.gd`.
  Cada carpeta tiene además `fist.png`: el puño de cada cuadro recortado (14×14), que se dibuja encima del mango.
- `assets/sprites/skel/`: los esqueletos de **PixelLab** (`arch/` y `axe/`, con `idle/` (respira), `walk/`, `atk/`, `hurt/` y `death/`, lienzo de 68×68).
- `assets/sprites/slimes.png`: la hoja de slimes de 32 bits sacada tal cual del juego web.
- `assets/sprites/pip/`: Pip hecho con **PixelLab** (personaje "Pip arquero", vista lateral, 48×48):
  `east.png` y las carpetas `idle/`, `run/`, `jump/`, `fall/`, `shoot/` (tensar el arco), `aim/` (apuntando en loop, con la capa al viento), `release/` (soltar con retroceso), `dash/`, `hurt/` y `death/` con un PNG por cuadro. Mira a la derecha; para la izquierda se espeja.
  Si falta alguna carpeta, el juego usa el cuadro quieto. `pip_cazador/` es la evolución.
- `assets/sprites/mago/` y `nigromante/`: el mago y su evolución, de **PixelLab** (lienzo de 68×68, pies en la fila
  54), con `idle/`, `run/`, `jump/`, `fall/`, `land/`, `attack/` (estocada), `charge/`, `charge_hold/`, `charge_walk/`,
  `big/` (bastonazo), `cast/` (bola de fuego), `apex/` (arriba de todo del salto), `twirl/` (el giro del doble salto), `hurt/`, `death/`, `flourish/` (solo el mago) y `summon/` (solo el
  Nigromante). Recetas `mago.json` y `nigromante.json` en `tools/heroes/recetas`.
- `assets/sprites/caballero/`, `barbaro/`, `paladin/` y `warlord/`: los otros héroes y sus evoluciones, de **PixelLab**
  (lienzo de 68×68, pies en la fila 56; el tajo y el espadazo, más anchos, con el mismo centro), con `idle/`, `run/`,
  `jump/`, `fall/`, `attack/`, `charge/`, `hurt/`, `death/` y lo propio: `big/`, `shield/`, `charge_hold/` y `charge_walk/`
  (cargando quieto y caminando), `flourish/` (el floreo cuando se queda quieto) y `land/` (aterrizaje) el caballero, `spin/`, `fury/`, `charge_hold/` y `land/` el bárbaro. Los pasa al juego `tools/heroes/cuadros.py`
  (ver `tools/heroes/LEEME.md`).

## Plan
1. **Base**: proyecto, Pip arquero, slimes y el Reino. ✔
2. **Nivel 1 completo con el arquero**: música, sonidos, juice, monedas, cartas, evolución y Mega Caballero. ✔
   Caballero, bárbaro y mago con sus evoluciones ✔. Modo Villano completo ✔ (Pradera, Ruinas, Murallas y el Mega Caballero). Multijugador local ✔ (falta el online).
3. **Niveles 2 a 4** con sus bichos y jefes (Campeón, Yeti, Kraken), experiencia y evoluciones.
4. **Sillón** (varios joysticks en la misma pantalla) y después el **online**.
