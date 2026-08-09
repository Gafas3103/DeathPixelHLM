extends Node2D

## COMPONENTE VISUAL DE PERSONAJE  (DeathPixel / HLM)
## ---------------------------------------------------------------------------
## Se agrega como HIJO del CharacterBody2D del personaje. No toca la física ni
## el sistema de apuntado: el cuerpo sigue rotando con look_at() igual que
## antes. Este nodo solo se encarga de lo VISUAL:
##
##   1. Animación de disparo (pose Attack) con retorno automático.
##   2. Retroceso / kickback del sprite hacia atrás al disparar.
##   3. Fogonazo (muzzle flash) generado por código, sin necesitar arte.
##   4. Mantener el sprite derecho y voltearlo según hacia dónde apunta,
##      porque los sprites Swat están dibujados de frente y no en top-down.
##
## Uso desde el script del jugador:
##      visuals.fire()          -> al disparar
##      visuals.is_shooting()   -> para no pisar la animación de disparo
##      visuals.set_dead(true)  -> al morir
## ---------------------------------------------------------------------------

@export_group("Sprite")
## Si se deja vacío se busca automáticamente el AnimatedSprite2D del personaje.
@export var sprite_path: NodePath
## Los sprites Swat están dibujados de frente. Si el cuerpo rota con look_at(),
## esto los mantiene derechos para que no se vean acostados.
## Ponlo en false si algún día usan arte top-down (tipo hitman1_silencer).
@export var keep_upright: bool = true
## Voltea el sprite en horizontal según hacia dónde apunte el personaje.
@export var flip_with_aim: bool = true
## Velocidad mínima para considerar que el personaje está caminando.
@export var walk_threshold: float = 8.0

@export_group("Retroceso")
@export var recoil_distance: float = 7.0
@export var recoil_in_time: float = 0.04
@export var recoil_out_time: float = 0.16
@export var recoil_squash: float = 0.07

@export_group("Fogonazo")
@export var muzzle_offset: Vector2 = Vector2(34.0, 0.0)
@export var flash_time: float = 0.06
@export var flash_size: float = 12.0
@export var flash_color: Color = Color(1.0, 0.9, 0.42, 1.0)
@export var eject_shell: bool = true

@export_group("Animación")
## Cuánto dura visible la pose de disparo antes de volver a idle/walk.
@export var shoot_hold_time: float = 0.13

var _body: Node2D = null
var _sprite: AnimatedSprite2D = null
var _sprite_home := Vector2.ZERO
var _sprite_home_scale := Vector2.ONE
var _flash: Node2D = null
var _recoil_tween: Tween = null
var _hit_tween: Tween = null
var _shoot_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_body = get_parent() as Node2D
	_sprite = _find_sprite()
	if _sprite != null:
		_sprite_home = _sprite.position
		_sprite_home_scale = _sprite.scale
	_build_flash()


func _process(delta: float) -> void:
	if _shoot_timer > 0.0:
		_shoot_timer = max(0.0, _shoot_timer - delta)

	if _sprite == null:
		return

	# --- 1. Mantener el sprite derecho aunque el cuerpo rote ---------------
	if keep_upright:
		_sprite.global_rotation = 0.0

	# --- 2. Voltear según hacia dónde apunta ------------------------------
	if flip_with_aim and _body != null:
		# El eje X local del cuerpo es la dirección de apuntado (look_at).
		var aim_x: float = _body.global_transform.x.x
		if absf(aim_x) > 0.05:
			_sprite.flip_h = aim_x < 0.0

	# --- 3. Elegir la animación -------------------------------------------
	_update_animation()


func _update_animation() -> void:
	if _dead:
		AnimNames.play(_sprite, AnimNames.DEAD)
		return
	# Mientras dura el disparo no pisamos la pose de ataque.
	if _shoot_timer > 0.0:
		return
	var moving := false
	if _body is CharacterBody2D:
		moving = (_body as CharacterBody2D).velocity.length() > walk_threshold
	if moving:
		AnimNames.play(_sprite, AnimNames.WALK)
	else:
		AnimNames.play(_sprite, AnimNames.IDLE)


# ===========================================================================
#  API PÚBLICA
# ===========================================================================

## Llamar cada vez que el personaje dispara.
func fire() -> void:
	if _dead:
		return
	_play_shoot_anim()
	_do_recoil()
	_do_flash()
	if eject_shell:
		_eject_shell()


func is_shooting() -> bool:
	return _shoot_timer > 0.0


## Parpadeo al recibir daño.
func flash_hit(color: Color = Color(3.0, 0.7, 0.7, 1.0), time: float = 0.14) -> void:
	if _sprite == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_sprite.modulate = color
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite, "modulate", Color.WHITE, time)


func set_dead(value: bool) -> void:
	if _dead == value:
		return
	_dead = value
	if _dead:
		_shoot_timer = 0.0
		if _recoil_tween != null and _recoil_tween.is_valid():
			_recoil_tween.kill()
		if _sprite != null:
			_sprite.position = _sprite_home
			_sprite.scale = _sprite_home_scale
			AnimNames.play(_sprite, AnimNames.DEAD)


# ===========================================================================
#  INTERNO
# ===========================================================================

func _find_sprite() -> AnimatedSprite2D:
	if not sprite_path.is_empty():
		var n := get_node_or_null(sprite_path)
		if n is AnimatedSprite2D:
			return n
	if _body != null:
		return _find_animated_recursive(_body)
	return null


func _find_animated_recursive(node: Node) -> AnimatedSprite2D:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			return child
	for child in node.get_children():
		var found := _find_animated_recursive(child)
		if found != null:
			return found
	return null


func _play_shoot_anim() -> void:
	_shoot_timer = shoot_hold_time
	if _sprite == null:
		return
	if not AnimNames.play(_sprite, AnimNames.SHOOT):
		# Si el personaje no tiene animación de disparo, al menos que se note
		# el retroceso: dejamos el temporizador en 0 para no congelar el idle.
		_shoot_timer = 0.0


func _do_recoil() -> void:
	if _sprite == null:
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()

	_sprite.position = _sprite_home
	_sprite.scale = _sprite_home_scale

	# El eje -X local del cuerpo es "hacia atrás" respecto a la mira.
	var back := _sprite_home - Vector2(recoil_distance, 0.0)
	var squashed := _sprite_home_scale * Vector2(1.0 - recoil_squash, 1.0 + recoil_squash)

	_recoil_tween = create_tween()
	_recoil_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_sprite, "position", back, recoil_in_time)
	_recoil_tween.parallel().tween_property(_sprite, "scale", squashed, recoil_in_time)
	_recoil_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(_sprite, "position", _sprite_home, recoil_out_time)
	_recoil_tween.parallel().tween_property(_sprite, "scale", _sprite_home_scale, recoil_out_time)


func _build_flash() -> void:
	_flash = Node2D.new()
	_flash.name = "MuzzleFlash"
	_flash.position = muzzle_offset
	_flash.visible = false
	add_child(_flash)

	var glow := Polygon2D.new()
	glow.polygon = _star_points(flash_size, 1.8)
	glow.color = flash_color
	_flash.add_child(glow)

	var core := Polygon2D.new()
	core.polygon = _star_points(flash_size * 0.45, 1.6)
	core.color = Color(1.0, 1.0, 0.95, 1.0)
	_flash.add_child(core)


func _star_points(radius: float, stretch_x: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var spikes := 7
	for i in range(spikes * 2):
		var r: float = radius if i % 2 == 0 else radius * 0.4
		var a: float = TAU * float(i) / float(spikes * 2)
		pts.append(Vector2(cos(a) * r * stretch_x, sin(a) * r))
	return pts


func _do_flash() -> void:
	if _flash == null:
		return
	_flash.position = muzzle_offset
	_flash.visible = true
	_flash.modulate.a = 1.0
	_flash.rotation = randf_range(-0.35, 0.35)
	_flash.scale = Vector2.ONE * randf_range(0.8, 1.25)

	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.0, flash_time)
	t.tween_callback(_hide_flash)


func _hide_flash() -> void:
	if _flash != null:
		_flash.visible = false


func _eject_shell() -> void:
	var shell := CPUParticles2D.new()
	shell.emitting = false
	shell.one_shot = true
	shell.explosiveness = 1.0
	shell.amount = 1
	shell.lifetime = 0.5
	shell.local_coords = false
	shell.direction = Vector2(-0.3, -1.0)
	shell.spread = 18.0
	shell.gravity = Vector2(0.0, 420.0)
	shell.initial_velocity_min = 110.0
	shell.initial_velocity_max = 170.0
	shell.angular_velocity_min = -720.0
	shell.angular_velocity_max = 720.0
	shell.scale_amount_min = 1.5
	shell.scale_amount_max = 2.0
	shell.color = Color(0.95, 0.78, 0.3, 1.0)
	add_child(shell)
	shell.position = muzzle_offset * 0.4
	shell.emitting = true
	shell.finished.connect(shell.queue_free)
