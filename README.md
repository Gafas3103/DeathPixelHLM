# DeathPixel

Juego 2D top-down hecho en Godot 4.7 (renderer Compatibility, ventana de 1280x720 con stretch `canvas_items`).
Este archivo junta todo lo que hay que saber del proyecto: si vas a trabajar con una IA, pásale este README primero.

## Cómo se juega
- **Mover:** WASD · **Apuntar/disparar:** mouse · **Recargar:** R · **Interactuar (puertas, notas):** E
- **Armas:** 1 rifle, 2 escopeta, 3 cuchillo (también Q o la rueda del mouse)
- **Cuchillo rápido:** F o clic derecho · **Sigilo:** Shift · **Pausa:** Esc
- **Debug:** J te hace daño, H te cura

Objetivo de cada nivel: eliminar a los enemigos, agarrar la llave que suelta el último, abrir la puerta con E y llegar a la salida.
Hay un tutorial en el menú principal (botón TUTORIAL) que explica armas, sigilo y combo. Con N se salta un paso.

## Flujo y autoloads
`MainMenu` → `LevelSelect` → `Scenes/Levels/LevelN.tscn` → victoria → siguiente nivel o menú.
Ajustes es su propia escena (`Scenes/UI/SettingsMenu.tscn`). `Main.tscn` es solo una escena de pruebas.

| Autoload | Archivo | Qué hace |
|---|---|---|
| `Global` | `Scripts/Global.gd` | Vida, munición, puntaje, combo, llave, objetivo y ruido |
| `Settings` | `Scripts/Settings.gd` | Guarda y aplica los ajustes (`user://settings.cfg`) |
| `GameManager` | `Scripts/GameManager.gd` | Lista de niveles, progreso (`user://progress.cfg`), cambio de escena |

## Niveles
Un nivel es una escena de `Scenes/Levels/` con el script `Scripts/level.gd`. Hijos: `Map` (tilemap), `Items` (`KeyItem`, `Door`, `ExitZone`), `Enemies`, `Player`, `HUD`.
Para hacer otro: duplicar `Level1.tscn`, cambiar el mapa, recolocar cosas y llenar su entrada en `GameManager.LEVELS` (los niveles 4 y 5 ya están reservados como "próximamente").
Los niveles se desbloquean al ganar el anterior (Ajustes → General → "Desbloquear niveles" lo salta).

- La nota de historia solo sale en el nivel 1 (`drop_note_on_clear`). Se edita en `NoteItem.tscn` (`note_title`, `note_text`, `note_signature`).
- Nivel 3: el enemigo con `guards_exit` cuida la sala de la puerta y no suelta la llave; la llave la suelta uno de los de afuera.
- `appears_from` en cada enemigo controla la dificultad en que aparece (0 siempre, 1 Normal y Difícil, 2 solo Difícil).

## Recursos y botín
No hay objetos sueltos en el mapa: todo lo sueltan los enemigos al morir (`level.gd` decide qué, según lo que le falte al jugador).
Vida, corazones, balas y puntaje pasan de un nivel al siguiente. Si te quedas sin corazones se reinicia desde el nivel 1 y se pierde todo.
Los números del botín están en el Inspector de cada nivel ("Botín de enemigos").

## Armas, sigilo y flow
- Rifle automático: un toque dispara una vez, mantener dispara en ráfaga. Escopeta: 8 perdigones, lenta y ruidosa. Cuchillo: melee sin munición.
- Cada arma de fuego tiene su propio cargador y reserva. Definición de armas en `Scripts/weapons.gd`.
- El enemigo no te detecta al instante: su `awareness` sube mientras te ve (más rápido de cerca, moviéndote o disparando; más lento quieto o con Shift). Se ve con el anillo sobre su cabeza y la barra SIGILO del HUD.
- Por la espalda de un enemigo que no te ha visto, el cuchillo lo mata en silencio y da puntos dobles.
- Al aparecer hay unos segundos de gracia (`Settings.SPAWN_GRACE`) y 2 s de invulnerabilidad.
- Flow: con combo 3 / 6 / 10 subes de nivel (FLOW / FRENESÍ / BERSERK). Cada punto de combo da +15% de daño, y además más velocidad, cadencia y recarga. Constantes al inicio de `Global.gd`.
- Combo y puntaje: cada baja da `100 × combo × multiplicador de dificultad`. El combo sube +1 (o +2 si matas en menos de 2.5 s) hasta x20 y dura más mientras más alto esté.

## Dificultad
Fácil / Normal / Difícil, se elige en la pantalla de niveles o en Ajustes → General. Toda la tabla está en `Settings.DIFFICULTY_TABLE` (daño, reacción, visión, puntería, oído, vida, botín, puntaje).
En Difícil la recarga es solo manual con R; en Fácil y Normal es automática al vaciar el cargador.

## IA del enemigo (`Scripts/Enemy/enemy.gd`)
Máquina de estados: `PATRULLA → ATACAR → VOLVER`, más `INVESTIGAR` (ruidos), `HUIR` (poca vida) y `MUERTO`.
Comportamiento (propiedad `behavior` en el Inspector):

| Modo | Qué hace |
|---|---|
| INERTE | No hace nada (los muñecos del tutorial) |
| TORRETA | Fija, barre la zona y dispara al verte |
| PATRULLA | Camina una línea recta (o los puntos de `route`) |
| PERSEGUIR | Te sigue por el mapa con A* |

- Ve por un `VisionArea` (solo capa 2) y luego un cono de visión + `RayCast` contra el mundo. Hay un punto ciego por detrás.
- Oye disparos y pasos según `noise_level` del jugador, y los gritos de aliados que ya te vieron.
- El pathfinding (`level.find_path()`) sale de los polígonos de colisión del `TileSet`.
- El script es `@tool`: en el editor se ve la línea de patrulla en verde y el cono de visión en amarillo.
- Parámetros útiles: `vision_range`, `vision_angle`, `reaction_time`, `fire_rate`, `spread_degrees`, `give_up_time`, `max_health`, `patrol_distance`, `patrol_angle_degrees`, `turret_sweep_degrees`.

## Colisiones
Capas de física: 1 Mundo (paredes, muebles, puertas cerradas) · 2 Jugador · 3 Enemigo · 4 Bala · 5 Bala enemiga.
Los objetos recogibles (`KeyItem`, `Pickup`, `ExitZone`) son `Area2D` que solo detectan la capa 2.
Las balas llaman a `apply_bullet_hit(daño, dirección)` o, si no existe, a `take_damage(daño)`: cualquier cosa a la que quieras poder disparar solo necesita uno de los dos.
**Un tile nuevo que deba ser pared necesita su polígono de colisión en el TileSet**, si no la IA y el pathfinding lo ignoran.

## Animación de disparo
`Scripts/CharacterVisuals.gd` (nodo `Visuals`, hijo del `CharacterBody2D`) hace la pose de disparo, el retroceso, el fogonazo y el casquillo cuando `player.gd` llama a `visuals.fire()`.
Se ajusta desde el Inspector: `recoil_distance`, `recoil_out_time`, `shoot_hold_time`, `muzzle_offset`, `flash_size`.
Los sprites `Swat*` están dibujados de frente, así que `keep_upright = true` los mantiene derechos y solo los voltea izquierda/derecha; el cuerpo sigue rotando con `look_at()` por debajo.
`Scripts/AnimNames.gd` prueba varios nombres de animación (`idle`, `Idle`, `Quieto`...); si usas otro nombre, agrégalo a las listas de ese archivo.

## HUD, menús y ajustes
- El HUD (`Scripts/hud.gd`) tiene vida, corazones, panel de armas, barra de combo, barra de sigilo, minimapa y una guía que apunta a llave → puerta → salida.
- Los menús se construyen por código con `Scripts/UI/ui_style.gd` (colores y tipografía). Créditos: constante `CREDITS` en `Scripts/UI/main_menu.gd`.
- Paleta: fondo `#161923`, panel `#252833`, texto `#E9E5D8`, vida `#EF3E4A`, munición `#22D3EE`, objetivo `#FFB000`.
- Ajustes: gráficos (pantalla, resolución, VSync, brillo, FPS), audio (buses `Master`, `Music`, `SFX`), controles (reasignar teclas) y general (dificultad, minimapa, mirilla). Todavía no hay sonidos en el proyecto: cuando los haya, asignar cada `AudioStreamPlayer` a su bus.
- El mouse queda confinado a la ventana durante la partida.
- Las imágenes de los menús y de la nota están en `Assest/UI/`.

## Para quien use IA con este repo
- No hay Godot en el PATH; hay que darle a la IA la ruta del ejecutable.
- Comprobar cambios cargando todos los `.gd` y `.tscn` con un script de `SceneTree` (`godot --headless --path . --script res://alguno.gd`) y arrancando cada nivel.
- Las pruebas tocan `user://progress.cfg` y `user://settings.cfg` (`%APPDATA%\Godot\app_userdata\DeathPixel`): hacer copia antes.
- Sin ventana (`--headless`) no funcionan el mouse ni `keyboard_get_keycode_from_physical`.
- Escribir scripts largos a un archivo antes de ejecutarlos; los heredocs con comillas se dañan en Git Bash.
- La carpeta se llama `Assest` (así, con la errata); si la renombras hay que arreglar todas las rutas.
