extends Node

const BossScene := preload("res://Scenes/Boss.tscn")
const EnemyScene := preload("res://Scenes/Enemy.tscn")

var _step: int = 0
var _frames: int = 0
var _boss: Node = null
var _level: Node = null
var _player: Node2D = null
var _fails: int = 0
var _spawned_sig: int = 0
var _health_sig: int = 0
var _defeated_sig: int = 0
var _radio_count: int = 0
var _phases_seen: Dictionary = {}
var _actions_seen: Dictionary = {}
var _enemies_before: int = 0
var _death_msec: int = 0
var _slow_seen: bool = false
var _hp_start: float = 0.0
var _damage_taken: float = 0.0
var _last_hp: float = 0.0
var _max_boss_dist: float = 0.0
var _stuck_frames: int = 0
var _last_boss_pos: Vector2 = Vector2.ZERO
var _prev_action: int = 0
var _log_actions: Array[String] = []
var _boss_only: bool = false
var _move: bool = false
var _move_dir: int = 0
var _phase_dmg: Array[float] = []


func _sim_player() -> void:
	if not _move or _step < 2 or _step > 5:
		return
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if _frames % 36 == 0:
		_move_dir = randi() % 4
	Input.action_press(["move_left", "move_right", "move_up", "move_down"][_move_dir])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	Global.boss_spawned.connect(_on_spawned)
	Global.boss_health_changed.connect(_on_health)
	Global.boss_defeated.connect(_on_defeated)
	Global.radio_message.connect(_on_radio)
	var args := OS.get_cmdline_user_args()
	_boss_only = args.has("bossonly")
	_move = args.has("move")
	print("MODE boss_only=", _boss_only, " move=", _move)
	GameManager.start_level(2, Global.START_RETRY)
	_step = 1
	_frames = 0


func _on_spawned(_b: Node) -> void:
	_spawned_sig += 1


func _on_health(_c: float, _m: float, p: int) -> void:
	_health_sig += 1
	_phases_seen[p] = true


func _on_defeated() -> void:
	_defeated_sig += 1


func _on_radio(_s: String, _t: String) -> void:
	_radio_count += 1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		print("  FAIL ", label)
		_fails += 1


func _physics_process(_d: float) -> void:
	_frames += 1
	_sim_player()
	if _boss != null and is_instance_valid(_boss):
		_actions_seen[int(_boss.get("_action"))] = true
		if _player != null:
			_max_boss_dist = maxf(_max_boss_dist, _boss.global_position.distance_to(_player.global_position))
		if Global.health < _last_hp:
			_damage_taken += _last_hp - Global.health
		_last_hp = Global.health
		var act := int(_boss.get("_action"))
		if act != _prev_action:
			if act != 0 and _player != null:
				_log_actions.append("%d@%d" % [act, int(_boss.global_position.distance_to(_player.global_position))])
			_prev_action = act
		if _boss_only:
			for e in get_tree().get_nodes_in_group("Enemies"):
				if not e.is_in_group("boss") and e.has_method("is_alive") and e.is_alive() and _step >= 3 and _step <= 5 and _frames > 100:
					e.die()
	match _step:
		1:
			var cs := get_tree().current_scene
			if _frames > 20 and cs != null and cs.name == "Level3":
				_step = 0
				await _setup()
				_step = 2
				_frames = 0
		2:
			if _frames == 20:
				var hp := float(_boss.get("health"))
				_boss.take_damage(200.0)
				_check(is_equal_approx(float(_boss.get("health")), hp), "boss invulnerable during intro")
				_check(Global.boss_alive and Global.boss_node == _boss, "Global.boss_alive/boss_node set")
				_check(_spawned_sig == 1, "boss_spawned emitted once")
				_check(_health_sig >= 1, "boss_health_changed emitted on spawn")
			if _frames == 170:
				_check(int(_boss.get("_mode")) == 1, "boss in FIGHT after intro")
				_step = 3
				_frames = 0
		3:
			if _frames == 420:
				print("  actions phase0: ", _actions_seen.keys(), " dmg_taken=", _damage_taken, " log=", _log_actions)
				_log_actions.clear()
				_check(_actions_seen.has(1), "phase0 used BURST")
				_check(_damage_taken > 0.0, "boss bullets hit the player")
				_enemies_before = _count_alive()
				var target := float(_boss.get("max_health")) * 0.5
				_boss.take_damage(float(_boss.get("health")) - target)
				_check(int(_boss.get("phase")) == 1, "phase 1 reached")
				_check(is_equal_approx(float(_boss.get("health")), float(_boss.get("max_health")) * 0.66), "health clamped at 66%")
				_check(bool(_boss.is_invulnerable()), "invulnerable in transition")
				_actions_seen.clear()
				_step = 4
				_frames = 0
		4:
			if _frames == 90:
				print("  alive before=", _enemies_before, " after=", _count_alive())
				_check(_count_alive() >= _enemies_before + 1, "minions summoned in phase 1")
			if _frames == 400:
				Global.health = 0.0
			if _frames == 470:
				_check(int(_boss.get("_mode")) == 3, "boss dormant while player dead")
				Global.health = 100000.0
				_last_hp = Global.health
				Global.grace_time = 0.0
			if _frames == 600:
				_check(int(_boss.get("_mode")) == 1, "boss wakes up after respawn (mode=%d)" % int(_boss.get("_mode")))
			if _frames == 720:
				print("  actions phase1: ", _actions_seen.keys(), " dmg_taken=", _damage_taken, " log=", _log_actions)
				_log_actions.clear()
				_check(_actions_seen.size() >= 2, "phase1 attacked")
				_enemies_before = _count_alive()
				_boss.take_damage(float(_boss.get("max_health")))
				_check(int(_boss.get("phase")) == 2, "phase 2 reached")
				_check(is_equal_approx(float(_boss.get("health")), float(_boss.get("max_health")) * 0.33), "health clamped at 33%")
				_actions_seen.clear()
				_step = 5
				_frames = 0
		5:
			if _frames == 90:
				print("  alive before=", _enemies_before, " after=", _count_alive())
				_check(_count_alive() >= _enemies_before + 1, "minions summoned in phase 2")
			if _frames == 780:
				print("  actions phase2: ", _actions_seen.keys(), " dmg_taken=", _damage_taken, " max_dist=", _max_boss_dist, " log=", _log_actions)
				_check(_actions_seen.has(3), "phase2 used RING")
				_check(_phases_seen.has(0) and _phases_seen.has(1) and _phases_seen.has(2), "health signal reported phases 0,1,2")
				var hits := 0
				while _boss.is_alive() and hits < 400:
					_boss.apply_bullet_hit(22.0, Vector2.RIGHT)
					hits += 1
				print("  hits to kill phase2: ", hits)
				_check(not _boss.is_alive(), "boss died")
				_check(_defeated_sig == 1, "boss_defeated emitted once")
				_check(not Global.boss_alive, "Global.boss_alive false")
				_check(is_equal_approx(Engine.time_scale, 0.35), "slow motion active")
				_death_msec = Time.get_ticks_msec()
				_step = 6
				_frames = 0
		6:
			if Engine.time_scale < 1.0:
				_slow_seen = true
			if Time.get_ticks_msec() - _death_msec > 2000:
				_check(is_equal_approx(Engine.time_scale, 1.0), "time_scale back to 1.0")
				_check(_radio_count >= 5, "radio lines sent (%d)" % _radio_count)
				_check(Global.score > 0, "score added (%d)" % Global.score)
				_boss.take_damage(50.0)
				_boss.die()
				_check(_defeated_sig == 1, "no double defeat")
				_step = 7
				_frames = 0
		7:
			if _frames == 30:
				_variant_checks()
			if _frames == 200:
				_variant_followup()
				print("BOSS_TEST_DONE fails=", _fails)
				get_tree().quit()


func _count_alive() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.is_in_group("boss"):
			continue
		if e.has_method("is_alive") and e.is_alive():
			n += 1
	return n


func _setup() -> void:
	_level = get_tree().get_first_node_in_group("level")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.has_method("die") and e.is_alive():
			e.die()
	Global.max_health = 100000.0
	Global.health = 100000.0
	Global.invuln_time = 0.0
	_last_hp = Global.health
	if OS.get_cmdline_user_args().has("levelspawn"):
		Global.collect_key()
		for dnode in get_tree().get_nodes_in_group("doors"):
			if dnode.has_method("open"):
				dnode.open()
		for i in range(10):
			await get_tree().physics_frame
		_boss = Global.boss_node
		print("  level spawned boss=", _boss, " at ", _boss.global_position if _boss != null else Vector2.ZERO, " player=", _player.global_position)
		if _boss == null:
			print("  FAIL level did not spawn boss")
			get_tree().quit()
			return
		_player.global_position = _find_spot(_boss.global_position)
		_player.set("start_position", _player.global_position)
	else:
		var spot := _find_spot(_player.global_position)
		print("  player=", _player.global_position, " boss spot=", spot)
		_boss = BossScene.instantiate()
		_boss.position = spot
		var holder := _level.get_node_or_null("Enemies")
		if holder == null:
			holder = _level
		holder.add_child(_boss)
	_hp_start = float(_boss.get("max_health"))
	_last_boss_pos = _boss.global_position
	print("  boss max_health=", _hp_start)


func _find_spot(origin: Vector2) -> Vector2:
	var space := _player.get_world_2d().direct_space_state
	for r in [120.0, 100.0, 150.0, 80.0, 180.0]:
		for i in range(24):
			var c: Vector2 = origin + Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * r
			if _level.has_method("is_walkable") and not _level.is_walkable(c):
				continue
			var q := PhysicsRayQueryParameters2D.create(origin, c, 1)
			if space.intersect_ray(q).is_empty():
				return c
	return origin + Vector2(60, 0)


var _test_enemies: Array = []


func _variant_checks() -> void:
	print("VARIANTS")
	var base := EnemyScene.instantiate()
	base.set("behavior", 0)
	_level.add_child(base)
	base.global_position = _player.global_position + Vector2(-400, -400)
	var base_hp := float(base.get("max_health"))
	var base_speed := float(base.get("speed"))
	var info := {}
	for p in base.get_property_list():
		if String(p["name"]) == "variant":
			info = p
	print("  variant property: type=", info.get("type"), " hint=", info.get("hint"), " hint_string=", info.get("hint_string"))
	_check(int(info.get("type", -1)) == TYPE_INT and int(info.get("hint", -1)) == PROPERTY_HINT_ENUM, "variant exported as int enum")
	_check(String(base.variant_key()) == "soldado", "default variant soldado")
	_test_enemies.append(base)
	var keys := ["", "pesado", "tirador", "rapido"]
	for v in [1, 2, 3]:
		var e := EnemyScene.instantiate()
		e.set("behavior", 0)
		_level.add_child(e)
		e.global_position = _player.global_position + Vector2(-400 + 30 * v, -400)
		e.apply_variant(v)
		e.apply_variant(1 if v != 1 else 2)
		_check(String(e.variant_key()) == keys[v], "variant_key %s" % keys[v])
		_check(is_equal_approx(float(e.get("health")), float(e.get("max_health"))), "health reset %s" % keys[v])
		_test_enemies.append(e)
		match v:
			1:
				_check(is_equal_approx(float(e.get("max_health")), base_hp * 2.4), "pesado hp x2.4")
				_check(int(e.get("pellets")) == 4, "pesado 4 pellets")
				_check(not bool(e.get("can_flee")), "pesado no flee")
			2:
				var laser := e.get_node_or_null("Laser") as Line2D
				_check(laser != null and laser.light_mask == 0, "tirador laser light_mask 0")
				_check(bool(e.get("stop_to_shoot")), "tirador stop_to_shoot")
			3:
				_check(is_equal_approx(float(e.get("speed")), base_speed * 1.55), "rapido speed x1.55")
				_check(is_equal_approx(float(e.get("max_health")), base_hp * 0.6), "rapido hp x0.6")
	var pre := EnemyScene.instantiate()
	pre.set("behavior", 0)
	pre.set("variant", 2)
	_level.add_child(pre)
	pre.global_position = _player.global_position + Vector2(-300, -400)
	_check(String(pre.variant_key()) == "tirador" and pre.get_node_or_null("Laser") != null, "inspector variant applied in _ready")
	_test_enemies.append(pre)
	var icon_ok := true
	for c in base.get_children():
		if c is CanvasItem and c.get_class() == "Node2D" and c.top_level:
			icon_ok = icon_ok and (c as CanvasItem).light_mask == 0
	_check(icon_ok, "awareness icon light_mask 0")
	base.alert_to(_player.global_position)
	_check(int(base.get("state")) == 4, "alert_to -> INVESTIGAR")
	var lv = _player.get("light_visibility")
	print("  player light_visibility=", lv)
	var before := Global.times_detected
	Global.level_active = true
	var shooter: Node = _test_enemies[3]
	shooter.set("_target", _player)
	shooter._enter_attack()
	print("  times_detected before=", before, " after=", Global.times_detected)
	var sk := Global.stealth_kills
	var victim: Node = _test_enemies[1]
	victim.set("state", 0)
	victim.global_rotation = 0.0
	victim.melee_hit(45.0, victim.global_position + Vector2(-20, 0))
	_check(not victim.is_alive() and Global.stealth_kills == sk + 1, "stealth kill registered")


func _variant_followup() -> void:
	var tir: Node = _test_enemies[2]
	var laser := tir.get_node_or_null("Laser") as Line2D
	_check(laser != null and laser.points.size() == 2 and laser.visible, "laser updating")
	_check(tir.z_index == 0, "enemy z_index")
