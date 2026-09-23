extends Node

var _plan: Array = []
var _cur: Dictionary = {}
var _frames: int = 0
var _fails: Array = []
var _messages: Array = []
var _radio: Array = []
var _orig_diff: int = 1
var _marker_pos: Vector2 = Vector2.INF


func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	_orig_diff = Settings.difficulty
	Global.message.connect(func(t: String) -> void: _messages.append(t))
	Global.radio_message.connect(func(s: String, t: String) -> void: _radio.append(s + ": " + t))
	_plan = [
		{"kind": "variants", "level": 2, "diff": 0},
		{"kind": "variants", "level": 2, "diff": 2},
		{"kind": "variants", "level": 1, "diff": 1},
		{"kind": "note", "level": 0, "diff": 1},
		{"kind": "hunt", "level": 1, "diff": 1},
		{"kind": "marker", "level": 2, "diff": 1},
	]
	_next()


func _check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		_fails.append(what)


func _next() -> void:
	if _plan.is_empty():
		Settings.difficulty = _orig_diff
		print("TEST2_DONE fails=", _fails.size(), " ", _fails)
		get_tree().quit()
		return
	_cur = _plan.pop_front()
	_frames = 0
	Settings.difficulty = int(_cur["diff"])
	print("CASE ", _cur)
	GameManager.start_level(int(_cur["level"]), Global.START_RETRY)


func _level() -> Node:
	return get_tree().get_first_node_in_group("level")


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _process(_d: float) -> void:
	if _cur.is_empty():
		return
	_frames += 1
	var lv := _level()
	match String(_cur["kind"]):
		"variants":
			if _frames == 20:
				var counts := {}
				for e in get_tree().get_nodes_in_group("Enemies"):
					if e.has_method("variant_key"):
						var k: String = e.variant_key()
						counts[k] = int(counts.get(k, 0)) + 1
				var want: Dictionary = GameManager.level_data(int(_cur["level"])).get("variants", {})
				print("  counts=", counts, " want=", want)
				var ok := true
				var total := 0
				for k in counts:
					total += int(counts[k])
				for k in want:
					if int(counts.get(k, 0)) > int(want[k]):
						ok = false
				var placed := total - int(counts.get("soldado", 0))
				var wanted := 0
				for k in want:
					wanted += int(want[k])
				_check(ok and placed == mini(wanted, total), "variant quota respected")
				_check(Global.level_active, "level active without briefing on retry")
				_check(Global.lights_out == (GameManager.level_data(int(_cur["level"])).get("twist", "") == "apagon"), "lights_out matches twist")
				_next()
		"note":
			if _frames == 20:
				Global.invuln_time = 99999.0
				for e in get_tree().get_nodes_in_group("Enemies"):
					if e.is_alive():
						e.die()
			if _frames == 40:
				var notes := get_tree().get_nodes_in_group("notes")
				_check(notes.size() == 1, "level 1 drops one note")
				if notes.size() == 1:
					_check(String(notes[0].get("note_title")) == "ORDEN CONFIDENCIAL", "note title chapter 1")
					_check(lv.is_walkable(notes[0].global_position), "note on walkable spot")
				_check(Global.objective == "RECOGE LA LLAVE Y LEE LA NOTA", "objective note")
				var clear_radio := false
				for l in _radio:
					if String(l).contains("Llevaba una nota"):
						clear_radio = true
				_check(clear_radio, "radio_clear sent")
				_next()
		"hunt":
			if _frames == 20:
				_messages.clear()
				Global.invuln_time = 99999.0
				_player().global_position += Vector2(4, 0)
				lv.set("twist", "caceria")
				lv.set("_hunt_timer", 0.05)
			if _frames == 30:
				_check(_messages.has("¡TE LOCALIZARON!"), "caceria pulse message")
				var alerted := 0
				var alive := 0
				for e in get_tree().get_nodes_in_group("Enemies"):
					if e.is_alive():
						alive += 1
						if int(e.get("state")) != 0:
							alerted += 1
				print("  alerted ", alerted, "/", alive)
				_check(alerted == alive and alive > 0, "all enemies alerted")
				_check(float(lv.get("_hunt_timer")) > 20.0, "hunt timer rearmed")
				_next()
		"marker":
			if _frames == 20:
				Global.invuln_time = 99999.0
				var m := Node2D.new()
				m.add_to_group("boss_spawn")
				lv.add_child(m)
				_marker_pos = lv.random_walkable_point(_player().global_position, 60.0)
				m.global_position = _marker_pos
				for e in get_tree().get_nodes_in_group("Enemies"):
					if e.is_alive():
						e.die()
			if _frames == 40:
				Global.collect_key()
				for d in get_tree().get_nodes_in_group("doors"):
					d.open()
			if _frames == 70:
				var boss = Global.boss_node
				if ResourceLoader.exists("res://Scenes/Boss.tscn"):
					_check(boss != null and is_instance_valid(boss), "boss spawned")
					if boss != null and is_instance_valid(boss):
						var d: float = boss.global_position.distance_to(_marker_pos)
						print("  boss dist to marker=", d)
						_check(d < 30.0, "boss spawned at boss_spawn marker")
						_check(not Global.alarm_active, "alarm off with boss")
				_next()
