extends CanvasLayer

## HUD: vidas y salud arriba a la izquierda, minimapa arriba a la derecha, objetivo al centro,
## score y combo abajo a la izquierda, arma y munición abajo a la derecha.
## Se construye por código y se actualiza con las señales de Global.

const UIStyle := preload("res://Scripts/UI/ui_style.gd")


# controles propios

## corazones en pixel-art, los perdidos se ven apagados
class Hearts extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	const SHAPE: Array[String] = [
		".XX...XX.",
		"XXXX.XXXX",
		"XXXXXXXXX",
		"XXXXXXXXX",
		".XXXXXXX.",
		"..XXXXX..",
		"...XXX...",
		"....X....",
	]
	var lives: int = 3
	var max_lives: int = 3
	var px: int = 3
	var gap: int = 10

	func _init() -> void:
		custom_minimum_size = Vector2(max_lives * (9 * px + gap), 8 * px + 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_lives(value: int) -> void:
		lives = value
		queue_redraw()

	func _draw() -> void:
		for i in range(max_lives):
			var origin := Vector2(2 + i * (9 * px + gap), 2)
			var full := i < lives
			var outline := UIStyle.LIFE.darkened(0.75) if full else UIStyle.BG
			var fill := UIStyle.LIFE if full else UIStyle.BAR_EMPTY
			for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
				_paint(origin + off, outline)
			_paint(origin, fill)
			if full:
				_paint_cells(origin, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)], UIStyle.LIFE.lightened(0.5))

	func _paint(origin: Vector2, color: Color) -> void:
		for y in range(SHAPE.size()):
			var row := SHAPE[y]
			for x in range(row.length()):
				if row[x] == "X":
					draw_rect(Rect2(origin + Vector2(x * px, y * px), Vector2(px, px)), color)

	func _paint_cells(origin: Vector2, cells: Array, color: Color) -> void:
		for c in cells:
			draw_rect(Rect2(origin + Vector2(c.x * px, c.y * px), Vector2(px, px)), color)


## silueta del arma equipada
class WeaponIcon extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	var weapon: int = 0

	func _init() -> void:
		custom_minimum_size = Vector2(112, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_weapon(index: int) -> void:
		weapon = index
		queue_redraw()

	func _draw() -> void:
		var s := minf(size.x / 44.0, size.y / 16.0)
		var o := (size - Vector2(44, 16) * s) * 0.5
		var col := Color(UIStyle.TEXT_DIM, 0.85)
		var parts: Array[Rect2] = []
		match weapon:
			0:
				parts = [
					Rect2(0, 4, 9, 6), Rect2(9, 4, 20, 4), Rect2(29, 5, 15, 2),
					Rect2(13, 2, 8, 2), Rect2(17, 8, 4, 8), Rect2(10, 8, 3, 5),
				]
			1:
				parts = [
					Rect2(0, 5, 9, 6), Rect2(8, 3, 14, 5), Rect2(22, 4, 22, 2),
					Rect2(22, 7, 22, 2), Rect2(24, 9, 10, 3), Rect2(12, 8, 4, 4),
				]
			2:
				parts = [Rect2(0, 6, 12, 5), Rect2(12, 3, 3, 11)]
				var blade := PackedVector2Array([
					o + Vector2(15, 5) * s, o + Vector2(42, 8) * s, o + Vector2(15, 11) * s,
				])
				draw_colored_polygon(blade, Color(UIStyle.TEXT, 0.9))
		for r in parts:
			draw_rect(Rect2(o + r.position * s, r.size * s), col)


## radar de lo que hay alrededor del jugador
class Minimap extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	## píxeles del mundo del centro al borde horizontal
	const RANGE := 260.0

	var _panel: StyleBoxFlat

	func _init() -> void:
		custom_minimum_size = Vector2(220, 124)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel = UIStyle.box(UIStyle.PANEL, UIStyle.BG, 2, 8, 0, 0)

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return

		var scale_f := (size.x * 0.5) / RANGE
		var center := size * 0.5
		var pp := player.global_position

		# paredes y muebles cercanos
		var level := get_tree().get_first_node_in_group("level")
		if level != null and "solid_rects" in level:
			var limit := Vector2(RANGE + 16.0, (size.y * 0.5) / scale_f + 16.0)
			for r in level.solid_rects:
				var rel: Vector2 = r.get_center() - pp
				if absf(rel.x) > limit.x or absf(rel.y) > limit.y:
					continue
				draw_rect(Rect2(center + (r.position - pp) * scale_f, r.size * scale_f), Color(UIStyle.BAR_EMPTY, 0.85))

		# puertas cerradas
		for door in get_tree().get_nodes_in_group("doors"):
			if door.is_open:
				continue
			var rel_door: Vector2 = door.global_position - pp
			draw_rect(Rect2(center + rel_door * scale_f - door.size * scale_f * 0.5, door.size * scale_f), UIStyle.OBJECTIVE)

		# salida (solo con la llave)
		if Global.has_key:
			for ex in get_tree().get_nodes_in_group("exit_zone"):
				var p := _edge((ex.global_position - pp) * scale_f + center)
				draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), UIStyle.BAR_FILL)

		# llave
		for k in get_tree().get_nodes_in_group("key_items"):
			var kp := _edge((k.global_position - pp) * scale_f + center)
			draw_colored_polygon(PackedVector2Array([kp + Vector2(0, -5), kp + Vector2(5, 0), kp + Vector2(0, 5), kp + Vector2(-5, 0)]), UIStyle.OBJECTIVE)

		# enemigos vivos
		for e in get_tree().get_nodes_in_group("Enemies"):
			if not e.has_method("is_alive") or not e.is_alive():
				continue
			var raw: Vector2 = (e.global_position - pp) * scale_f + center
			var inside := Rect2(Vector2(4, 4), size - Vector2(8, 8)).has_point(raw)
			var ep := _edge(raw)
			draw_circle(ep, 3.0, UIStyle.LIFE if inside else Color(UIStyle.LIFE, 0.45))

		# jugador al centro, con una rayita hacia donde apunta
		draw_circle(center, 4.5, UIStyle.BAR_FILL)
		draw_line(center, center + Vector2.RIGHT.rotated(player.global_rotation) * 9.0, UIStyle.BAR_FILL, 2.0)

	func _edge(p: Vector2) -> Vector2:
		return Vector2(clampf(p.x, 6.0, size.x - 6.0), clampf(p.y, 6.0, size.y - 6.0))


## mirilla que sigue al mouse (el cursor real está oculto)
class Crosshair extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	var pos: Vector2 = Vector2.ZERO
	var zoom: float = 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Color(1.0, 0.1, 0.1, 0.85)
		var gap := 4.0 * zoom
		var length := 9.0 * zoom
		draw_line(pos + Vector2(-gap - length, 0), pos + Vector2(-gap, 0), c, 2.0)
		draw_line(pos + Vector2(gap, 0), pos + Vector2(gap + length, 0), c, 2.0)
		draw_line(pos + Vector2(0, -gap - length), pos + Vector2(0, -gap), c, 2.0)
		draw_line(pos + Vector2(0, gap), pos + Vector2(0, gap + length), c, 2.0)
		draw_circle(pos, 1.5 * zoom, c)


## guía del objetivo: marcador si está en pantalla, si no una flecha en el borde con la distancia
class Guide extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	var target: Node2D = null
	var caption: String = ""
	var color: Color = Color("#FFB000")
	var _time: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if target == null or not is_instance_valid(target):
			return
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return

		# posición en pantalla (la cámara ya está en la transformación del canvas)
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * target.global_position
		var meters := int(round(player.global_position.distance_to(target.global_position) / 16.0))
		var text := "%s · %d m" % [caption, meters]

		var pulse := 0.75 + 0.25 * sin(_time * 5.0)
		var col := Color(color, pulse)
		var dark := Color(0, 0, 0, 0.75)
		var font := ThemeDB.fallback_font

		# zona segura, lejos de las esquinas con vidas, minimapa y arma
		var bounds := Rect2(Vector2(70, 110), size - Vector2(140, 250))

		if bounds.has_point(screen_pos):
			# visible: triángulo que rebota
			var bob := sin(_time * 6.0) * 4.0
			var tip := screen_pos + Vector2(0, -20 + bob)
			var tri := PackedVector2Array([tip, tip + Vector2(-9, -14), tip + Vector2(9, -14)])
			draw_colored_polygon(tri, col)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), dark, 2.0)
			_text(font, tip + Vector2(-90, -20), text, col, dark)
		else:
			# fuera de pantalla: flecha en el borde
			var center := bounds.get_center()
			var dir := (screen_pos - center).normalized()
			var half := bounds.size * 0.5
			var kx := half.x / maxf(absf(dir.x), 0.001)
			var ky := half.y / maxf(absf(dir.y), 0.001)
			var pos := center + dir * minf(kx, ky)
			var angle := dir.angle()
			var pts := PackedVector2Array([
				pos + Vector2(16, 0).rotated(angle),
				pos + Vector2(-10, -11).rotated(angle),
				pos + Vector2(-4, 0).rotated(angle),
				pos + Vector2(-10, 11).rotated(angle),
			])
			draw_colored_polygon(pts, col)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), dark, 2.0)
			# el texto va hacia adentro, junto a la flecha
			var text_pos := pos - dir * 34.0 + Vector2(-90, 5)
			_text(font, text_pos, text, col, dark)

	func _text(font: Font, at: Vector2, text: String, col: Color, outline: Color) -> void:
		# texto casi blanco con borde negro para que se lea sobre cualquier suelo
		var bright := Color(col.lerp(Color.WHITE, 0.7), 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 17, 8, Color(0, 0, 0, 0.95))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 17, bright)


# estado

var _root: Control
var _hearts: Hearts
var _health_bar: ProgressBar
var _minimap: Minimap
var _objective_big: Label
var _objective_small: Label
var _score_label: Label
var _combo_mult: Label
var _last_mult: int = 1
var _mult_tween: Tween = null
var _combo_bar: ProgressBar
var _ammo_label: Label
var _reserve_label: Label
var _reload_label: Label
var _toast: Label
var _crosshair: Crosshair
var _weapon_icon: WeaponIcon
var _weapon_name: Label
var _slot_labels: Array[Label] = []
var _melee_hint: Label
var _stealth_bar: ProgressBar
var _stealth_fill: StyleBoxFlat
var _stealth_label: Label
var _flow_label: Label
var _flow_banner: Label
var _flow_banner_tween: Tween = null
var _vignette: TextureRect
var _last_tier: int = 0
var _controls_bar: Label
var _guide: Guide
var _game_over: ColorRect
var _game_over_prompt: Label

var _objective_tween: Tween = null
var _screen_flash: ColorRect
var _flash_tween: Tween = null
var _last_health: float = -1.0
var _age: float = 0.0
var _toast_tween: Tween = null


func _ready() -> void:
	layer = 5

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)

	# destello al recibir daño (rojo) o curarse (verde), debajo del resto de la interfaz
	_screen_flash = ColorRect.new()
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_flash.color = Color(1, 0, 0, 0)
	_root.add_child(_screen_flash)

	_build_vignette()
	_build_top_left()
	_build_minimap()
	_build_stealth()
	_build_objective()
	_build_bottom_left()
	_build_weapon()
	_build_toast()
	_build_controls_bar()
	_build_guide()
	_build_crosshair()
	_build_game_over()

	# señales de Global
	Global.health_changed.connect(_on_health_changed)
	Global.ammo_changed.connect(_on_ammo_changed)
	Global.weapon_changed.connect(_on_weapon_changed)
	Global.reserve_changed.connect(_on_reserve_changed)
	Global.lives_changed.connect(_on_lives_changed)
	Global.score_changed.connect(_on_score_changed)
	Global.combo_changed.connect(_on_combo_changed)
	Global.objective_changed.connect(_on_objective_changed)
	Global.message.connect(_show_toast)
	Global.player_died.connect(_on_player_died)
	Global.player_respawned.connect(_on_player_respawned)

	# valores iniciales
	_on_health_changed(Global.health)
	_on_weapon_changed(Global.current_weapon)
	_on_ammo_changed(Global.ammo)
	_on_reserve_changed(Global.reserve_ammo)
	_on_lives_changed(Global.lives)
	_on_score_changed(Global.score)
	_on_combo_changed(Global.combo, 0.0)
	if Global.objective != "":
		_on_objective_changed(Global.objective)

	_apply_mouse_mode()


func _process(delta: float) -> void:
	_age += delta
	_crosshair.pos = get_viewport().get_mouse_position()
	_crosshair.zoom = Settings.crosshair_scale
	_crosshair.visible = not _game_over.visible
	_crosshair.queue_redraw()

	_minimap.visible = Settings.show_minimap
	_reload_label.visible = Global.reloading
	_update_guide()

	# rojo con el cargador vacío
	var empty := Global.ammo <= 0 and not Global.is_melee_weapon()
	_ammo_label.add_theme_color_override("font_color", UIStyle.LIFE if empty else UIStyle.AMMO)

	_update_stealth()
	_update_flow(delta)
	if _controls_bar != null and _controls_bar.visible:
		_controls_bar.modulate.a = clampf((16.0 - _age) / 2.0, 0.0, 1.0)


# construcción

func _place(c: Control, ax: float, ay: float, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom
	if ax >= 1.0:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if ay >= 1.0:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _outlined(l: Label, size: int = 4) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", size)
	return l


func _build_top_left() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(box, 0.0, 0.0, 24, 20, 260, 70)
	_root.add_child(box)

	_hearts = Hearts.new()
	box.add_child(_hearts)

	_health_bar = UIStyle.bar(UIStyle.LIFE, Vector2(200, 14))
	box.add_child(_health_bar)


func _build_minimap() -> void:
	_minimap = Minimap.new()
	_place(_minimap, 1.0, 0.0, -244, 20, -24, 144)
	_root.add_child(_minimap)


func _build_objective() -> void:
	# grande al centro al cambiar, luego queda el pequeño
	_objective_big = UIStyle.label("", 52, UIStyle.OBJECTIVE, true)
	_objective_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(_objective_big, 10)
	_place(_objective_big, 0.5, 0.42, -600, -50, 600, 50)
	_objective_big.modulate.a = 0.0
	_root.add_child(_objective_big)

	_objective_small = UIStyle.label("", 20, UIStyle.OBJECTIVE, true)
	_objective_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(_objective_small, 6)
	_place(_objective_small, 0.5, 0.0, -300, 22, 300, 52)
	_root.add_child(_objective_small)


func _build_bottom_left() -> void:
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(stats, 0.0, 1.0, 24, -92, 280, -24)
	_root.add_child(stats)

	_score_label = UIStyle.label("SCORE: 0", 22, UIStyle.TEXT_DIM)
	_outlined(_score_label)
	stats.add_child(_score_label)

	var combo_box := VBoxContainer.new()
	combo_box.add_theme_constant_override("separation", 4)
	combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(combo_box, 0.0, 1.0, 300, -128, 620, -24)
	_root.add_child(combo_box)

	# encima de la barra: COMBO y multiplicador, que rebota al subir
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_box.add_child(head)

	var caption := UIStyle.label("COMBO", 18, UIStyle.TEXT_DIM)
	caption.size_flags_vertical = Control.SIZE_SHRINK_END
	_outlined(caption)
	head.add_child(caption)

	_combo_mult = UIStyle.label("X1", 42, UIStyle.TEXT, true)
	_outlined(_combo_mult, 7)
	head.add_child(_combo_mult)

	_combo_bar = UIStyle.bar(UIStyle.BAR_FILL, Vector2(300, 22))
	_combo_bar.max_value = 1.0
	_combo_bar.value = 0.0
	combo_box.add_child(_combo_bar)

	# debajo: el flow activo y el daño extra
	_flow_label = UIStyle.label("", 15, UIStyle.TEXT_DIM, true)
	_outlined(_flow_label)
	combo_box.add_child(_flow_label)


func _build_weapon() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, Color.TRANSPARENT, 0, 12, 10, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, 1.0, 1.0, -330, -134, -24, -24)
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	# ranuras de armas
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 12)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(slots)
	var slot_names := ["1 RIFLE", "2 ESCOPETA", "3 CUCHILLO"]
	for i in range(slot_names.size()):
		var l := UIStyle.label(slot_names[i], 12, UIStyle.TEXT_DIM, true)
		slots.add_child(l)
		_slot_labels.append(l)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	_weapon_icon = WeaponIcon.new()
	row.add_child(_weapon_icon)

	var ammo_box := VBoxContainer.new()
	ammo_box.add_theme_constant_override("separation", 0)
	ammo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ammo_box)

	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 4)
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_box.add_child(numbers)

	_ammo_label = UIStyle.label("20", 46, UIStyle.AMMO, true)
	numbers.add_child(_ammo_label)

	_reserve_label = UIStyle.label("/60", 22, UIStyle.TEXT_DIM)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	numbers.add_child(_reserve_label)

	_reload_label = UIStyle.label("RECARGANDO…", 14, UIStyle.OBJECTIVE, true)
	_reload_label.visible = false
	ammo_box.add_child(_reload_label)

	_weapon_name = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	ammo_box.add_child(_weapon_name)

	_melee_hint = UIStyle.label("[F] / CLIC DER.: CUCHILLO", 11, UIStyle.TEXT_DIM)
	column.add_child(_melee_hint)


## indicador de sigilo bajo el minimapa
func _build_stealth() -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(box, 1.0, 0.0, -244, 150, -24, 172)
	_root.add_child(box)

	var caption := UIStyle.label("SIGILO", 13, UIStyle.TEXT_DIM, true)
	_outlined(caption, 3)
	box.add_child(caption)

	_stealth_bar = UIStyle.bar(UIStyle.BAR_FILL, Vector2(70, 10))
	_stealth_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stealth_fill = UIStyle.box(UIStyle.BAR_FILL, Color.TRANSPARENT, 0, 2, 0, 0)
	_stealth_bar.add_theme_stylebox_override("fill", _stealth_fill)
	_stealth_bar.value = 0.0
	box.add_child(_stealth_bar)

	_stealth_label = UIStyle.label("OCULTO", 13, UIStyle.BAR_FILL, true)
	_outlined(_stealth_label, 3)
	box.add_child(_stealth_label)


## viñeta que se enciende con frenesí y berserk
func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256

	_vignette = TextureRect.new()
	_vignette.texture = texture
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0)
	_root.add_child(_vignette)

	# aviso al subir de nivel de flow
	_flow_banner = UIStyle.label("", 60, UIStyle.OBJECTIVE, true)
	_flow_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flow_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(_flow_banner, 10)
	_place(_flow_banner, 0.5, 0.25, -400, -40, 400, 40)
	_flow_banner.modulate.a = 0.0
	_root.add_child(_flow_banner)


func _build_toast() -> void:
	_toast = UIStyle.label("", 22, UIStyle.TEXT, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(_toast, 6)
	_place(_toast, 0.5, 1.0, -300, -150, 300, -118)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _build_guide() -> void:
	_guide = Guide.new()
	_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_guide)


## qué mostrar en la guía: llave, puerta cerrada, salida
func _update_guide() -> void:
	var target: Node2D = null
	var caption := ""
	var col := UIStyle.OBJECTIVE

	var tutorial_target := _nearest_to_player("tutorial_target")
	if tutorial_target != null:
		# en el tutorial apunta al objetivo del paso
		target = tutorial_target
		caption = String(tutorial_target.get_meta("caption", "AQUÍ"))
	elif Global.health > 0.0:
		if not Global.has_key:
			target = _nearest_to_player("key_items")
			caption = "LLAVE"
			if target == null:
				# la llave aparece al caer el último enemigo; mientras, guía a los que quedan
				target = _nearest_to_player("Enemies")
				caption = "ENEMIGO"
				col = UIStyle.LIFE
		else:
			var door := _nearest_to_player("doors", true)
			if door != null:
				target = door
				caption = "PUERTA"
			else:
				target = _nearest_to_player("exit_zone")
				caption = "SALIDA"
				col = UIStyle.BAR_FILL

	_guide.target = target
	_guide.caption = caption
	_guide.color = col


func _nearest_to_player(group_name: String, only_closed: bool = false) -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group_name):
		var node := n as Node2D
		if node == null:
			continue
		if only_closed and node.get("is_open") == true:
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var d := player.global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## recordatorio de controles los primeros segundos
func _build_controls_bar() -> void:
	_controls_bar = UIStyle.label("", 14, UIStyle.TEXT_DIM, true)
	_controls_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(_controls_bar, 4)
	_place(_controls_bar, 0.5, 0.0, -520, 78, 520, 98)
	_root.add_child(_controls_bar)
	_controls_bar.text = "%s MOVER · CLIC DISPARAR (MANTENER = RÁFAGA) · 1 2 3 ARMAS · %s RECARGAR · %s SIGILO · %s CUCHILLO · %s INTERACTUAR" % [
		"WASD", Settings.key_name("reload"), Settings.key_name("sneak"), Settings.key_name("melee"), Settings.key_name("action")]
	# el tutorial ya tiene su tarjeta
	if get_tree().get_first_node_in_group("tutorial") != null:
		_controls_bar.visible = false


func _build_crosshair() -> void:
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_crosshair)


func _build_game_over() -> void:
	_game_over = ColorRect.new()
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over.color = Color(0, 0, 0, 0.62)
	_game_over.visible = false
	_root.add_child(_game_over)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := UIStyle.label("AGENTE CAÍDO", 64, UIStyle.LIFE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outlined(title, 8)
	box.add_child(title)

	_game_over_prompt = UIStyle.label("", 20, UIStyle.TEXT)
	_game_over_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_game_over_prompt)

	var retry := UIStyle.button("REAPARECER  [R]", Vector2(320, 50))
	retry.name = "RetryButton"
	retry.focus_mode = Control.FOCUS_NONE
	retry.pressed.connect(_retry)
	box.add_child(retry)

	var menu := UIStyle.button("MENÚ PRINCIPAL", Vector2(320, 50))
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(GameManager.go_to_menu)
	box.add_child(menu)


# reacciones a Global

func _on_health_changed(new_health: float) -> void:
	_health_bar.value = new_health / Global.max_health * 100.0
	# solo destella con cambios reales, no al cargar el nivel
	if _age > 0.6 and _last_health >= 0.0:
		if new_health < _last_health - 0.5:
			_pulse_screen(Color(1.0, 0.08, 0.12, 0.34), 0.4)
		elif new_health > _last_health + 0.5:
			_pulse_screen(Color(0.2, 1.0, 0.5, 0.22), 0.45)
	_last_health = new_health


func _pulse_screen(color: Color, duration: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_screen_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_screen_flash, "color:a", 0.0, duration)


func _on_ammo_changed(_new_ammo: int) -> void:
	_refresh_ammo()


func _on_reserve_changed(_new_reserve: int) -> void:
	_refresh_ammo()


func _on_weapon_changed(index: int) -> void:
	_weapon_icon.set_weapon(index)
	for i in range(_slot_labels.size()):
		_slot_labels[i].add_theme_color_override("font_color", UIStyle.OBJECTIVE if i == index else UIStyle.TEXT_DIM)
	_weapon_name.text = String(Global.Weapons.LIST[index]["name"])
	_melee_hint.visible = index != Global.Weapons.KNIFE
	_refresh_ammo()


func _refresh_ammo() -> void:
	if Global.is_melee_weapon():
		_ammo_label.text = "∞"
		_reserve_label.text = ""
	else:
		_ammo_label.text = str(Global.ammo)
		_reserve_label.text = "/%d" % Global.reserve_ammo


func _on_lives_changed(new_lives: int) -> void:
	_hearts.set_lives(new_lives)


func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE: %d" % new_score


func _on_combo_changed(multiplier: int, time_fraction: float) -> void:
	_combo_bar.value = time_fraction
	if multiplier == _last_mult:
		return
	_last_mult = multiplier
	_combo_mult.text = "X%d" % multiplier

	# el color sube con el combo
	var tint := UIStyle.TEXT
	if multiplier >= 10:
		tint = UIStyle.LIFE
	elif multiplier >= 5:
		tint = UIStyle.OBJECTIVE
	elif multiplier >= 2:
		tint = UIStyle.BAR_FILL
	_combo_mult.add_theme_color_override("font_color", tint)

	# rebota al subir
	if multiplier > 1:
		if _mult_tween != null and _mult_tween.is_valid():
			_mult_tween.kill()
		_combo_mult.pivot_offset = _combo_mult.size * 0.5
		_combo_mult.scale = Vector2(1.9, 1.9)
		_mult_tween = create_tween()
		_mult_tween.tween_property(_combo_mult, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_combo_mult.scale = Vector2.ONE


func _on_objective_changed(text: String) -> void:
	var full := "OBJETIVO: " + text
	_objective_small.text = full
	_objective_big.text = full

	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	_objective_big.modulate.a = 1.0
	_objective_tween = create_tween()
	_objective_tween.tween_interval(2.2)
	_objective_tween.tween_property(_objective_big, "modulate:a", 0.0, 0.8)


func _show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2 + float(text.length()) * 0.035)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _on_player_died() -> void:
	_game_over.visible = true
	# quita el aviso grande para no tapar el mensaje
	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	_objective_big.modulate.a = 0.0
	_apply_mouse_mode()
	var retry := _game_over.find_child("RetryButton", true, false) as Button
	if Global.lives > 1:
		_game_over_prompt.text = "Presiona [R] para reaparecer (-1 vida)"
		if retry != null:
			retry.text = "REAPARECER  [R]"
	else:
		# última vida: se pierde todo el avance
		_hearts.set_lives(0)
		_game_over_prompt.text = "¡SIN VIDAS!\nPierdes tu puntaje y empiezas desde el NIVEL 1.\nPresiona [R] para reiniciar"
		if retry != null:
			retry.text = "VOLVER AL NIVEL 1  [R]"


func _on_player_respawned() -> void:
	_game_over.visible = false
	_apply_mouse_mode()


## qué tan cerca está algún enemigo de detectarte
func _update_stealth() -> void:
	var highest := 0.0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.has_method("is_alive") and e.is_alive():
			var aw := float(e.get("awareness"))
			# un enemigo en combate cuenta como detección total aunque haya perdido de vista al jugador
			var st := int(e.get("state"))
			if st == 1 or st == 5:
				aw = 1.0
			highest = maxf(highest, aw)

	var text := "OCULTO"
	var col := UIStyle.BAR_FILL
	if Global.grace_time > 0.0:
		text = "OCULTO · %d s" % int(ceil(Global.grace_time))
		highest = 0.0
	elif highest >= 0.999:
		text = "¡DETECTADO!"
		col = UIStyle.LIFE
	elif highest > 0.25:
		text = "SOSPECHA"
		col = UIStyle.OBJECTIVE

	_stealth_bar.value = highest * 100.0
	_stealth_fill.bg_color = col
	_stealth_label.text = text
	_stealth_label.add_theme_color_override("font_color", col)


## modo flow: etiqueta, viñeta y aviso al subir de nivel
func _update_flow(_delta: float) -> void:
	var tier := Global.flow_tier()
	var tint := UIStyle.TEXT_DIM
	match tier:
		1: tint = UIStyle.AMMO
		2: tint = UIStyle.OBJECTIVE
		3: tint = UIStyle.LIFE

	if tier > 0:
		_flow_label.text = "%s · DAÑO ×%.2f" % [Global.flow_name(), Global.damage_mult()]
	else:
		_flow_label.text = "DAÑO ×%.2f" % Global.damage_mult() if Global.combo > 1 else ""
	_flow_label.add_theme_color_override("font_color", tint)

	# la viñeta aparece en Frenesí y late en Berserk
	var strength: float = [0.0, 0.0, 0.32, 0.6][tier]
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * (0.014 if tier >= 3 else 0.007))
	_vignette.modulate = Color(tint, strength * pulse)

	if tier > _last_tier:
		_show_flow_banner(tier, tint)
	_last_tier = tier


func _show_flow_banner(tier: int, tint: Color) -> void:
	_flow_banner.text = "¡%s!" % Global.FLOW_NAMES[tier]
	_flow_banner.add_theme_color_override("font_color", tint)
	if _flow_banner_tween != null and _flow_banner_tween.is_valid():
		_flow_banner_tween.kill()
	_flow_banner.pivot_offset = _flow_banner.size * 0.5
	_flow_banner.scale = Vector2(1.6, 1.6)
	_flow_banner.modulate.a = 1.0
	_flow_banner_tween = create_tween()
	_flow_banner_tween.tween_property(_flow_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flow_banner_tween.tween_interval(0.7)
	_flow_banner_tween.tween_property(_flow_banner, "modulate:a", 0.0, 0.4)


## ratón confinado a la ventana; en partida además se oculta (la mirilla la dibuja el HUD)
func _apply_mouse_mode() -> void:
	if _game_over.visible or get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)


func _notification(what: int) -> void:
	# al volver a la ventana se recupera la captura
	if (what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN) and is_node_ready():
		_apply_mouse_mode()


func _input(event: InputEvent) -> void:
	# con la pantalla de muerte, R o Enter/Espacio reaparecen
	if not _game_over.visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_R or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_retry()


func _retry() -> void:
	if Global.lives > 1:
		Global.respawn()
		_game_over.visible = false
		_apply_mouse_mode()
	else:
		# sin vidas extra reinicia el nivel desde el principio
		Global.reset_game()
