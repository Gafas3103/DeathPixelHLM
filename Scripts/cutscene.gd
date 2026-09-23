extends CanvasLayer

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const StoryScreen := preload("res://Scripts/UI/story_screen.gd")
const Story := preload("res://Scripts/story.gd")

signal finished
signal _tick

const BAR_HEIGHT := 96.0
const TYPE_SPEED := 46.0


class Marker extends Node2D:
	var target: Node2D = null
	var text: String = ""
	var color: Color = Color("#EF3E4A")
	var _t: float = 0.0

	func _init() -> void:
		top_level = true
		z_index = 150
		light_mask = 0

	func _process(delta: float) -> void:
		_t += delta
		if target == null or not is_instance_valid(target):
			queue_free()
			return
		global_position = target.global_position
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / 0.25, 0.0, 1.0)
		var r := lerpf(28.0, 15.0, k)
		var col := Color(color, k)
		var arm := 6.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var c := Vector2(sx * r, sy * r)
				draw_line(c, c - Vector2(sx * arm, 0.0), col, 1.5)
				draw_line(c, c - Vector2(0.0, sy * arm), col, 1.5)
		if k < 1.0 or text == "":
			return
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var blink := 0.75 + 0.25 * sin(_t * 9.0)
		draw_rect(Rect2(Vector2(-w * 0.5 - 4.0, -r - 16.0), Vector2(w + 8.0, 12.0)), Color(0.0, 0.0, 0.0, 0.8))
		draw_rect(Rect2(Vector2(-w * 0.5 - 4.0, -r - 16.0), Vector2(2.0, 12.0)), Color(color, blink))
		draw_string(font, Vector2(-w * 0.5, -r - 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(color, blink))


var skipped: bool = false
var world: Node2D = null

var _dt: float = 0.0
var _advance: bool = false
var _ended: bool = false
var _input_delay: float = 0.35

var _cam: Camera2D = null
var _prev_cam: Camera2D = null
var _cam_from: Vector2 = Vector2.ZERO
var _cam_to: Vector2 = Vector2.ZERO
var _zoom_from: float = 2.0
var _zoom_to: float = 2.0
var _cam_time: float = 0.0
var _cam_len: float = 0.0
var _cam_moving: bool = false
var _follow: Node2D = null
var _shake: float = 0.0
var _markers: Array[Node] = []

var _root: Control
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _fade: ColorRect
var _flash: ColorRect
var _location: Label
var _dialog: VBoxContainer
var _speaker: Label
var _line: Label
var _hint: Label
var _flash_tween: Tween = null


func _ready() -> void:
	layer = 38
	_build()


func _exit_tree() -> void:
	if not _ended:
		_ended = true
		Global.set_cutscene(false)
	if _cam != null and is_instance_valid(_cam) and not _cam.is_queued_for_deletion():
		_cam.queue_free()


func _process(delta: float) -> void:
	_dt = minf(delta / maxf(Engine.time_scale, 0.05), 0.1)
	_input_delay = maxf(0.0, _input_delay - _dt)
	_update_camera()
	_tick.emit()


func _input(event: InputEvent) -> void:
	if _ended or GameManager.trailer_mode:
		return
	if StoryScreen.is_cancel(event):
		skipped = true
		get_viewport().set_input_as_handled()
	elif StoryScreen.is_press(event):
		if _input_delay <= 0.0:
			_advance = true
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)

	var vig := StoryScreen.vignette(0.55)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vig)

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	_top_bar = _make_bar(true)
	_bottom_bar = _make_bar(false)

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_location = StoryScreen.spaced_label("", 15, UIStyle.TEXT_DIM, 6, true)
	_location.position = Vector2(48, 34)
	_location.size = Vector2(900, 28)
	_location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_location)

	_hint = StoryScreen.spaced_label("[ESC] SALTAR  ·  [CLIC] CONTINUAR", 12, Color(UIStyle.TEXT_DIM, 0.8), 3)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -420
	_hint.offset_right = -40
	_hint.offset_top = 38
	_hint.offset_bottom = 60
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = not GameManager.trailer_mode
	_hint.modulate.a = 0.0
	_root.add_child(_hint)

	_dialog = VBoxContainer.new()
	_dialog.anchor_top = 1.0
	_dialog.anchor_bottom = 1.0
	_dialog.anchor_right = 1.0
	_dialog.offset_left = 180
	_dialog.offset_right = -180
	_dialog.offset_top = -BAR_HEIGHT + 10
	_dialog.offset_bottom = -6
	_dialog.add_theme_constant_override("separation", 0)
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog.modulate.a = 0.0
	_root.add_child(_dialog)

	_speaker = StoryScreen.spaced_label("", 15, UIStyle.AMMO, 5, true)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.add_child(_speaker)

	_line = UIStyle.label("", 21, UIStyle.TEXT, false)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_constant_override("line_spacing", -2)
	_dialog.add_child(_line)


func _make_bar(top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.anchor_right = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Color(UIStyle.LIFE, 0.55)
	line.anchor_right = 1.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		bar.offset_bottom = 0.0
		line.anchor_top = 1.0
		line.anchor_bottom = 1.0
		line.offset_top = -2.0
	else:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = 0.0
		line.offset_bottom = 2.0
	bar.add_child(line)
	_root.add_child(bar)
	return bar


func _set_bars(k: float) -> void:
	_top_bar.offset_bottom = BAR_HEIGHT * k
	_bottom_bar.offset_top = -BAR_HEIGHT * k
	_hint.modulate.a = k


func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


func _run(duration: float, step: Callable, force: bool = false) -> void:
	var t := 0.0
	while t < duration and (force or not skipped) and is_inside_tree():
		await _tick
		t += _dt
		step.call(clampf(t / maxf(duration, 0.001), 0.0, 1.0))
	step.call(1.0)


func _update_camera() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var follow_ok := _follow != null and is_instance_valid(_follow)
	if _cam_moving:
		_cam_time += _dt
		var k := clampf(_cam_time / maxf(_cam_len, 0.001), 0.0, 1.0)
		var e := _ease(k)
		var goal := _follow.global_position if follow_ok else _cam_to
		_cam.global_position = _cam_from.lerp(goal, e)
		_cam.zoom = Vector2.ONE * lerpf(_zoom_from, _zoom_to, e)
		if k >= 1.0:
			_cam_moving = false
	elif follow_ok:
		_cam.global_position = _cam.global_position.lerp(_follow.global_position, clampf(_dt * 7.0, 0.0, 1.0))
	_shake = move_toward(_shake, 0.0, _dt * 16.0)
	_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake


func begin(world_node: Node2D) -> void:
	world = world_node
	Global.set_cutscene(true)
	_prev_cam = get_viewport().get_camera_2d()
	_cam = Camera2D.new()
	_cam.name = "CutsceneCamera"
	var start := Vector2.ZERO
	var z := 2.0
	if _prev_cam != null:
		start = _prev_cam.get_screen_center_position()
		z = _prev_cam.zoom.x
		_cam.limit_left = _prev_cam.limit_left
		_cam.limit_top = _prev_cam.limit_top
		_cam.limit_right = _prev_cam.limit_right
		_cam.limit_bottom = _prev_cam.limit_bottom
	elif world != null:
		start = world.global_position
	_zoom_from = z
	_zoom_to = z
	_cam.zoom = Vector2(z, z)
	world.add_child(_cam)
	_cam.global_position = start
	_cam.make_current()
	_run(0.45, _set_bars, true)


func cam_jump(point: Vector2, zoom: float) -> void:
	_cam_moving = false
	_follow = null
	if _cam != null:
		_cam.global_position = point
		_cam.zoom = Vector2(zoom, zoom)


func cam_move(point: Vector2, zoom: float, time: float) -> void:
	if _cam == null:
		return
	_follow = null
	_cam_from = _cam.global_position
	_cam_to = point
	_zoom_from = _cam.zoom.x
	_zoom_to = zoom
	_cam_time = 0.0
	_cam_len = time
	_cam_moving = true
	if skipped:
		_cam_moving = false
		_cam.global_position = point
		_cam.zoom = Vector2(zoom, zoom)


func cam_follow(node: Node2D, zoom: float = -1.0, time: float = 0.8) -> void:
	if _cam == null or node == null:
		return
	cam_move(node.global_position, zoom if zoom > 0.0 else _cam.zoom.x, time)
	_follow = node


func cam_wait() -> void:
	while _cam_moving and not skipped and is_inside_tree():
		await _tick


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func wait(time: float) -> void:
	var t := 0.0
	while t < time and not skipped and is_inside_tree():
		await _tick
		t += _dt


func fade_now(alpha: float) -> void:
	_fade.color.a = alpha


func fade(alpha: float, time: float) -> void:
	var a0 := _fade.color.a
	await _run(time, func(k: float) -> void: _fade.color.a = lerpf(a0, alpha, k))


func flash(color: Color, time: float = 0.5) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color = Color(color, 0.75)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, time)


func location(text: String) -> void:
	_location.text = text
	_location.visible_characters = 0
	var total := text.length()
	_run(0.9, func(k: float) -> void: _location.visible_characters = int(round(k * total)))


func mark(node: Node2D, text: String, color: Color) -> void:
	if node == null or world == null or not is_instance_valid(node):
		return
	var m := Marker.new()
	m.target = node
	m.text = text
	m.color = color
	world.add_child(m)
	m.global_position = node.global_position
	_markers.append(m)


func face(actor: Node2D, point: Vector2) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if "puppet_aim" in actor:
		actor.set("puppet_aim", point)
	elif actor.global_position.distance_to(point) > 1.0:
		actor.look_at(point)


func walk(actor: Node2D, to: Vector2, speed: float = 70.0) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var prop := ""
	if "puppet_velocity" in actor:
		prop = "puppet_velocity"
	elif "cutscene_velocity" in actor:
		prop = "cutscene_velocity"
	var limit := actor.global_position.distance_to(to) / maxf(speed, 1.0) + 1.2
	var t := 0.0
	while not skipped and is_inside_tree() and is_instance_valid(actor) and actor.global_position.distance_to(to) > 3.0 and t < limit:
		var dir := (to - actor.global_position).normalized()
		if prop != "":
			actor.set(prop, dir * speed)
		else:
			actor.global_position += dir * speed * _dt
		if "puppet_aim" in actor:
			actor.set("puppet_aim", actor.global_position + dir * 80.0)
		await _tick
		t += _dt
	if not is_instance_valid(actor):
		return
	if prop != "":
		actor.set(prop, Vector2.ZERO)
	if skipped:
		actor.global_position = to


func say(speaker: String, text: String, hold: float = -1.0) -> void:
	if skipped or not is_inside_tree():
		return
	_speaker.text = speaker
	_speaker.add_theme_color_override("font_color", Story.speaker_color(speaker))
	_line.text = text
	_line.visible_characters = 0
	if _dialog.modulate.a < 1.0:
		var a0 := _dialog.modulate.a
		_run(0.2, func(k: float) -> void: _dialog.modulate.a = lerpf(a0, 1.0, k))
	_advance = false
	var total := text.length()
	var shown := 0.0
	while shown < total and not skipped and not _advance and is_inside_tree():
		await _tick
		shown += _dt * TYPE_SPEED
		_line.visible_characters = int(shown)
	_line.visible_characters = -1
	_advance = false
	var hold_time := hold if hold >= 0.0 else 1.0 + float(total) * 0.032
	var t := 0.0
	while t < hold_time and not skipped and not _advance and is_inside_tree():
		await _tick
		t += _dt
	_advance = false


func say_line(line: Variant, hold: float = -1.0) -> void:
	if line is Array and line.size() >= 2:
		await say(String(line[0]), String(line[1]), hold)


func hide_dialog() -> void:
	var a0 := _dialog.modulate.a
	if a0 <= 0.0:
		return
	_run(0.2, func(k: float) -> void: _dialog.modulate.a = lerpf(a0, 0.0, k), true)


func title_card(top: String, big: String, sub: String, slogan: String, hold: float = 2.0) -> void:
	if skipped or not is_inside_tree():
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_root.move_child(center, _dialog.get_index())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var l_top := StoryScreen.spaced_label(top, 17, UIStyle.TEXT_DIM, 9, true)
	l_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l_top)

	var l_big := UIStyle.label(big, 84, UIStyle.OBJECTIVE, true)
	l_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_big.add_theme_color_override("font_outline_color", UIStyle.LIFE.darkened(0.55))
	l_big.add_theme_constant_override("outline_size", 12)
	box.add_child(l_big)

	var l_sub := StoryScreen.spaced_label(sub, 40, UIStyle.TEXT, 14, true)
	l_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l_sub.add_theme_constant_override("outline_size", 8)
	box.add_child(l_sub)

	var rule := ColorRect.new()
	rule.color = UIStyle.LIFE
	rule.custom_minimum_size = Vector2(0, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)

	var l_slogan := StoryScreen.spaced_label(slogan, 17, UIStyle.LIFE, 5, true)
	l_slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_slogan.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l_slogan.add_theme_constant_override("outline_size", 6)
	box.add_child(l_slogan)

	box.modulate.a = 0.0
	flash(Color(1.0, 0.95, 0.85), 0.35)
	shake(4.0)
	var reveal := func(k: float) -> void:
		box.modulate.a = minf(1.0, k * 2.2)
		center.position = Vector2(randf_range(-10.0, 10.0), randf_range(-3.0, 3.0)) * (1.0 - k)
		l_big.add_theme_color_override("font_color", UIStyle.LIFE if (k < 0.8 and randf() < 0.35) else UIStyle.OBJECTIVE)
		rule.custom_minimum_size.x = 460.0 * _ease(k)
	await _run(0.5, reveal)
	await wait(hold)
	var leave := func(k: float) -> void:
		box.modulate.a = 1.0 - k
		center.position.y = -18.0 * k
	await _run(0.4, leave, true)
	center.queue_free()


func boss_card(boss_name: String, title: String, hold: float = 2.2) -> void:
	if skipped or not is_inside_tree():
		return
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	_root.move_child(holder, _dialog.get_index())

	var band := ColorRect.new()
	band.color = Color(0.02, 0.02, 0.04, 0.92)
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = -92
	band.offset_bottom = 92
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(band)

	for edge in [-92.0, 88.0]:
		var stripe := ColorRect.new()
		stripe.color = UIStyle.LIFE
		stripe.anchor_right = 1.0
		stripe.anchor_top = 0.5
		stripe.anchor_bottom = 0.5
		stripe.offset_top = edge
		stripe.offset_bottom = edge + 4.0
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(stripe)

	var pixels: Array[ColorRect] = []
	for i in range(14):
		var px := ColorRect.new()
		px.color = UIStyle.LIFE
		px.size = Vector2(8, 8)
		px.position = Vector2(80.0 + float(i) * 83.0 + float(i % 3) * 17.0, 360.0 + (-78.0 if i % 2 == 0 else 66.0))
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(px)
		pixels.append(px)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.anchor_right = 1.0
	box.offset_top = -86
	box.offset_bottom = 86
	box.offset_left = 150
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)

	var l_small := StoryScreen.spaced_label("JEFE FINAL", 18, UIStyle.LIFE, 10, true)
	box.add_child(l_small)
	var l_name := UIStyle.label(boss_name, 92, UIStyle.TEXT, true)
	l_name.add_theme_color_override("font_outline_color", UIStyle.LIFE.darkened(0.6))
	l_name.add_theme_constant_override("outline_size", 12)
	box.add_child(l_name)
	var l_title := StoryScreen.spaced_label("«%s»" % title, 22, UIStyle.OBJECTIVE, 6, true)
	box.add_child(l_title)

	holder.modulate.a = 0.0
	flash(Color(1.0, 0.1, 0.1), 0.5)
	shake(9.0)
	var slide_in := func(k: float) -> void:
		var e := 1.0 - pow(1.0 - k, 3.0)
		holder.modulate.a = minf(1.0, k * 3.0)
		box.offset_left = lerpf(-900.0, 150.0, e)
		box.offset_right = lerpf(-1050.0, 0.0, e)
	await _run(0.45, slide_in)
	var t := 0.0
	while t < hold and not skipped and is_inside_tree():
		await _tick
		t += _dt
		for i in range(pixels.size()):
			pixels[i].visible = fmod(t * 3.0 + float(i) * 0.37, 1.0) > 0.3
	var slide_out := func(k: float) -> void:
		holder.modulate.a = 1.0 - k
		box.offset_left = 150.0 + 500.0 * k * k
	await _run(0.35, slide_out, true)
	holder.queue_free()


func stamp(text: String, color: Color, hold: float = 1.0) -> void:
	if skipped or not is_inside_tree():
		return
	var l := UIStyle.label(text, 90, color, true)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	_root.move_child(l, _dialog.get_index())
	l.pivot_offset = _root.get_rect().size * 0.5
	l.scale = Vector2(2.2, 2.2)
	l.modulate.a = 0.0
	flash(color, 0.3)
	var punch := func(k: float) -> void:
		var e := 1.0 - pow(1.0 - k, 3.0)
		l.scale = Vector2.ONE * lerpf(2.2, 1.0, e)
		l.modulate.a = k
	await _run(0.22, punch)
	shake(8.0)
	await wait(hold)
	var vanish := func(k: float) -> void:
		l.modulate.a = 1.0 - k
		l.scale = Vector2.ONE * (1.0 + 0.08 * k)
	await _run(0.3, vanish, true)
	l.queue_free()


func end() -> void:
	if _ended:
		return
	_ended = true
	_advance = false
	hide_dialog()
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	var a_loc := _location.modulate.a
	_run(0.3, func(k: float) -> void: _location.modulate.a = lerpf(a_loc, 0.0, k), true)
	if _fade.color.a > 0.0:
		var a0 := _fade.color.a
		_run(0.3, func(k: float) -> void: _fade.color.a = lerpf(a0, 0.0, k), true)
	if _prev_cam != null and is_instance_valid(_prev_cam) and _cam != null and is_instance_valid(_cam):
		_follow = null
		_cam_moving = false
		var from := _cam.global_position
		var z0 := _cam.zoom.x
		var cam := _cam
		var target := _prev_cam
		var back := func(k: float) -> void:
			if is_instance_valid(cam) and is_instance_valid(target):
				var e := _ease(k)
				cam.global_position = from.lerp(target.get_screen_center_position(), e)
				cam.zoom = Vector2.ONE * lerpf(z0, target.zoom.x, e)
		await _run(0.45, back, true)
		if is_instance_valid(target):
			target.make_current()
	await _run(0.3, func(k: float) -> void: _set_bars(1.0 - k), true)
	if _cam != null and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	Global.set_cutscene(false)
	finished.emit()
	queue_free()
