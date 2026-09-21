extends PointLight2D

## LUZ REACTIVA del jugador (DeathPixel).
## Adaptación a 2D de luz_reactiva.gd (ejemplo de la Sesión 17): en vez de
## Light3D usa PointLight2D, y en vez de parpadear "porque sí" cada N segundos,
## parpadea cuando algo pasa en el juego. Sigue cambiando light_color con Tween
## para que las transiciones sean suaves.
##
## Reacciona a tres cosas:
##   1. VIDA        -> mientras menos vida, más roja se vuelve la luz (continuo).
##   2. ENEMIGOS    -> si algún enemigo te tiene en su mira (estado ATACAR),
##                     la luz parpadea en rojo. Se revisa cada `intervalo` seg.
##   3. DISPARO     -> cada bala gastada da un destello corto de energía.
##   (y recibir daño da un destello más fuerte)
##
## No hace falta tocar player.gd: escucha las señales de Global.

const EnemyScript := preload("res://Scripts/Enemy/enemy.gd")

@export_group("Colores")
@export var color_normal: Color = Color(1.0, 0.93, 0.78)
@export var color_alerta: Color = Color(1.0, 0.15, 0.15)

@export_group("Energía")
@export var energia_normal: float = 1.0
@export var energia_disparo: float = 1.7
@export var energia_dano: float = 2.4

@export_group("Reacción")
## Cada cuántos segundos se revisa si hay enemigos apuntándote.
@export var intervalo: float = 0.4
## Segundos que dura cada mitad del parpadeo de alerta.
@export var duracion_parpadeo: float = 0.25

var _en_alerta: bool = false
var _vida_previa: float = 100.0
var _tween_alerta: Tween = null
var _tween_destello: Tween = null


func _ready() -> void:
	energy = energia_normal
	_vida_previa = Global.health
	_actualizar_color_por_vida()

	Global.health_changed.connect(_on_health_changed)
	Global.ammo_changed.connect(_on_ammo_changed)

	var temporizador := Timer.new()
	temporizador.wait_time = intervalo
	temporizador.autostart = true
	add_child(temporizador)
	temporizador.timeout.connect(_revisar_enemigos)


# ---------------------------------------------------------------------------
#  ENEMIGOS
# ---------------------------------------------------------------------------

func _revisar_enemigos() -> void:
	var alerta := false
	for enemigo in get_tree().get_nodes_in_group("Enemies"):
		if enemigo.state == EnemyScript.State.ATACAR:
			alerta = true
			break

	if alerta == _en_alerta:
		return
	_en_alerta = alerta

	if _tween_alerta != null and _tween_alerta.is_valid():
		_tween_alerta.kill()

	if _en_alerta:
		# Parpadeo infinito entre el color actual y el de alerta.
		_tween_alerta = create_tween().set_loops()
		_tween_alerta.tween_property(self, "color", color_alerta, duracion_parpadeo)
		_tween_alerta.tween_property(self, "color", _color_por_vida(), duracion_parpadeo)
	else:
		_tween_alerta = create_tween()
		_tween_alerta.tween_property(self, "color", _color_por_vida(), duracion_parpadeo)


# ---------------------------------------------------------------------------
#  VIDA
# ---------------------------------------------------------------------------

## Mientras menos vida, más cerca del color de alerta (0 = sano, 1 = muerto).
func _color_por_vida() -> Color:
	var peligro: float = clampf(1.0 - Global.health / Global.max_health, 0.0, 1.0)
	return color_normal.lerp(color_alerta, peligro)


func _actualizar_color_por_vida() -> void:
	# Si está parpadeando por alerta, el propio parpadeo ya usa _color_por_vida().
	if not _en_alerta:
		color = _color_por_vida()


func _on_health_changed(nueva_vida: float) -> void:
	if nueva_vida < _vida_previa - 1.0:
		_destello(energia_dano)
	_vida_previa = nueva_vida
	_actualizar_color_por_vida()


# ---------------------------------------------------------------------------
#  DISPARO
# ---------------------------------------------------------------------------

func _on_ammo_changed(nueva_municion: int) -> void:
	# ammo_changed también se emite al recargar (sube): solo reaccionar al gastar.
	if nueva_municion < Global.max_ammo:
		_destello(energia_disparo)


## Sube la energía de golpe y la devuelve a la normal.
func _destello(energia_pico: float) -> void:
	if _tween_destello != null and _tween_destello.is_valid():
		_tween_destello.kill()
	energy = energia_pico
	_tween_destello = create_tween()
	_tween_destello.tween_property(self, "energy", energia_normal, 0.18)
