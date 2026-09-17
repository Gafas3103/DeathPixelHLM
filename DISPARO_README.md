# Animación de disparo — DeathPixel (HLM)

Resumen de lo que se agregó al proyecto para que el disparo se vea y se sienta.
**No se tocó el sistema de apuntado**: los personajes siguen rotando con
`look_at(get_global_mouse_position())` exactamente como estaba.

---

## 1. Qué archivos son nuevos

| Archivo | Para qué sirve |
|---|---|
| `Scripts/CharacterVisuals.gd` | Componente visual: pose de disparo, retroceso, fogonazo, casquillo. |
| `Scripts/AnimNames.gd` | Utilidad para reproducir animaciones sin depender del nombre exacto. |

## 2. Qué archivos se modificaron

| Archivo | Cambio |
|---|---|
| `Scenes/Player.tscn` | Se agregó `AnimatedSprite2D` (sprites Swat) y el nodo `Visuals`. |
| `Scenes/Second.tscn` | Igual, con los sprites Swat2. |
| `Scenes/Bala.tscn` | Ahora es un `Area2D` (antes `Node2D`, no colisionaba con nada). |
| `Scenes/Enemy.tscn` | Se llenó el `SpriteFrames` que estaba vacío. |
| `Scripts/player.gd`, `Scripts/HoldMovement.gd` | Cadencia de fuego, boca de cañón, llamada a `visuals.fire()`. |
| `Scripts/bala.gd` | Colisión, daño, chispas de impacto, autodestrucción. |
| `Scripts/Enemy/enemy.gd` | Vida, parpadeo al recibir daño, empuje y muerte. |
| `Scripts/hud.gd` | Corregido un bug de precedencia (`and` / `or`) en el respawn. |
| `Scenes/HUD.tscn` | Corregido un `uid` de script que no existía. |
| `project.godot` | Nombres de las capas de física. |

---

## 3. Cómo funciona la animación de disparo

El nodo `Visuals` (script `CharacterVisuals.gd`) es hijo del `CharacterBody2D`.
Cuando el jugador dispara, `player.gd` llama a:

```gdscript
visuals.fire()
```

y eso hace tres cosas a la vez:

1. **Pose de disparo** — reproduce la animación `shoot` (frame `SwatAttack`)
   durante `shoot_hold_time` segundos y luego vuelve sola a `idle` o `walk`.
2. **Retroceso** — un `Tween` empuja el sprite hacia atrás (eje `-X` local,
   o sea en dirección contraria a la mira) y lo devuelve con rebote.
3. **Fogonazo** — un destello dibujado por código (`Polygon2D` en estrella)
   aparece en la boca del cañón y se desvanece en ~0.06 s, más un casquillo
   que sale volando.

Todo es configurable desde el Inspector, seleccionando el nodo `Visuals`.

### Parámetros que vale la pena tocar

| Parámetro | Default | Qué hace |
|---|---|---|
| `recoil_distance` | 7.0 | Cuántos píxeles "patea" el sprite. Súbelo para escopeta. |
| `recoil_out_time` | 0.16 | Qué tan rápido vuelve. Más alto = más pesado. |
| `shoot_hold_time` | 0.13 | Cuánto dura visible la pose de ataque. |
| `muzzle_offset` | (32, -4) | Dónde nace el fogonazo. Ajústalo si no cuadra con el arma. |
| `flash_size` | 12.0 | Tamaño del destello. |
| `keep_upright` | true | Ver punto 5. |
| `fire_rate` (en el player) | 0.18 | Segundos entre disparos. |
| `automatic` (en el player) | false | `true` = mantener clic para ráfaga. |

---

## 4. Capas de física

Se ordenaron para que las balas no le peguen a quien dispara:

| Capa | Nombre | Quién está ahí |
|---|---|---|
| 1 | Mundo | TileMap del mapa |
| 2 | Jugador | los dos personajes |
| 3 | Enemigo | `Enemy.tscn` |
| 4 | Bala | `Bala.tscn` (tuya) |
| 5 | Bala enemiga | `BalaEnemy.tscn` |

Tu bala vive en la capa **4** y detecta **1 y 3**: atraviesa a los jugadores
pero choca con paredes y enemigos. La bala enemiga vive en la **5** y detecta
**1 y 2**: choca con paredes y contigo, pero no con otros enemigos.

Al impactar llama a `apply_bullet_hit(daño, dirección)` y, si el objetivo no
tiene ese método, a `take_damage(daño)`. Cualquier cosa a la que le quieras
poder disparar solo necesita uno de esos dos métodos.

---

## 5. Nota importante sobre los sprites

Los sprites `Swat*` están dibujados **de frente**, pero el cuerpo rota con
`look_at()`. Si el sprite rotara junto con el cuerpo se vería acostado.

Por eso `CharacterVisuals.gd` tiene `keep_upright = true`: mantiene el sprite
derecho y solo lo voltea a izquierda/derecha según hacia dónde apuntes, mientras
el `CharacterBody2D` sigue rotando normalmente por debajo (así el disparo, la
dirección de la bala y todo el código del grupo siguen funcionando igual).

Si algún día el grupo pasa a arte top-down de verdad (como `hitman1_silencer.png`),
solo hay que poner `keep_upright = false` y `flip_with_aim = false`.

El `Sprite2D` viejo con `hitman1_silencer.png` **no se borró**, solo quedó con
`visible = false` por si lo quieren recuperar.

---

## 6. Si tu compañero ya tiene otras animaciones

`AnimNames.gd` prueba varios nombres en orden, así que funciona con `idle`,
`Idle`, `Stop`, `Quieto`, etc. Si usaron un nombre distinto, agrégalo a las
listas al final de `Scripts/AnimNames.gd` y funciona en todo el juego:

```gdscript
const SHOOT := ["shoot", "Shoot", "Attack", "attack", "disparo", "Disparo", "Disparar"]
```

---

## 7. IA del enemigo

### 7.1 Los tres comportamientos

Se eligen en el Inspector, en la propiedad **`behavior`**. Un mismo
`Enemy.tscn` sirve para los tres: no hay que duplicar código ni escenas.

| Modo | Qué hace |
|---|---|
| **INERTE** | No hace absolutamente nada. Sin visión, sin movimiento, sin disparos. |
| **TORRETA** | No se mueve nunca. Gira barriendo la zona y dispara al verte. |
| **PATRULLA** | Va y viene sobre **una línea recta**. Al verte se planta y dispara. |
| **PERSEGUIR** | Te sigue por el mapa. Ojo: va en línea recta, se atasca en esquinas. |

En `Main.tscn` ya hay uno de cada para que los veas funcionando:
`Enemy` (patrulla horizontal), `EnemyPatrullaVertical` y `EnemyTorreta`.

### 7.2 La máquina de estados

`Scripts/Enemy/enemy.gd` es una **máquina de estados**, el patrón estándar
para IA en juegos: en cada momento el enemigo está en UN solo estado, y solo
ciertas condiciones lo mueven a otro.

```
         te ve                        te pierde de vista
PATRULLA ───────► ATACAR ──────────────────────────────► VOLVER
    ▲                                                       │
    └──────────── vuelve a su sitio / se rinde ─────────────┘

    cualquier estado ──── vida <= 0 ────► MUERTO  (definitivo)
```

- **PATRULLA** — su rutina normal: barrer (torreta) o caminar la línea.
- **ATACAR** — te encara y dispara cada `fire_rate` segundos con dispersión
  aleatoria de `spread_degrees`, para que no sea un francotirador perfecto.
- **VOLVER** — te perdió. Se queda alerta mirando tu última posición durante
  `give_up_time` segundos y luego regresa a su línea o a su ángulo original.
- **MUERTO** — reproduce `Dead`, se quita de la capa de colisión, queda debajo.

### 7.3 La línea de patrulla

El punto donde colocas el enemigo es el **centro** de la línea. Se mueve
`patrol_distance` píxeles hacia cada lado, o sea que el recorrido total es el
doble. `patrol_angle_degrees` inclina la línea: **0 = horizontal**,
**90 = vertical**.

> **Truco:** el script es `@tool`, así que al seleccionar el enemigo en el
> editor verás dibujados en verde la línea con sus dos extremos, y en amarillo
> el cono de visión. Puedes ajustar todo a ojo sin ejecutar el juego.

Si choca contra una pared antes de llegar al extremo, se da la vuelta sola
(hay una detección de atasco de 0.35 s). Así que aunque te equivoques con la
distancia, no se queda empujando el muro para siempre.

### Cómo te detecta

Son dos filtros, uno tras otro:

1. **`VisionArea`** (Area2D, radio 260) — solo mira la capa 2, o sea que
   únicamente registra jugadores.
2. **Cono de visión + `VisionRay`** — comprueba que estés dentro del ángulo
   `vision_angle` y lanza un rayo hacia ti contra la capa 1. Si hay una pared
   en medio, no te ve. Si estás a menos de 60 px te nota aunque sea por detrás.

### Parámetros para balancear la dificultad

| Parámetro | Default | Efecto |
|---|---|---|
| `vision_range` | 260 | A qué distancia te ve. |
| `vision_angle` | 140 | Grados del cono. 360 = ojos en la nuca. |
| `reaction_time` | 0.45 | Cuánto tarda en disparar tras detectarte. **Súbelo si está muy difícil.** |
| `fire_rate` | 0.9 | Segundos entre disparos. |
| `spread_degrees` | 6 | Puntería. 0 = nunca falla. |
| `attack_range` | 220 | Solo en PERSEGUIR: a qué distancia deja de acercarse. |
| `give_up_time` | 3.0 | Cuánto te busca tras perderte. |
| `max_health` | 60 | Aguanta 3 balazos tuyos (25 de daño c/u). |
| `stop_to_shoot` | true | En PATRULLA: `false` = sigue caminando mientras dispara. |
| `patrol_speed` | 70 | Qué tan rápido patrulla. |
| `patrol_wait` | 0.7 | Pausa en cada extremo de la línea. |
| `turret_sweep_degrees` | 90 | Grados que barre la torreta. 0 = fija. |
| `turret_sweep_time` | 4.0 | Segundos por barrido completo. |

---

## 8. Cosas que quedaron pendientes

- **Los PNG del enemigo tienen tamaños muy distintos** (`EnemyAttack` es
  103×124 y `EnemyDead` es 349×321). Como el `AnimatedSprite2D` usa una sola
  escala para todos los frames, al cambiar de animación el enemigo va a
  "crecer" o "encoger". Lo ideal es exportarlos todos al mismo lienzo.
- **El mapa no tiene colisiones.** Revisé el `TileSet` de `Map.tscn`: declara
  una capa de física pero **ningún tile tiene polígono de colisión**, así que
  ahora mismo se puede caminar por encima de todo y las balas no chocan con
  nada. Hay que pintar las colisiones en el editor de TileSet (pestaña
  *Physics*, dibujar el polígono en los tiles de pared). Hasta que lo hagan,
  el cono de visión de los enemigos tampoco se corta con las paredes.
- **Pathfinding**: el modo PERSEGUIR va en línea recta y se atasca en las
  esquinas. Para que rodee obstáculos hay que usar el `NavigationAgent2D` que
  ya está en la escena, pero eso requiere un `NavigationRegion2D` en el mapa.
  Los modos TORRETA y PATRULLA no tienen este problema.
- **`HearingArea`** está en la escena con un radio de 420 px pero sin lógica.
  La idea sería que los disparos alerten a los enemigos cercanos.
- No hay `Camera2D` en `Main.tscn`, por eso no se agregó screen shake.
- Solo hay **un** enemigo en `Main.tscn`. Duplica el nodo `Enemy` para poner
  más; cada uno lleva su propia IA sin configuración extra.
