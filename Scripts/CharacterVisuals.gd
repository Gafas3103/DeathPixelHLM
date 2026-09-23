extends Node2D

## Parte visual del personaje (hijo del CharacterBody2D): pose de disparo, retroceso, fogonazo y
## sprite derecho volteado según la mira. No toca la física ni el apuntado.
## Uso: visuals.fire() al disparar, visuals.is_shooting(), visuals.set_dead(true).

@export_group("Sprite")
## si está vacío busca el AnimatedSprite2D del personaje
@export var sprite_path: NodePath
## los sprites Swat están dibujados de frente: esto los mantiene derechos aunque el cuerpo rote
## false si algún día usan arte top-down
@export var keep_upright: bool = true
## voltea el sprite según hacia dónde apunte
@export var flip_with_aim: bool = true
## velocidad mínima para contar como caminando
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
## cuánto dura la pose de disparo
@export var shoot_hold_time: float = 0.13

var _body: Node2D = null
var _sprite: AnimatedSprite2D = null
var _sprite_home := Vector2.ZERO
var _sprite_home_scale := Vector2.ONE
var _flash: Node2D = null
var _flash_light: PointLight2D = null
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

	# sprite derecho aunque el cuerpo rote
	if keep_upright:
		_sprite.global_rotation = 0.0

	# voltear según la mira
	if flip_with_aim and _body != null:
		# el eje X local es la dirección de apuntado
		var aim_x: float = _body.global_transform.x.x
		if absf(aim_x) > 0.05:
			_sprite.flip_h = aim_x < 0.0

	# elegir animación
	_update_animation()


func _update_animation() -> void:
	if _dead:
		AnimNames.play(_sprite, AnimNames.DEAD)
		return
	# no pisar la pose de ataque mientras dura el disparo
	if _shoot_timer > 0.0:
		return
	var moving := false
	if _body is CharacterBody2D:
		moving = (_body as CharacterBody2D).velocity.length() > walk_threshold
	if moving:
		AnimNames.play(_sprite, AnimNames.WALK)
	else:
		AnimNames.play(_sprite, AnimNames.IDLE)


# api

## llamar cada vez que dispara
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


## parpadeo al recibir daño
func flash_hit(color: Color = Color(3.0, 0.7, 0.7, 1.0), time: float = 0.14) -> void:
	if _sprite == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_sprite.modulate = color
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite, "modulate", Color.WHITE, time)


func set_material_emission(color: Color, energy: float, enabled: bool = true) -> void:
	if _sprite == null or _sprite.material == null:
		return
	if _sprite.material is ShaderMaterial:
		var material := _sprite.material as ShaderMaterial
		material.set_shader_parameter("emission", color)
		material.set_shader_parameter("emission_energy_multiplier", energy)
		material.set_shader_parameter("emission_enabled", enabled)


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


# interno

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
		# sin animación de disparo al menos que se note el retroceso
		_shoot_timer = 0.0


func _do_recoil() -> void:
	if _sprite == null:
		return
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()

	_sprite.position = _sprite_home
	_sprite.scale = _sprite_home_scale

	# -X local es hacia atrás respecto a la mira
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
	_flash.light_mask = 0
	add_child(_flash)

	var glow := Polygon2D.new()
	glow.polygon = _star_points(flash_size, 1.8)
	glow.color = flash_color
	glow.light_mask = 0
	_flash.add_child(glow)

	var core := Polygon2D.new()
	core.polygon = _star_points(flash_size * 0.45, 1.6)
	core.color = Color(1.0, 1.0, 0.95, 1.0)
	core.light_mask = 0
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

	var lit := _update_flash_light()
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.0, flash_time)
	if lit:
		t.parallel().tween_property(_flash_light, "energy", 0.25, flash_time)
	t.tween_callback(_hide_flash)


func _update_flash_light() -> bool:
	if not is_inside_tree():
		return false
	var lighting := get_tree().get_first_node_in_group(&"level_lighting")
	var active := lighting != null and lighting.has_method(&"is_active") and bool(lighting.call(&"is_active"))
	if not active:
		if _flash_light != null:
			_flash_light.enabled = false
		return false
	if _flash_light == null:
		_flash_light = PointLight2D.new()
		_flash_light.name = "LuzFogonazo"
		_flash_light.texture = lighting.call(&"radial_texture")
		_flash_light.texture_scale = clampf(flash_size / 9.0, 0.8, 2.0)
		_flash_light.color = flash_color
		_flash_light.blend_mode = Light2D.BLEND_MODE_ADD
		_flash_light.range_item_cull_mask = 1
		_flash.add_child(_flash_light)
	_flash_light.enabled = true
	_flash_light.energy = 1.6
	return true


func _hide_flash() -> void:
	if _flash != null:
		_flash.visible = false


func _eject_shell() -> void:
	var shell := CPUParticles2D.new()
	shell.light_mask = 0
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
