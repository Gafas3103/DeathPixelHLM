extends CanvasLayer

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const Story := preload("res://Scripts/story.gd")
const RADIO_CPS := 48.0
const RADIO_QUEUE_MAX := 8


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


class Minimap extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
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

		var level := get_tree().get_first_node_in_group("level")
		if level != null and "solid_rects" in level:
			var limit := Vector2(RANGE + 16.0, (size.y * 0.5) / scale_f + 16.0)
			for r in level.solid_rects:
				var rel: Vector2 = r.get_center() - pp
				if absf(rel.x) > limit.x or absf(rel.y) > limit.y:
					continue
				draw_rect(Rect2(center + (r.position - pp) * scale_f, r.size * scale_f), Color(UIStyle.BAR_EMPTY, 0.85))

		for door in get_tree().get_nodes_in_group("doors"):
			if door.is_open:
				continue
			var rel_door: Vector2 = door.global_position - pp
			draw_rect(Rect2(center + rel_door * scale_f - door.size * scale_f * 0.5, door.size * scale_f), UIStyle.OBJECTIVE)

		if Global.has_key:
			for ex in get_tree().get_nodes_in_group("exit_zone"):
				var p := _edge((ex.global_position - pp) * scale_f + center)
				draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), UIStyle.BAR_FILL)

		for k in get_tree().get_nodes_in_group("key_items"):
			var kp := _edge((k.global_position - pp) * scale_f + center)
			draw_colored_polygon(PackedVector2Array([kp + Vector2(0, -5), kp + Vector2(5, 0), kp + Vector2(0, 5), kp + Vector2(-5, 0)]), UIStyle.OBJECTIVE)

		for e in get_tree().get_nodes_in_group("Enemies"):
			if not e.has_method("is_alive") or not e.is_alive():
				continue
			var raw: Vector2 = (e.global_position - pp) * scale_f + center
			var inside := Rect2(Vector2(4, 4), size - Vector2(8, 8)).has_point(raw)
			var ep := _edge(raw)
			draw_circle(ep, 3.0, UIStyle.LIFE if inside else Color(UIStyle.LIFE, 0.45))

		draw_circle(center, 4.5, UIStyle.BAR_FILL)
		draw_line(center, center + Vector2.RIGHT.rotated(player.global_rotation) * 9.0, UIStyle.BAR_FILL, 2.0)

	func _edge(p: Vector2) -> Vector2:
		return Vector2(clampf(p.x, 6.0, size.x - 6.0), clampf(p.y, 6.0, size.y - 6.0))


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


class Guide extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	var target: Node2D = null
	var caption: String = ""
	var color: Color = Color("#FFB000")
	var top: float = 110.0
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

		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * target.global_position
		var meters := int(round(player.global_position.distance_to(target.global_position) / 16.0))
		var text := "%s · %d m" % [caption, meters]

		var pulse := 0.75 + 0.25 * sin(_time * 5.0)
		var col := Color(color, pulse)
		var dark := Color(0, 0, 0, 0.75)
		var font := ThemeDB.fallback_font

		var bounds := Rect2(Vector2(70, top), size - Vector2(140, top + 140.0))

		if bounds.has_point(screen_pos):
			var bob := sin(_time * 6.0) * 4.0
			var tip := screen_pos + Vector2(0, -20 + bob)
			var tri := PackedVector2Array([tip, tip + Vector2(-9, -14), tip + Vector2(9, -14)])
			draw_colored_polygon(tri, col)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), dark, 2.0)
			_text(font, tip + Vector2(-90, -20), text, col, dark)
		else:
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
			var text_pos := pos - dir * 34.0 + Vector2(-90, 5)
			_text(font, text_pos, text, col, dark)

	func _text(font: Font, at: Vector2, text: String, col: Color, outline: Color) -> void:
		var bright := Color(col.lerp(Color.WHITE, 0.7), 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 17, 8, Color(0, 0, 0, 0.95))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 17, bright)


class BossBar extends Control:
	const UIStyle := preload("res://Scripts/UI/ui_style.gd")
	const MARKS: Array[float] = [0.66, 0.33]
	var ratio: float = 1.0
	var trail: float = 1.0
	var phase: int = 0
	var flash: float = 0.0
	var _hold: float = 0.0
	var _time: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(560, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_ratio(value: float) -> void:
		value = clampf(value, 0.0, 1.0)
		if value < ratio - 0.0001:
			flash = maxf(flash, 0.18)
			_hold = 0.35
		ratio = value
		if trail < ratio:
			trail = ratio

	func _process(delta: float) -> void:
		_time += delta
		flash = maxf(0.0, flash - delta)
		if _hold > 0.0:
			_hold -= delta
		elif trail > ratio:
			trail = move_toward(trail, ratio, delta * 0.45)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.8))
		var inner := r.grow(-2.0)
		draw_rect(inner, UIStyle.BAR_EMPTY)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * trail, inner.size.y)), Color(1.0, 0.86, 0.7, 0.85))
		var k := clampf(flash / 0.18, 0.0, 1.0)
		var fill := UIStyle.LIFE.lerp(Color.WHITE, k * 0.65)
		if phase >= 2:
			fill = fill.lerp(Color(1.0, 0.05, 0.2), 0.25 + 0.25 * sin(_time * 9.0))
		var filled := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
		draw_rect(filled, fill)
		draw_rect(Rect2(filled.position, Vector2(filled.size.x, 3.0)), Color(1, 1, 1, 0.2))
		for mark in MARKS:
			var x := inner.position.x + inner.size.x * mark
			var col := UIStyle.TEXT if ratio > mark else Color(UIStyle.TEXT, 0.3)
			draw_line(Vector2(x, r.position.y - 3.0), Vector2(x, r.end.y + 3.0), Color(0, 0, 0, 0.9), 4.0)
			draw_line(Vector2(x, r.position.y - 3.0), Vector2(x, r.end.y + 3.0), col, 2.0)
		draw_rect(r, UIStyle.LIFE.darkened(0.35), false, 2.0)


class RadioIcon extends Control:
	var color: Color = Color.WHITE
	var active: bool = false
	var _time: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(20, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for i in range(4):
			var h := 4.0 + float(i) * 3.0
			var a := 0.9
			if active:
				a = 0.35 + 0.65 * clampf(0.5 + 0.5 * sin(_time * 16.0 - float(i) * 1.4), 0.0, 1.0)
			draw_rect(Rect2(float(i) * 5.0, size.y - h, 3.0, h), Color(color, a))


var _root: Control
var _hearts: Hearts
var _health_bar: ProgressBar
var _minimap: Minimap
var _objective_big: Label
var _objective_big_pending: bool = false
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
var _in_tutorial: bool = false
var _ammo_empty: bool = false

var _boss_box: VBoxContainer
var _boss_bar: BossBar
var _boss_phase_label: Label
var _boss_last_phase: int = 0
var _boss_tween: Tween = null

var _alarm_box: PanelContainer
var _alarm_title: Label
var _alarm_time: Label
var _alarm_caption: Label
var _alarm_left: float = 0.0

var _radio: PanelContainer
var _radio_style: StyleBoxFlat
var _radio_icon: RadioIcon
var _radio_speaker: Label
var _radio_text: Label
var _radio_queue: Array = []
var _radio_state: int = 0
var _radio_timer: float = 0.0
var _radio_chars: float = 0.0

var _timer_label: Label
var _timer_shown: int = -1

var _flash_box: HBoxContainer
var _flash_label: Label
var _flash_state: Label
var _flash_known: bool = false
var _flash_refresh: float = 0.0


func _ready() -> void:
	layer = 5
	_in_tutorial = GameManager.in_tutorial or get_tree().get_first_node_in_group("tutorial") != null

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)

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
	_build_boss_bar()
	_build_alarm()
	_build_radio()
	_build_flashlight()
	_build_guide()
	_build_crosshair()
	_build_game_over()

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
	Global.radio_message.connect(_on_radio_message)
	Global.boss_spawned.connect(_on_boss_spawned)
	Global.boss_health_changed.connect(_on_boss_health_changed)
	Global.boss_defeated.connect(_on_boss_defeated)
	Global.alarm_changed.connect(_on_alarm_changed)
	Global.flashlight_changed.connect(_on_flashlight_changed)

	call_deferred("_sync_level_state")

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
	if _objective_big_pending and not get_tree().paused:
		_show_objective_big()
	_crosshair.pos = get_viewport().get_mouse_position()
	_crosshair.zoom = Settings.crosshair_scale
	_crosshair.visible = not _game_over.visible
	_crosshair.queue_redraw()

	_minimap.visible = Settings.show_minimap
	_reload_label.visible = Global.reloading
	_guide.top = 160.0 if (_boss_box.visible or _alarm_box.visible) else 110.0
	_update_guide()
	_update_radio(delta)
	_update_alarm_fx()
	_update_timer()
	_update_flashlight(delta)

	var empty := Global.ammo <= 0 and not Global.is_melee_weapon()
	if empty != _ammo_empty:
		_ammo_empty = empty
		_ammo_label.add_theme_color_override("font_color", UIStyle.LIFE if empty else UIStyle.AMMO)

	_update_stealth()
	_update_flow(delta)
	if _controls_bar != null and _controls_bar.visible:
		_controls_bar.modulate.a = clampf((16.0 - _age) / 2.0, 0.0, 1.0)


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

	_timer_label = UIStyle.label("", 14, UIStyle.TEXT_DIM, true)
	_outlined(_timer_label, 3)
	_timer_label.visible = false
	stats.add_child(_timer_label)

	var combo_box := VBoxContainer.new()
	combo_box.add_theme_constant_override("separation", 4)
	combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(combo_box, 0.0, 1.0, 300, -128, 620, -24)
	_root.add_child(combo_box)

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


func _update_guide() -> void:
	var target: Node2D = null
	var caption := ""
	var col := UIStyle.OBJECTIVE

	var tutorial_target := _nearest_to_player("tutorial_target")
	if tutorial_target != null:
		target = tutorial_target
		caption = String(tutorial_target.get_meta("caption", "AQUÍ"))
	elif Global.health > 0.0:
		var boss: Variant = Global.boss_node
		if Global.boss_alive and is_instance_valid(boss) and boss is Node2D:
			target = boss as Node2D
			caption = "CONTRATISTA"
			col = UIStyle.LIFE
		elif not Global.has_key:
			target = _nearest_to_player("key_items")
			caption = "LLAVE"
			if target == null:
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


func _build_controls_bar() -> void:
	_controls_bar = UIStyle.label("", 14, UIStyle.TEXT_DIM, true)
	_controls_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(_controls_bar, 4)
	_place(_controls_bar, 0.0, 0.0, 24, 78, 1024, 98)
	_root.add_child(_controls_bar)
	_controls_bar.text = "%s MOVER · CLIC DISPARAR (MANTENER = RÁFAGA) · 1 2 3 ARMAS · %s RECARGAR · %s SIGILO · %s CUCHILLO · %s INTERACTUAR" % [
		"WASD", Settings.key_name("reload"), Settings.key_name("sneak"), Settings.key_name("melee"), Settings.key_name("action")]
	if get_tree().get_first_node_in_group("tutorial") != null:
		_controls_bar.visible = false


func _build_boss_bar() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 3)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_boss_box, 0.5, 0.0, -280, 104, 280, 150)
	_root.add_child(_boss_box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(head)

	var boss_name := UIStyle.label(Story.BOSS_NAME, 18, UIStyle.LIFE, true)
	boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outlined(boss_name, 5)
	head.add_child(boss_name)

	var title := UIStyle.label(Story.BOSS_TITLE, 12, UIStyle.TEXT_DIM, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outlined(title, 3)
	head.add_child(title)

	_boss_phase_label = UIStyle.label("FASE 1/3", 12, UIStyle.TEXT, true)
	_boss_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_outlined(_boss_phase_label, 3)
	head.add_child(_boss_phase_label)

	_boss_bar = BossBar.new()
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false


func _build_alarm() -> void:
	_alarm_box = PanelContainer.new()
	_alarm_box.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.BG, 0.8), UIStyle.LIFE, 2, 6, 16, 2))
	_alarm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_alarm_box, 0.5, 0.0, -200, 104, 200, 150)
	_root.add_child(_alarm_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alarm_box.add_child(row)

	_alarm_title = UIStyle.label("ALARMA", 16, UIStyle.LIFE, true)
	_alarm_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outlined(_alarm_title, 4)
	row.add_child(_alarm_title)

	_alarm_time = UIStyle.label("00:00", 28, UIStyle.TEXT, true)
	_alarm_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outlined(_alarm_time, 5)
	row.add_child(_alarm_time)

	_alarm_caption = UIStyle.label("REFUERZOS EN CAMINO", 12, UIStyle.TEXT_DIM, true)
	_alarm_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outlined(_alarm_caption, 3)
	row.add_child(_alarm_caption)
	_alarm_box.visible = false


func _build_radio() -> void:
	_radio = PanelContainer.new()
	_radio_style = UIStyle.box(Color(UIStyle.BG, 0.86), UIStyle.AMMO, 0, 6, 14, 10)
	_radio_style.border_width_left = 4
	_radio.add_theme_stylebox_override("panel", _radio_style)
	_radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_radio, 0.0, 1.0, 24, -230, 484, -156)
	_root.add_child(_radio)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)

	_radio_icon = RadioIcon.new()
	_radio_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_radio_icon)

	_radio_speaker = UIStyle.label("", 13, UIStyle.AMMO, true)
	_outlined(_radio_speaker, 3)
	head.add_child(_radio_speaker)

	var tag := UIStyle.label("RADIO", 11, UIStyle.TEXT_DIM, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)

	_radio_text = UIStyle.label("", 16, UIStyle.TEXT)
	_radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_text.custom_minimum_size = Vector2(426, 0)
	_outlined(_radio_text, 3)
	column.add_child(_radio_text)
	_radio.visible = false


func _build_flashlight() -> void:
	_flash_box = HBoxContainer.new()
	_flash_box.add_theme_constant_override("separation", 10)
	_flash_box.alignment = BoxContainer.ALIGNMENT_END
	_flash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_flash_box, 1.0, 1.0, -420, -196, -24, -172)
	_root.add_child(_flash_box)

	_flash_state = UIStyle.label("", 12, UIStyle.BAR_FILL, true)
	_flash_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outlined(_flash_state, 3)
	_flash_box.add_child(_flash_state)

	_flash_label = UIStyle.label("", 13, UIStyle.OBJECTIVE, true)
	_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outlined(_flash_label, 3)
	_flash_box.add_child(_flash_label)
	_flash_box.visible = false


func _sync_level_state() -> void:
	if Global.boss_alive and is_instance_valid(Global.boss_node):
		_on_boss_spawned(Global.boss_node)
	_on_alarm_changed(Global.alarm_active, _alarm_left)


func _clock(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	return "%02d:%02d" % [floori(float(s) / 60.0), s % 60]


func _on_radio_message(speaker: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	_radio_queue.append([speaker, text])
	while _radio_queue.size() > RADIO_QUEUE_MAX:
		_radio_queue.pop_front()
	if _radio_state == 0 or _radio_state == 3:
		_next_radio()


func _next_radio() -> void:
	if _radio_queue.is_empty():
		_radio_state = 3
		_radio_icon.active = false
		return
	var item: Array = _radio_queue.pop_front()
	var speaker := String(item[0])
	var col := Story.speaker_color(speaker)
	_radio_speaker.text = speaker
	_radio_speaker.add_theme_color_override("font_color", col)
	_radio_style.border_color = col
	_radio_icon.color = col
	_radio_icon.active = true
	_radio_text.text = String(item[1])
	_radio_text.visible_characters = 0
	_radio_chars = 0.0
	_radio_state = 1
	_radio.visible = true
	_radio.modulate.a = 1.0


func _update_radio(delta: float) -> void:
	match _radio_state:
		1:
			var total := _radio_text.text.length()
			_radio_chars += delta * RADIO_CPS * minf(1.0 + 0.5 * float(_radio_queue.size()), 2.5)
			if _radio_chars >= float(total):
				_radio_text.visible_characters = -1
				_radio_icon.active = false
				_radio_state = 2
				_radio_timer = 1.3 + float(total) * 0.035
				if not _radio_queue.is_empty():
					_radio_timer *= 0.6
			else:
				_radio_text.visible_characters = int(_radio_chars)
		2:
			_radio_timer -= delta
			if _radio_timer <= 0.0:
				_next_radio()
		3:
			_radio.modulate.a = maxf(0.0, _radio.modulate.a - delta * 2.5)
			if _radio.modulate.a <= 0.0:
				_radio.visible = false
				_radio_state = 0


func _on_boss_spawned(boss: Node) -> void:
	var ratio := 1.0
	if boss != null and is_instance_valid(boss):
		var max_hp: Variant = boss.get("max_health")
		var hp: Variant = boss.get("health")
		if max_hp != null and hp != null and float(max_hp) > 0.0 and float(hp) > 0.0:
			ratio = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_boss_last_phase = 0
	_radio_queue.clear()
	if _radio_state == 1 or _radio_state == 2:
		var was_typing := _radio_state == 1
		_radio_text.visible_characters = -1
		_radio_icon.active = false
		_radio_state = 2
		_radio_timer = 0.5 if was_typing else minf(_radio_timer, 0.5)
	_boss_bar.ratio = ratio
	_boss_bar.trail = ratio
	_boss_bar.phase = 0
	_boss_phase_label.text = "FASE 1/3"
	_boss_phase_label.add_theme_color_override("font_color", UIStyle.TEXT)
	_alarm_box.visible = false
	_boss_box.visible = true
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_box.modulate.a = 0.0
	_boss_tween = create_tween()
	_boss_tween.tween_property(_boss_box, "modulate:a", 1.0, 0.5)
	_pulse_screen(Color(0.85, 0.02, 0.06, 0.32), 0.9)


func _on_boss_health_changed(current: float, maximum: float, phase: int) -> void:
	if not _boss_box.visible:
		if current <= 0.0:
			return
		_on_boss_spawned(null)
	_boss_bar.set_ratio(current / maxf(maximum, 1.0))
	_boss_bar.phase = phase
	_boss_phase_label.text = "FASE %d/3" % (clampi(phase, 0, 2) + 1)
	if phase > _boss_last_phase:
		_boss_bar.flash = 0.5
		_boss_phase_label.add_theme_color_override("font_color", UIStyle.LIFE)
		_pulse_screen(Color(1.0, 0.1, 0.1, 0.26), 0.6)
	_boss_last_phase = phase


func _on_boss_defeated() -> void:
	if not _boss_box.visible:
		return
	_boss_bar.set_ratio(0.0)
	_boss_phase_label.text = "DERROTADO"
	_boss_phase_label.add_theme_color_override("font_color", UIStyle.OBJECTIVE)
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_box.modulate.a = 1.0
	_boss_tween = create_tween()
	_boss_tween.tween_interval(1.8)
	_boss_tween.tween_property(_boss_box, "modulate:a", 0.0, 0.6)
	_boss_tween.tween_callback(_boss_box.hide)
	_pulse_screen(Color(1.0, 0.9, 0.7, 0.3), 0.9)


func _on_alarm_changed(active: bool, time_left: float) -> void:
	_alarm_left = time_left
	if not active or _boss_box.visible:
		_alarm_box.visible = false
		return
	_alarm_box.visible = true
	var clock := _clock(ceilf(time_left))
	if _alarm_time.text != clock:
		_alarm_time.text = clock
	var caption := "REFUERZOS EN CAMINO" if time_left > 0.0 else "¡LLEGAN LOS PESADOS!"
	if _alarm_caption.text != caption:
		_alarm_caption.text = caption


func _update_alarm_fx() -> void:
	if not _alarm_box.visible:
		return
	var urgent := _alarm_left < 15.0
	var p := 0.5 + 0.5 * sin(_age * (11.0 if urgent else 5.0))
	_alarm_title.modulate.a = 0.5 + 0.5 * p
	if urgent:
		_alarm_time.modulate = Color(1.0, 0.45 + 0.55 * p, 0.45 + 0.55 * p)
	else:
		_alarm_time.modulate = Color.WHITE


func _update_timer() -> void:
	if _in_tutorial or GameManager.current_index < 0:
		_timer_label.visible = false
		return
	_timer_label.visible = true
	var secs := int(Global.level_time)
	if secs == _timer_shown:
		return
	_timer_shown = secs
	var par := float(GameManager.level_data(GameManager.current_index).get("par_time", 0.0))
	var text := "TIEMPO " + _clock(Global.level_time)
	if par > 0.0:
		text += "  ·  PAR " + _clock(par)
	_timer_label.text = text
	var over := par > 0.0 and Global.level_time > par
	_timer_label.add_theme_color_override("font_color", UIStyle.LIFE if over else UIStyle.TEXT_DIM)


func _on_flashlight_changed(_on: bool) -> void:
	if not _in_tutorial:
		_flash_known = true
	_flash_refresh = 0.0


func _update_flashlight(delta: float) -> void:
	_flash_refresh -= delta
	if not _flash_known and not _in_tutorial and (Global.lights_out or Global.flashlight_on):
		_flash_known = true
		_flash_refresh = 0.0
	if not _flash_known and not _in_tutorial and _flash_refresh <= 0.0:
		_flash_refresh = 0.5
		var lighting := get_tree().get_first_node_in_group("level_lighting")
		if lighting != null and lighting.has_method("has_flashlight") and lighting.has_flashlight():
			_flash_known = true
			_flash_refresh = 0.0
	_flash_box.visible = _flash_known
	if not _flash_known or _flash_refresh > 0.0:
		return
	_flash_refresh = 0.2
	var on := Global.flashlight_on
	_flash_label.text = "LINTERNA [%s] · %s" % [Settings.key_name("flashlight"), "ENCENDIDA" if on else "APAGADA"]
	_flash_label.add_theme_color_override("font_color", UIStyle.OBJECTIVE if on else UIStyle.TEXT_DIM)
	var state_text := ""
	var state_color := UIStyle.BAR_FILL
	if Global.lights_out:
		var player := get_tree().get_first_node_in_group("player")
		var vis: Variant = player.get("light_visibility") if player != null else null
		if vis != null:
			if float(vis) < 0.99:
				state_text = "EN LA OSCURIDAD"
			else:
				state_text = "VISIBLE"
				state_color = UIStyle.OBJECTIVE
	_flash_state.text = state_text
	_flash_state.add_theme_color_override("font_color", state_color)


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


func _on_health_changed(new_health: float) -> void:
	_health_bar.value = new_health / Global.max_health * 100.0
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

	var tint := UIStyle.TEXT
	if multiplier >= 10:
		tint = UIStyle.LIFE
	elif multiplier >= 5:
		tint = UIStyle.OBJECTIVE
	elif multiplier >= 2:
		tint = UIStyle.BAR_FILL
	_combo_mult.add_theme_color_override("font_color", tint)

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
	if get_tree().paused:
		_objective_big_pending = true
		_objective_big.modulate.a = 0.0
		return
	_show_objective_big()


func _show_objective_big() -> void:
	_objective_big_pending = false
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
		_hearts.set_lives(0)
		_game_over_prompt.text = "¡SIN VIDAS!\nPierdes tu puntaje y empiezas desde el NIVEL 1.\nPresiona [R] para reiniciar"
		if retry != null:
			retry.text = "VOLVER AL NIVEL 1  [R]"


func _on_player_respawned() -> void:
	_game_over.visible = false
	_apply_mouse_mode()


func _update_stealth() -> void:
	var highest := 0.0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.has_method("is_alive") and e.is_alive():
			var aw := float(e.get("awareness"))
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


func _apply_mouse_mode() -> void:
	if _game_over.visible or get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN) and is_node_ready():
		_apply_mouse_mode()


func _input(event: InputEvent) -> void:
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
		Global.reset_game()
