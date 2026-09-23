extends Node2D

const POLL_TIME := 0.4
const TILE := 16.0
const WALL_INSET := 2.0
const OCCLUDER_CULL := OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
const FLAT_SIZE := 8
const CONE_SIZE := 256
const CONE_REACH := 256
const ENEMY_CONE_SIZE := 160
const ENEMY_CONE_REACH := 128
const MAX_PICKUP_GLOWS := 6
const TILE_QUADRANT := 8
const SCREEN_LIGHT_SIZE := 2800.0
const STATE_ATACAR := 1
const STATE_HUIR := 5

const KIND_KEY := 0
const KIND_PICKUP := 1
const KIND_NOTE := 2
const KIND_DOOR := 3
const KIND_EXIT := 4

const RED := Color(1.0, 0.16, 0.1)
const ALERT := Color(1.0, 0.56, 0.16)
const HURT := Color(1.0, 0.2, 0.14)
const LOCKED := Color(0.94, 0.24, 0.29)
const OPENED := Color(0.22, 0.9, 0.55)
const EXIT_IDLE := Color(0.45, 0.5, 0.55)
const GOLD := Color(1.0, 0.69, 0.0)
const PAPER := Color(1.0, 0.84, 0.5)
const PICKUP_COLORS: Array[Color] = [Color(0.13, 0.83, 0.93), Color(0.94, 0.24, 0.29), Color(0.94, 0.24, 0.29), Color(1.0, 0.69, 0.0)]

const SHOT_GLOW := &"_shot_glow"

const MOODS := {
	"atardecer": {
		"dark": Color(0.1, 0.27, 0.42),
		"flashlight": false,
		"glow": Color(1.0, 0.78, 0.5),
		"glow_energy": 0.4,
		"glow_size": 1.7,
		"cone": Color(1.0, 0.9, 0.7),
		"cone_energy": 0.8,
		"enemy": false,
		"enemy_color": Color(1.0, 0.9, 0.7),
		"enemy_energy": 0.0,
		"items": 0.55,
		"accent": Color(1.0, 0.45, 0.15),
		"accent_energy": 0.0,
	},
	"noche": {
		"dark": Color(0.8, 0.74, 0.55),
		"flashlight": true,
		"glow": Color(0.78, 0.84, 1.0),
		"glow_energy": 0.75,
		"glow_size": 1.3,
		"cone": Color(1.0, 0.95, 0.82),
		"cone_energy": 1.7,
		"enemy": true,
		"enemy_color": Color(1.0, 0.92, 0.72),
		"enemy_energy": 0.85,
		"items": 0.9,
		"accent": Color(0.3, 0.4, 1.0),
		"accent_energy": 0.0,
	},
	"apagon": {
		"dark": Color(0.8, 0.79, 0.72),
		"flashlight": true,
		"glow": Color(0.95, 0.88, 0.72),
		"glow_energy": 0.9,
		"glow_size": 0.95,
		"cone": Color(1.0, 0.94, 0.78),
		"cone_energy": 2.4,
		"enemy": true,
		"enemy_color": Color(1.0, 0.9, 0.68),
		"enemy_energy": 1.0,
		"items": 1.0,
		"accent": Color(1.0, 1.0, 1.0),
		"accent_energy": 0.0,
	},
	"sede": {
		"dark": Color(0.84, 0.8, 0.66),
		"flashlight": true,
		"glow": Color(0.8, 0.86, 1.0),
		"glow_energy": 0.7,
		"glow_size": 1.2,
		"cone": Color(0.92, 0.96, 1.0),
		"cone_energy": 1.6,
		"enemy": true,
		"enemy_color": Color(1.0, 0.5, 0.42),
		"enemy_energy": 0.9,
		"items": 0.9,
		"accent": Color(1.0, 0.08, 0.1),
		"accent_energy": 0.05,
	},
}

var mood: String = ""
var quality: int = 1

var _active: bool = false
var _has_flashlight: bool = false
var _time: float = 0.0
var _poll_left: float = 0.0
var _alarm: bool = false
var _clear_saved: bool = false

var _dark_color: Color = Color.BLACK
var _glow_color: Color = Color.WHITE
var _glow_energy: float = 0.5
var _glow_size: float = 1.0
var _cone_color: Color = Color.WHITE
var _cone_energy: float = 1.0
var _enemy_lights: bool = false
var _enemy_color: Color = Color.WHITE
var _enemy_energy: float = 1.0
var _item_energy: float = 1.0
var _accent_color: Color = Color.BLACK
var _accent_energy: float = 0.0

var _dark: PointLight2D = null
var _accent: PointLight2D = null
var _flash: PointLight2D = null
var _flash_tween: Tween = null

var _player: Node2D = null
var _glow: PointLight2D = null
var _cone: PointLight2D = null
var _cone_level: float = 0.0
var _hit: float = 0.0
var _heal: float = 0.0
var _last_health: float = -1.0

var _tracked: Dictionary = {}
var _enemies: Array = []
var _items: Array = []
var _occluders: Node2D = null
var _occluders_done: bool = false
var _occluder_tries: int = 0
var _pickup_glows: int = 0

static var _base_clear: Color = Color("#161923")
static var _clear_owners: int = 0
static var _flat_tex: ImageTexture = null
static var _radial_tex: ImageTexture = null
static var _cone_tex: ImageTexture = null
static var _enemy_cone_tex: ImageTexture = null


func _ready() -> void:
	add_to_group("level_lighting")
	Global.health_changed.connect(_on_health_changed)
	Settings.changed.connect(_on_settings_changed)
	_last_health = Global.health


func _exit_tree() -> void:
	_teardown()


func setup(level_mood: String) -> void:
	mood = level_mood
	var cfg: Dictionary = MOODS.get(mood, {})
	_has_flashlight = Global.lights_out or bool(cfg.get("flashlight", false))
	if _has_flashlight:
		Global.set_flashlight(true)
	if cfg.is_empty():
		return
	_dark_color = cfg["dark"]
	_glow_color = cfg["glow"]
	_glow_energy = cfg["glow_energy"]
	_glow_size = cfg["glow_size"]
	_cone_color = cfg["cone"]
	_cone_energy = cfg["cone_energy"]
	_enemy_lights = cfg["enemy"]
	_enemy_color = cfg["enemy_color"]
	_enemy_energy = cfg["enemy_energy"]
	_item_energy = cfg["items"]
	_accent_color = cfg["accent"]
	_accent_energy = cfg["accent_energy"]
	if Global.lights_out and mood != "apagon":
		_dark_color = _dark_color.lerp(Color(0.92, 0.92, 0.88), 0.6)
		_enemy_lights = true
	_build()


func is_active() -> bool:
	return _active


func has_flashlight() -> bool:
	return _has_flashlight


func set_alarm(active: bool) -> void:
	_alarm = active
	if not active and _accent != null and _accent_energy <= 0.0:
		_accent.enabled = false


func pulse(color: Color, strength: float, duration: float) -> void:
	if not _active or _flash == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = color
	_flash.energy = maxf(strength, 0.0)
	_flash.enabled = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "energy", 0.0, maxf(duration, 0.02)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_callback(_end_pulse)


func _end_pulse() -> void:
	if _flash != null:
		_flash.enabled = false


static func flat_texture() -> Texture2D:
	if _flat_tex == null:
		var img := Image.create_empty(FLAT_SIZE, FLAT_SIZE, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_flat_tex = ImageTexture.create_from_image(img)
	return _flat_tex


static func radial_texture() -> Texture2D:
	if _radial_tex == null:
		_radial_tex = _make_radial(128)
	return _radial_tex


static func cone_texture() -> Texture2D:
	if _cone_tex == null:
		_cone_tex = _make_cone(CONE_SIZE, CONE_REACH, 0.44, 0.0)
	return _cone_tex


static func enemy_cone_texture() -> Texture2D:
	if _enemy_cone_tex == null:
		_enemy_cone_tex = _make_cone(ENEMY_CONE_SIZE, ENEMY_CONE_REACH, 0.5, 0.2)
	return _enemy_cone_tex


static func _make_radial(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a * (3.0 - 2.0 * a)))
	return ImageTexture.create_from_image(img)


static func _make_cone(size: int, reach: int, half_angle: float, bulb: float) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 0.0))
	var apex := Vector2(float(size - reach), float(size) * 0.5)
	var from_x := maxi(0, int(apex.x - bulb * float(reach)) - 1)
	for y in range(size):
		for x in range(from_x, size):
			var v := Vector2(float(x) + 0.5, float(y) + 0.5) - apex
			var r := v.length() / float(reach)
			if r >= 1.0:
				continue
			var a := 0.0
			if v.x > 0.0:
				var ang := absf(atan2(v.y, v.x))
				if ang < half_angle:
					var edge := 1.0 - smoothstep(half_angle * 0.5, half_angle, ang)
					var core := 0.78 + 0.22 * (1.0 - smoothstep(0.0, half_angle * 0.45, ang))
					var fall := pow(1.0 - r, 0.85) * smoothstep(0.0, 0.12, r)
					a = edge * core * fall
			if bulb > 0.0 and r < bulb:
				var b := 1.0 - smoothstep(0.0, bulb, r)
				a = maxf(a, b * 0.75)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _build() -> void:
	quality = clampi(Settings.lighting_quality, 0, 2)
	_active = quality > 0 and MOODS.has(mood)
	if not _active:
		return
	_dark = _screen_light("Oscuridad", Light2D.BLEND_MODE_SUB, _dark_color, 1.0)
	_accent = _screen_light("Acento", Light2D.BLEND_MODE_ADD, _accent_color, 0.0)
	_flash = _screen_light("Destello", Light2D.BLEND_MODE_ADD, Color.WHITE, 0.0)
	_shrink_tile_quadrants()
	_follow_camera()
	_apply_clear_color()
	_poll_left = POLL_TIME
	_poll()


func _screen_light(light_name: String, blend: Light2D.BlendMode, color: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.name = light_name
	l.texture = flat_texture()
	l.texture_scale = SCREEN_LIGHT_SIZE / float(FLAT_SIZE)
	l.blend_mode = blend
	l.color = color
	l.energy = energy
	l.range_item_cull_mask = 1
	l.top_level = true
	l.enabled = energy > 0.0
	add_child(l)
	return l


func _shrink_tile_quadrants() -> void:
	var level := _level_node()
	if level == null:
		return
	for n in level.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer != null and layer.rendering_quadrant_size > TILE_QUADRANT:
			layer.rendering_quadrant_size = TILE_QUADRANT


func _follow_camera() -> void:
	var center := Vector2.ZERO
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null:
		center = cam.get_screen_center_position()
	elif _player != null and is_instance_valid(_player):
		center = _player.global_position
	if _dark != null:
		_dark.global_position = center
	if _accent != null:
		_accent.global_position = center
	if _flash != null:
		_flash.global_position = center


func _teardown() -> void:
	for entry in _enemies:
		_free(entry[1])
		_free(entry[2])
	for entry in _items:
		_free(entry[1])
		_free(entry[4])
	_enemies.clear()
	_items.clear()
	_tracked.clear()
	_free(_glow)
	_free(_cone)
	_free(_dark)
	_free(_accent)
	_free(_flash)
	_free(_occluders)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_glow = null
	_cone = null
	_dark = null
	_accent = null
	_flash = null
	_occluders = null
	_player = null
	_occluders_done = false
	_occluder_tries = 0
	_active = false
	_restore_clear_color()


func _free(n: Variant) -> void:
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


func _on_settings_changed() -> void:
	if mood == "" or not MOODS.has(mood):
		return
	if clampi(Settings.lighting_quality, 0, 2) == quality:
		return
	_teardown()
	_build()


func _on_health_changed(value: float) -> void:
	if _last_health >= 0.0:
		if value < _last_health - 0.01:
			_hit = 1.0
		elif value > _last_health + 0.01:
			_heal = 1.0
	_last_health = value


func _apply_clear_color() -> void:
	if not _clear_saved:
		if _clear_owners == 0:
			_base_clear = RenderingServer.get_default_clear_color()
		_clear_owners += 1
		_clear_saved = true
	var k := Color(1.0 - _dark_color.r, 1.0 - _dark_color.g, 1.0 - _dark_color.b)
	RenderingServer.set_default_clear_color(Color(_base_clear.r * k.r, _base_clear.g * k.g, _base_clear.b * k.b))


func _restore_clear_color() -> void:
	if not _clear_saved:
		return
	_clear_saved = false
	_clear_owners = maxi(0, _clear_owners - 1)
	if _clear_owners == 0:
		RenderingServer.set_default_clear_color(_base_clear)


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL_TIME
		_poll()
	_follow_camera()
	_update_accent()
	_update_player(delta)
	_update_enemies(delta)
	_update_items()


func _update_accent() -> void:
	if _accent == null:
		return
	if _alarm:
		_accent.color = RED
		_accent.energy = 0.1 + 0.3 * (0.5 + 0.5 * sin(_time * 5.5))
		_accent.enabled = true
	elif _accent_energy > 0.0:
		_accent.color = _accent_color
		_accent.energy = _accent_energy * (0.6 + 0.4 * sin(_time * 1.3))
		_accent.enabled = true


func _update_player(delta: float) -> void:
	if _glow == null or _player == null or not is_instance_valid(_player):
		return
	_hit = maxf(0.0, _hit - delta * 3.0)
	_heal = maxf(0.0, _heal - delta * 2.0)
	var alive := Global.health > 0.0
	var hp := clampf(Global.health / maxf(Global.max_health, 1.0), 0.0, 1.0)
	var danger := clampf((0.55 - hp) / 0.55, 0.0, 1.0)
	var shot := 0.0
	var sg: Variant = _player.get(SHOT_GLOW)
	if sg != null:
		shot = clampf((float(sg) - 0.7) / 0.2, 0.0, 1.0)
	var col := _glow_color.lerp(HURT, danger * 0.75)
	col = col.lerp(Color(1.0, 0.86, 0.55), shot * 0.6)
	col = col.lerp(Color(1.0, 0.3, 0.25), _hit)
	col = col.lerp(Color(0.4, 1.0, 0.55), _heal)
	var energy := _glow_energy * (1.0 + danger * 0.35 * sin(_time * 7.0))
	energy += shot * 0.55 + _hit * 1.1 + _heal * 0.6
	if not alive:
		energy *= 0.3
	_glow.color = col
	_glow.energy = energy
	if _cone == null:
		return
	var want := 1.0 if (alive and Global.flashlight_on) else 0.0
	_cone_level = move_toward(_cone_level, want, delta * (7.0 if want > _cone_level else 5.0))
	var flicker := 1.0
	if danger > 0.6 and randf() < 0.05:
		flicker = randf_range(0.55, 0.9)
	_cone.energy = (_cone_energy + shot * 0.25) * _cone_level * flicker
	_cone.color = _cone_color.lerp(Color(1.0, 0.35, 0.3), _hit * 0.6)
	_cone.enabled = _cone_level > 0.005


func _update_enemies(delta: float) -> void:
	var k := clampf(delta * 8.0, 0.0, 1.0)
	for entry in _enemies:
		var e = entry[0]
		if not is_instance_valid(e):
			continue
		var cone: PointLight2D = entry[1]
		var aura = entry[2]
		var alive := true
		if e.has_method(&"is_alive"):
			alive = e.is_alive()
		if not alive:
			if cone != null and cone.enabled:
				cone.energy = move_toward(cone.energy, 0.0, delta * 2.5)
				cone.enabled = cone.energy > 0.01
			if aura != null and aura.enabled:
				aura.energy = move_toward(aura.energy, 0.0, delta * 1.5)
				aura.enabled = aura.energy > 0.01
			continue
		if aura != null:
			aura.energy = 0.85 + 0.35 * sin(_time * 3.2)
		if cone == null:
			continue
		var st: Variant = e.get(&"state")
		var attacking := st != null and (int(st) == STATE_ATACAR or int(st) == STATE_HUIR)
		var aw: Variant = e.get(&"awareness")
		var awareness := clampf(float(aw), 0.0, 1.0) if aw != null else 0.0
		var col := RED if (attacking or bool(entry[4])) else _enemy_color.lerp(ALERT, awareness)
		cone.color = cone.color.lerp(col, k)
		cone.energy = move_toward(cone.energy, float(entry[5]) * (1.2 if attacking else 1.0), delta * 3.0)


func _update_items() -> void:
	for entry in _items:
		var n = entry[0]
		if not is_instance_valid(n):
			continue
		var light: PointLight2D = entry[1]
		match int(entry[2]):
			KIND_KEY:
				light.energy = _item_energy * (1.0 + 0.35 * sin(_time * 4.0))
			KIND_DOOR:
				var open_v: Variant = n.get(&"is_open")
				var is_open_now := open_v != null and bool(open_v)
				light.color = OPENED if is_open_now else LOCKED
				light.energy = _item_energy * (0.45 if is_open_now else 0.75)
				if entry[4] != null and is_instance_valid(entry[4]):
					(entry[4] as LightOccluder2D).visible = not is_open_now
			KIND_EXIT:
				var rk: Variant = n.get(&"requires_key")
				var usable := Global.has_key or not (rk == null or bool(rk))
				if Global.boss_alive:
					light.color = LOCKED
					light.energy = _item_energy * (0.6 + 0.3 * sin(_time * 6.0))
				else:
					light.color = OPENED if usable else EXIT_IDLE
					light.energy = _item_energy * ((0.9 + 0.3 * sin(_time * 3.0)) if usable else 0.4)


func _poll() -> void:
	_prune()
	var tree := get_tree()
	if tree == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = null
		var p := tree.get_first_node_in_group(&"player") as Node2D
		if p != null:
			_attach_player(p)
	for e in tree.get_nodes_in_group(&"Enemies"):
		if not _tracked.has(e.get_instance_id()):
			_attach_enemy(e)
	for n in tree.get_nodes_in_group(&"key_items"):
		if not _tracked.has(n.get_instance_id()):
			_attach_item(n, KIND_KEY)
	for n in tree.get_nodes_in_group(&"pickups"):
		if _pickup_glows >= MAX_PICKUP_GLOWS:
			break
		if not _tracked.has(n.get_instance_id()):
			_attach_item(n, KIND_PICKUP)
	for n in tree.get_nodes_in_group(&"notes"):
		if not _tracked.has(n.get_instance_id()):
			_attach_item(n, KIND_NOTE)
	for n in tree.get_nodes_in_group(&"doors"):
		if not _tracked.has(n.get_instance_id()):
			_attach_item(n, KIND_DOOR)
	for n in tree.get_nodes_in_group(&"exit_zone"):
		if not _tracked.has(n.get_instance_id()):
			_attach_item(n, KIND_EXIT)
	if quality >= 2 and not _occluders_done:
		_build_occluders()


func _prune() -> void:
	for i in range(_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_enemies[i][0]):
			_tracked.erase(_enemies[i][3])
			_enemies.remove_at(i)
	_pickup_glows = 0
	for i in range(_items.size() - 1, -1, -1):
		if not is_instance_valid(_items[i][0]):
			_tracked.erase(_items[i][3])
			_items.remove_at(i)
		elif int(_items[i][2]) == KIND_PICKUP:
			_pickup_glows += 1


func _new_light(tex: Texture2D, color: Color, energy: float, size: float, shadows: bool) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = size
	l.color = color
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.range_item_cull_mask = 1
	if shadows and quality >= 2:
		l.shadow_enabled = true
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 1.5
		l.shadow_item_cull_mask = 1
	return l


func _attach_player(p: Node2D) -> void:
	_player = p
	_glow = _new_light(radial_texture(), _glow_color, _glow_energy, _glow_size, true)
	_glow.name = "LuzJugador"
	p.add_child(_glow)
	if _has_flashlight:
		_cone = _new_light(cone_texture(), _cone_color, 0.0, 1.05, true)
		_cone.name = "Linterna"
		_cone.position = Vector2(4.0, 0.0)
		_cone.offset = Vector2((float(CONE_REACH) - float(CONE_SIZE) * 0.5) * _cone.texture_scale, 0.0)
		_cone.enabled = false
		p.add_child(_cone)
		_cone_level = 1.0 if Global.flashlight_on else 0.0


func _attach_enemy(e: Node) -> void:
	_tracked[e.get_instance_id()] = true
	if not (e is Node2D):
		return
	if e.has_method(&"is_alive") and not bool(e.call(&"is_alive")):
		return
	var boss: bool = e.is_in_group(&"boss")
	if not _enemy_lights and not boss:
		return
	var base := _enemy_energy if _enemy_lights else 0.9
	var cone := _new_light(enemy_cone_texture(), RED if boss else _enemy_color, base, 1.2 if boss else 0.94, true)
	cone.offset = Vector2((float(ENEMY_CONE_REACH) - float(ENEMY_CONE_SIZE) * 0.5) * cone.texture_scale, 0.0)
	cone.name = "LuzEnemigo"
	e.add_child(cone)
	var aura: PointLight2D = null
	if boss:
		aura = _new_light(radial_texture(), RED, 0.9, 2.2, true)
		aura.name = "AuraJefe"
		e.add_child(aura)
	_enemies.append([e, cone, aura, e.get_instance_id(), boss, base])


func _attach_item(n: Node, kind: int) -> void:
	_tracked[n.get_instance_id()] = true
	if not (n is Node2D):
		return
	var color := GOLD
	var size := 0.9
	var energy := _item_energy
	match kind:
		KIND_PICKUP:
			var kv: Variant = n.get(&"kind")
			var idx := clampi(int(kv) if kv != null else 0, 0, PICKUP_COLORS.size() - 1)
			color = PICKUP_COLORS[idx]
			size = 0.6
			energy = _item_energy * 0.7
			_pickup_glows += 1
		KIND_NOTE:
			color = PAPER
			size = 0.8
			energy = _item_energy * 0.8
		KIND_DOOR:
			color = LOCKED
			size = 0.8
			energy = _item_energy * 0.75
			for child in n.get_children():
				if child is Label:
					(child as Label).light_mask = 0
		KIND_EXIT:
			color = EXIT_IDLE
			var sv: Variant = n.get(&"size")
			var ext := 36.0
			if sv is Vector2:
				ext = maxf((sv as Vector2).x, (sv as Vector2).y)
			size = clampf(ext / 40.0, 0.7, 2.0)
			energy = _item_energy * 0.4
	var light := _new_light(radial_texture(), color, energy, size, false)
	light.name = "Brillo"
	n.add_child(light)
	var occ: LightOccluder2D = null
	if kind == KIND_DOOR and quality >= 2:
		occ = _door_occluder(n as Node2D)
	_items.append([n, light, kind, n.get_instance_id(), occ])


func _door_occluder(door: Node2D) -> LightOccluder2D:
	var sv: Variant = door.get(&"size")
	if not (sv is Vector2):
		return null
	var sz: Vector2 = sv
	var half := sz * 0.5
	var grow := WALL_INSET + 3.0
	if sz.x >= sz.y:
		half.x += grow
		half.y = maxf(half.y - WALL_INSET, 2.0)
	else:
		half.y += grow
		half.x = maxf(half.x - WALL_INSET, 2.0)
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
	poly.cull_mode = OCCLUDER_CULL
	var occ := LightOccluder2D.new()
	occ.name = "SombraPuerta"
	occ.occluder = poly
	door.add_child(occ)
	return occ


func _level_node() -> Node:
	var p := get_parent()
	if p != null and p.get(&"solid_rects") != null:
		return p
	return get_tree().get_first_node_in_group(&"level")


func _build_occluders() -> void:
	_occluder_tries += 1
	if _occluder_tries > 10:
		_occluders_done = true
	var level := _level_node()
	if level == null:
		return
	var rv: Variant = level.get(&"solid_rects")
	if not (rv is Array) or (rv as Array).is_empty():
		return
	_occluders_done = true
	_occluders = Node2D.new()
	_occluders.name = "Oclusores"
	_occluders.top_level = true
	add_child(_occluders)
	var groups := {}
	for r in rv:
		var rect: Rect2 = r
		if absf(rect.size.x - TILE) < 0.5 and absf(rect.size.y - TILE) < 0.5:
			var off := Vector2i(roundi(fposmod(rect.position.x, TILE)), roundi(fposmod(rect.position.y, TILE)))
			off = Vector2i(off.x % int(TILE), off.y % int(TILE))
			if not groups.has(off):
				groups[off] = {}
			var cell := Vector2i(roundi((rect.position.x - float(off.x)) / TILE), roundi((rect.position.y - float(off.y)) / TILE))
			groups[off][cell] = true
		elif rect.size.x > 1.0 and rect.size.y > 1.0:
			var inset := minf(WALL_INSET, minf(rect.size.x, rect.size.y) * 0.25)
			var g := rect.grow(-inset)
			_add_occluder(PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]))
	for off in groups:
		for loop in _trace_loops(groups[off]):
			var pts := _inset_loop(loop, Vector2(off))
			if pts.size() >= 3:
				_add_occluder(pts)


func _add_occluder(pts: PackedVector2Array) -> void:
	var poly := OccluderPolygon2D.new()
	poly.polygon = pts
	poly.closed = true
	poly.cull_mode = OCCLUDER_CULL
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	_occluders.add_child(occ)


func _add_edge(edges: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not edges.has(a):
		edges[a] = []
	edges[a].append(b)


func _trace_loops(cells: Dictionary) -> Array:
	var edges := {}
	for c in cells:
		var cell: Vector2i = c
		if not cells.has(cell + Vector2i.UP):
			_add_edge(edges, cell, cell + Vector2i.RIGHT)
		if not cells.has(cell + Vector2i.RIGHT):
			_add_edge(edges, cell + Vector2i.RIGHT, cell + Vector2i.ONE)
		if not cells.has(cell + Vector2i.DOWN):
			_add_edge(edges, cell + Vector2i.ONE, cell + Vector2i.DOWN)
		if not cells.has(cell + Vector2i.LEFT):
			_add_edge(edges, cell + Vector2i.DOWN, cell)
	var starts: Array = []
	for v in edges:
		if (edges[v] as Array).size() == 1:
			starts.append(v)
	var loops: Array = []
	for s in starts:
		var outs_s: Array = edges[s]
		if outs_s.is_empty():
			continue
		var start: Vector2i = s
		var loop: Array = [start]
		var prev: Vector2i = start
		var cur: Vector2i = outs_s.pop_back()
		var guard := 0
		while cur != start and guard < 200000:
			guard += 1
			loop.append(cur)
			var outs: Array = edges.get(cur, [])
			if outs.is_empty():
				break
			var pick := 0
			if outs.size() > 1:
				var din := cur - prev
				var best := 99
				for i in range(outs.size()):
					var dout: Vector2i = outs[i] - cur
					var cr := din.x * dout.y - din.y * dout.x
					if cr < best:
						best = cr
						pick = i
			var nxt: Vector2i = outs[pick]
			outs.remove_at(pick)
			prev = cur
			cur = nxt
		if cur == start:
			loops.append(loop)
	return loops


func _inset_loop(loop: Array, origin: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := loop.size()
	for i in range(n):
		var a: Vector2i = loop[(i - 1 + n) % n]
		var b: Vector2i = loop[i]
		var c: Vector2i = loop[(i + 1) % n]
		var din := Vector2(b - a).normalized()
		var dout := Vector2(c - b).normalized()
		if din.is_equal_approx(dout):
			continue
		var nin := Vector2(-din.y, din.x)
		var nout := Vector2(-dout.y, dout.x)
		pts.append(origin + Vector2(b) * TILE + (nin + nout) * WALL_INSET)
	return pts
