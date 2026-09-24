extends Node2D

## Parte visual del personaje (hijo del CharacterBody2D): pose de disparo, retroceso, fogonazo,
## sprite derecho volteado según la mira, y el arma equipada dibujada en la mano (solo jugador).
## No toca la física ni el apuntado.
## Uso: visuals.fire() al disparar, visuals.is_shooting(), visuals.set_dead(true).

## Silueta del arma que el jugador tiene equipada, dibujada por código (sin sprites propios).
## Se agrega junto al cuerpo y gira con la mira; cambia sola al cambiar de arma (Global.weapon_changed).
class WeaponIcon extends Node2D:
	const BARREL := Color(0.16, 0.16, 0.19)
	const BARREL_DARK := Color(0.08, 0.08, 0.1)
	const BARREL_LIGHT := Color(0.34, 0.34, 0.38)
	const OUTLINE := Color(0.04, 0.04, 0.05)
	const GRIP := Color(0.36, 0.25, 0.13)
	const GRIP_DARK := Color(0.22, 0.15, 0.07)
	const METAL := Color(0.58, 0.59, 0.62)
	const BLADE := Color(0.86, 0.88, 0.92)
	const BLADE_EDGE := Color(0.98, 0.99, 1.0)

	## 0 rifle, 1 escopeta, 2 cuchillo (mismo orden que weapons.gd)
	var kind: int = 0

	func _init() -> void:
		z_index = 5

	func _draw() -> void:
		match kind:
			0:
				_draw_rifle()
			1:
				_draw_shotgun()
			2:
				_draw_knife()

	## polígono relleno con contorno fino, para dar sensación de solidez
	func _draw_shape(points: PackedVector2Array, fill: Color, outline_w: float = 1.0) -> void:
		draw_colored_polygon(points, fill)
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, OUTLINE, outline_w, true)

	func _draw_rect(rect: Rect2, fill: Color, outline_w: float = 1.0) -> void:
		var pts := PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y),
		])
		_draw_shape(pts, fill, outline_w)

	func _draw_rifle() -> void:
		# culata angulada
		var stock := PackedVector2Array([
			Vector2(-11.0, -1.5), Vector2(-2.0, -3.0), Vector2(-2.0, 3.0),
			Vector2(-11.0, 2.5), Vector2(-13.0, 4.5), Vector2(-13.0, 1.0),
		])
		_draw_shape(stock, GRIP)
		# empuñadura angulada
		var grip := PackedVector2Array([
			Vector2(-3.5, 1.5), Vector2(0.5, 1.5), Vector2(-1.0, 8.0), Vector2(-4.5, 8.0),
		])
		_draw_shape(grip, GRIP_DARK)
		# receiver
		_draw_rect(Rect2(-2.0, -3.2, 14.0, 6.4), BARREL)
		# cañón
		_draw_rect(Rect2(12.0, -1.3, 15.0, 2.6), BARREL_DARK)
		_draw_rect(Rect2(25.0, -1.6, 3.0, 3.2), Color(0.02, 0.02, 0.02))
		# cargador curvo
		var mag := PackedVector2Array([
			Vector2(1.0, 3.0), Vector2(4.5, 3.0), Vector2(6.5, 11.0),
			Vector2(3.5, 11.5), Vector2(0.5, 4.0),
		])
		_draw_shape(mag, BARREL_DARK)
		# mira trasera y delantera
		_draw_rect(Rect2(2.0, -5.4, 2.2, 2.4), METAL)
		_draw_rect(Rect2(21.0, -4.6, 1.6, 3.4), METAL)
		# brillo superior
		draw_line(Vector2(-1.0, -3.0), Vector2(11.0, -3.0), BARREL_LIGHT, 1.0)

	func _draw_shotgun() -> void:
		var stock := PackedVector2Array([
			Vector2(-10.0, -2.0), Vector2(-1.0, -3.5), Vector2(-1.0, 4.5),
			Vector2(-9.0, 3.5), Vector2(-11.5, 5.5), Vector2(-11.5, 1.5),
		])
		_draw_shape(stock, GRIP)
		_draw_rect(Rect2(-1.0, -3.6, 8.0, 7.2), BARREL_DARK)
		# cañón único, más grueso
		_draw_rect(Rect2(6.0, -2.3, 20.0, 4.6), BARREL)
		# guardamano tipo bomba
		_draw_rect(Rect2(9.0, -3.0, 7.0, 6.0), GRIP_DARK)
		for i in range(3):
			var x := 10.0 + i * 2.0
			draw_line(Vector2(x, -2.6), Vector2(x, 2.6), OUTLINE, 0.8)
		_draw_rect(Rect2(25.0, -2.6, 2.5, 5.2), Color(0.02, 0.02, 0.02))
		draw_line(Vector2(6.0, -2.0), Vector2(24.0, -2.0), BARREL_LIGHT, 1.0)

	func _draw_knife() -> void:
		var handle := PackedVector2Array([
			Vector2(-7.0, -1.2), Vector2(-1.5, -2.0), Vector2(0.0, 0.0),
			Vector2(-1.5, 2.0), Vector2(-7.0, 1.2),
		])
		_draw_shape(handle, GRIP)
		_draw_rect(Rect2(-0.5, -3.0, 1.6, 6.0), METAL)
		var blade := PackedVector2Array([
			Vector2(1.0, -1.4), Vector2(11.0, -1.0), Vector2(16.5, 0.0),
			Vector2(11.0, 1.0), Vector2(1.0, 1.4),
		])
		_draw_shape(blade, BLADE)
		draw_line(Vector2(2.0, -0.9), Vector2(15.0, -0.2), BLADE_EDGE, 0.8)


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

@export_group("Arma equipada")
## dibuja el arma actual en la mano; solo tiene efecto si el dueño está en el grupo "player"
@export var show_weapon_icon: bool = true
@export var weapon_offset: Vector2 = Vector2(11.0, 3.0)

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
var _weapon_icon: WeaponIcon = null
var _checked_owner: bool = false


func _ready() -> void:
	_body = get_parent() as Node2D
	_sprite = _find_sprite()
	if _sprite != null:
		_sprite_home = _sprite.position
		_sprite_home_scale = _sprite.scale
	_build_flash()


func _process(delta: float) -> void:
	if not _checked_owner:
		_checked_owner = true
		if show_weapon_icon and _body != null and _body.is_in_group("player"):
			_build_weapon_icon()

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
	if _weapon_icon != null:
		_weapon_icon.visible = not _dead
	if _dead:
		_shoot_timer = 0.0
		if _recoil_tween != null and _recoil_tween.is_valid():
			_recoil_tween.kill()
		if _sprite != null:
			_sprite.position = _sprite_home
			_sprite.scale = _sprite_home_scale
			AnimNames.play(_sprite, AnimNames.DEAD)


func _build_weapon_icon() -> void:
	_weapon_icon = WeaponIcon.new()
	_weapon_icon.position = weapon_offset
	_weapon_icon.kind = Global.current_weapon
	add_child(_weapon_icon)
	Global.weapon_changed.connect(_on_weapon_changed)


func _on_weapon_changed(index: int) -> void:
	if _weapon_icon != null:
		_weapon_icon.kind = index
		_weapon_icon.queue_redraw()


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
