extends Node

var _frames: int = 0
var _step: int = 0
var _wait: int = 0
var _level: Node = null
var _radio_log: Array = []
var _messages: Array = []
var _fails: Array = []
var _physics_spawn_pending: bool = false
var _physics_spawned: Node = null
var _boss_seen: bool = false


func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	Global.radio_message.connect(func(s: String, t: String) -> void: _radio_log.append(s + ": " + t))
	Global.message.connect(func(t: String) -> void: _messages.append(t))
	Global.boss_spawned.connect(func(_b: Node) -> void: _boss_seen = true)
	print("TEST start Level3, boss scene exists=", ResourceLoader.exists("res://Scenes/Boss.tscn"))
	GameManager.start_level(2)
	_step = 1
	_wait = 30


func _check(cond: bool, what: String) -> void:
	if cond:
		print("  OK   ", what)
	else:
		print("  FAIL ", what)
		_fails.append(what)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(_d: float) -> void:
	if _physics_spawn_pending and _level != null and is_instance_valid(_level):
		_physics_spawn_pending = false
		var p := _player()
		_physics_spawned = _level.spawn_reinforcement(3, p.global_position if p != null else Vector2.ZERO)
		print("  physics-frame spawn returned ", _physics_spawned, " in_tree=", _physics_spawned.is_inside_tree() if _physics_spawned != null else false)


func _process(_d: float) -> void:
	_frames += 1
	if _wait > 0:
		_wait -= 1
		return
	match _step:
		1:
			_level = get_tree().get_first_node_in_group("level")
			_check(_level != null, "level loaded")
			if _level == null:
				_finish()
				return
			_check(Global.lights_out == false, "lights_out false in noche level")
			var lighting := _level.get_node_or_null("Lighting")
			_check(lighting != null or not ResourceLoader.exists("res://Scripts/lighting.gd"), "lighting node created")
			var variants := {}
			for e in get_tree().get_nodes_in_group("Enemies"):
				if e.has_method("variant_key"):
					var k: String = e.variant_key()
					variants[k] = int(variants.get(k, 0)) + 1
			print("  variants=", variants)
			_check(int(variants.get("rapido", 0)) >= 1 and int(variants.get("tirador", 0)) >= 1 and int(variants.get("pesado", 0)) >= 1, "variants assigned")
			var briefing = _level.get("_briefing")
			print("  briefing open=", _level.get("_briefing_open"), " paused=", get_tree().paused)
			_check(Global.level_active == false, "level inactive while briefing")
			if briefing != null and is_instance_valid(briefing) and briefing.has_method("close"):
				_wait = 70
				_step = 2
			else:
				_step = 3
		2:
			var b = _level.get("_briefing")
			if b != null and is_instance_valid(b):
				b.close()
			_wait = 10
			_step = 3
		3:
			_check(Global.level_active, "level active after briefing")
			_check(not get_tree().paused, "tree unpaused")
			_check(_radio_log.size() >= 2, "radio_start lines sent (%d)" % _radio_log.size())
			Global.invuln_time = 99999.0
			for e in get_tree().get_nodes_in_group("Enemies"):
				if e.has_method("is_alive") and e.is_alive():
					e.die()
			_wait = 20
			_step = 4
		4:
			var keys := get_tree().get_nodes_in_group("key_items")
			var notes := get_tree().get_nodes_in_group("notes")
			_check(keys.size() == 1, "key dropped")
			_check(notes.size() == 1, "story note dropped")
			if notes.size() > 0:
				_check(String(notes[0].get("note_title")) == "EXPEDIENTE 0417", "note has chapter title")
			_check(Global.objective == "RECOGE LA LLAVE Y LEE LA NOTA", "objective with note: " + Global.objective)
			if keys.size() > 0:
				_player().global_position = keys[0].global_position
			_wait = 20
			_step = 5
		5:
			_check(Global.has_key, "key collected by walking over it")
			_check(Global.alarm_active, "alarm active after key")
			_check(Global.objective == "ABRE LA PUERTA", "objective open door: " + Global.objective)
			print("  alarm left=", _level.get("_alarm_left"))
			_wait = 60 * 7
			_step = 6
		6:
			var reinf: Array = _level.get("_reinforcements")
			print("  reinforcements tracked=", reinf.size())
			_check(reinf.size() >= 2, "first wave spawned")
			var ok := true
			for e in reinf:
				if not is_instance_valid(e) or not e.is_inside_tree():
					ok = false
					continue
				var pos: Vector2 = e.global_position
				var walk: bool = _level.is_walkable(pos)
				var d := pos.distance_to(_player().global_position)
				var path: PackedVector2Array = _level.find_path(pos, _player().global_position)
				print("   ", e.name, " at ", pos, " walkable=", walk, " dist=", int(d), " path=", path.size(), " variant=", e.variant_key() if e.has_method("variant_key") else "?", " state=", e.get("state"))
				if not walk or path.is_empty():
					ok = false
			_check(ok, "reinforcements at walkable, reachable points")
			var near_e = _level.spawn_reinforcement(3, _player().global_position)
			_check(near_e != null and near_e.is_inside_tree(), "spawn_reinforcement near works")
			if near_e != null:
				var dn: float = near_e.global_position.distance_to(_player().global_position)
				print("   near spawn dist=", int(dn), " walkable=", _level.is_walkable(near_e.global_position))
				_check(dn >= 20.0 and dn <= 170.0 and _level.is_walkable(near_e.global_position), "near spawn within range")
			var rp: Vector2 = _level.random_walkable_point(_player().global_position, 260.0)
			print("   random_walkable_point=", rp, " walkable=", _level.is_walkable(rp))
			_check(rp.is_finite() and _level.is_walkable(rp), "random_walkable_point walkable")
			_physics_spawn_pending = true
			_level.set("_alarm_left", 0.5)
			_wait = 60 * 2
			_step = 7
		7:
			_check(_physics_spawned != null and is_instance_valid(_physics_spawned) and _physics_spawned.is_inside_tree(), "deferred physics-frame spawn attached")
			_check(bool(_level.get("_alarm_expired")), "alarm expired")
			var expired_radio := false
			for l in _radio_log:
				if String(l).contains("Llegaron los pesados"):
					expired_radio = true
			_check(expired_radio, "ALARM_EXPIRED radio")
			var alive := 0
			for e in _level.get("_reinforcements"):
				if is_instance_valid(e) and e.is_alive():
					alive += 1
			print("  alive reinforcements=", alive)
			_check(alive <= 5, "reinforcement cap respected")
			for d in get_tree().get_nodes_in_group("doors"):
				_player().global_position = d.global_position + Vector2(0, -26)
				d.try_open()
			_wait = 30
			_step = 8
		8:
			var boss_exists := ResourceLoader.exists("res://Scenes/Boss.tscn")
			if boss_exists:
				_check(_boss_seen, "boss_spawned signal")
				_check(Global.boss_alive, "boss alive")
				_check(not Global.alarm_active, "alarm stopped when boss appears")
				_check(Global.objective == "DERROTA AL CONTRATISTA", "boss objective: " + Global.objective)
				var boss = Global.boss_node
				if boss != null and is_instance_valid(boss):
					print("  boss at ", boss.global_position, " walkable=", _level.is_walkable(boss.global_position))
			else:
				_check(not Global.boss_alive, "no boss scene, no boss")
				_check(Global.alarm_active, "alarm continues without boss")
			for ex in get_tree().get_nodes_in_group("exit_zone"):
				_player().global_position = ex.global_position
			_wait = 30
			_step = 9
		9:
			if Global.boss_alive:
				_check(GameManager.get("_victory") == null, "exit locked while boss alive")
				var warned := false
				for m in _messages:
					if String(m).contains("CONTRATISTA"):
						warned = true
				_check(warned, "boss lock message shown")
				_player().global_position += Vector2(0, -60)
				_wait = 60 * 3
				_step = 10
			else:
				_step = 11
		10:
			var boss = Global.boss_node
			if boss != null and is_instance_valid(boss):
				if boss.has_method("take_damage"):
					boss.take_damage(999999.0)
				if Global.boss_alive and boss.has_method("die"):
					boss.die()
			_wait = 60 * 3
			_step = 11
		11:
			if _boss_seen:
				_check(not Global.boss_alive, "boss defeated")
				_check(Global.objective == "LLEGA A LA SALIDA", "objective back to exit: " + Global.objective)
			Engine.time_scale = 1.0
			for ex in get_tree().get_nodes_in_group("exit_zone"):
				_player().global_position = ex.global_position
			_wait = 30
			_step = 12
		12:
			_check(GameManager.get("_victory") != null, "level completed (victory screen)")
			_check(not Global.alarm_active, "alarm off after completion")
			print("  rank=", GameManager.last_rank, " time=", Global.level_time)
			print("  radio log:")
			for l in _radio_log:
				print("    ", l)
			_finish()


func _finish() -> void:
	print("TEST_DONE fails=", _fails.size(), " ", _fails)
	get_tree().quit()
