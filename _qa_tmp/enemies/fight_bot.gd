extends Node

const BALA := preload("res://Scenes/Bala.tscn")

var _step: int = 0
var _frames: int = 0
var _t: float = 0.0
var _level: Node = null
var _player: CharacterBody2D = null
var _boss: Node = null
var _fails: int = 0
var _diff: int = 1
var _acc: float = 4.0
var _uptime: float = 0.7
var _shot_mode: bool = false
var _out: String = ""

var _fight_start: float = -1.0
var _fight_end: float = -1.0
var _phase_start: Array[float] = [-1.0, -1.0, -1.0]
var _dmg_in: float = 0.0
var _dmg_in_phase: Array[float] = [0.0, 0.0, 0.0]
var _last_hp: float = 100.0
var _deaths: int = 0
var _respawns: int = 0
var _dead_since: float = -1.0
var _shots: int = 0
var _boss_dmg: float = 0.0
var _expected: float = 0.0
var _boss_last: float = -1.0
var _minion_kills: int = 0
var _health_sigs: int = 0
var _defeat_sigs: int = 0
var _spawn_sigs: int = 0
var _phases_seen: Dictionary = {}
var _actions: Dictionary = {}
var _starved: int = 0
var _reload_left: float = 0.0
var _burst_left: float = 0.0
var _pause_left: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_t: float = 0.0
var _fire_cd: float = 0.0
var _minions_seen: Dictionary = {}
var _max_minions: int = 0
var _timescale_ok_at: float = -1.0
var _death_real_ms: int = 0
var _slow_ms: int = -1
var _log: Array[String] = []
var _stuck_log: float = 0.0
var _boss_prev_pos: Vector2 = Vector2.ZERO
var _boss_still: float = 0.0
var _boss_max_still: float = 0.0
var _respawn_checked: bool = false
var _hist: Dictionary = {}
var _dodge: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() != 2:
			if a == "shots":
				_shot_mode = true
			continue
		match kv[0]:
			"diff":
				_diff = int(kv[1])
			"acc":
				_acc = float(kv[1])
			"up":
				_uptime = float(kv[1])
			"seed":
				seed(int(kv[1]))
			"dodge":
				_dodge = kv[1] == "1"
	Settings.difficulty = _diff
	if _shot_mode:
		Settings.fullscreen = false
		Settings.apply_display()
	_out = ProjectSettings.globalize_path("res://_qa_tmp/enemies/")
	Global.boss_spawned.connect(func(_b: Node) -> void: _spawn_sigs += 1)
	Global.boss_health_changed.connect(_on_boss_health)
	Global.boss_defeated.connect(func() -> void: _defeat_sigs += 1)
	Global.enemy_killed.connect(_on_enemy_killed)
	print("BOT diff=", _diff, " acc=", _acc, " up=", _uptime)
	GameManager.start_level(2)
	_step = 1


func _on_boss_health(c: float, _m: float, p: int) -> void:
	_health_sigs += 1
	_phases_seen[p] = true
	if _boss_last >= 0.0 and c < _boss_last:
		_boss_dmg += _boss_last - c
	_boss_last = c
	if p >= 0 and p <= 2 and _phase_start[p] < 0.0:
		_phase_start[p] = _t
		_log.append("phase%d@%.1f" % [p, _t - _fight_start])


func _on_enemy_killed(_pos: Vector2) -> void:
	if _boss != null and _fight_start >= 0.0:
		_minion_kills += 1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		print("  FAIL ", label)
		_fails += 1


func _shot(name: String) -> void:
	if not _shot_mode:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + name + ".png")
	print("SHOT ", name)


func _physics_process(delta: float) -> void:
	_frames += 1
	_t += delta
	match _step:
		1:
			var cs := get_tree().current_scene
			if cs != null and cs.name == "Level3":
				_level = cs
				_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
				_step = 2
				_frames = 0
		2:
			if _frames == 30:
				var b = _level.get("_briefing")
				_check(b != null and is_instance_valid(b), "briefing open on fresh start")
				if b != null and is_instance_valid(b) and b.has_method("close"):
					b.close()
			if _frames == 60:
				_check(Global.level_active, "level active after briefing")
				var variants := {}
				for e in get_tree().get_nodes_in_group("Enemies"):
					var k := String(e.variant_key())
					variants[k] = int(variants.get(k, 0)) + 1
				print("  level variants: ", variants)
				for e in get_tree().get_nodes_in_group("Enemies"):
					if e.is_alive():
						e.die()
			if _frames == 90:
				var key := get_tree().get_first_node_in_group("key_items") as Node2D
				_check(key != null, "key dropped")
				if key != null:
					_player.global_position = key.global_position
			if _frames == 110:
				_check(Global.has_key, "key collected by touch")
				_check(Global.alarm_active, "alarm started on key")
				_player.global_position = Vector2(400, 14)
			if _frames == 130:
				Input.action_press("action")
			if _frames == 132:
				Input.action_release("action")
			if _frames == 150:
				_boss = Global.boss_node
				_check(_boss != null and is_instance_valid(_boss), "boss spawned by door open")
				_check(not Global.alarm_active, "alarm stopped by boss")
				_check(Global.objective == "DERROTA AL CONTRATISTA", "objective boss (%s)" % Global.objective)
				if _boss == null:
					_finish()
					return
				print("  boss at ", _boss.global_position, " hp=", _boss.get("max_health"), " spawn_sigs=", _spawn_sigs)
				_fight_start = _t
				Global.combo = 1
				Global.combo_time = 0.0
				_last_hp = Global.health
				_boss_prev_pos = (_boss as Node2D).global_position
				_player.global_position = Vector2(400, -10)
				_step = 3
				_frames = 0
				_shot("final_boss_intro")
		3:
			_fight(delta)
		4:
			_after(delta)


func _fight(delta: float) -> void:
	if Global.health < _last_hp:
		var d := _last_hp - Global.health
		_dmg_in += d
		var ph := clampi(int(_boss.get("phase")), 0, 2)
		_dmg_in_phase[ph] += d
		var src := "%.2f" % d
		_hist[src] = int(_hist.get(src, 0)) + 1
	_last_hp = Global.health
	var act := int(_boss.get("_action"))
	var ph2 := int(_boss.get("phase"))
	var key := "%d:%d" % [ph2, act]
	_actions[key] = int(_actions.get(key, 0)) + 1
	var alive := 0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e != _boss and e.is_alive():
			alive += 1
	_max_minions = maxi(_max_minions, alive)
	var bpos := (_boss as Node2D).global_position
	if bpos.distance_to(_boss_prev_pos) < 0.5 and int(_boss.get("_mode")) == 1 and act == 0:
		_boss_still += delta
		_boss_max_still = maxf(_boss_max_still, _boss_still)
	else:
		_boss_still = 0.0
	_boss_prev_pos = bpos
	if _shot_mode:
		_shots_timeline()
	if not _boss.is_alive():
		_fight_end = _t
		_death_real_ms = Time.get_ticks_msec()
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		_check(is_equal_approx(Engine.time_scale, 0.35), "slow motion on death")
		_step = 4
		_frames = 0
		return
	if _frames % 600 == 0:
		var cols := []
		for i in range(_player.get_slide_collision_count()):
			var c := _player.get_slide_collision(i)
			cols.append([str(c.get_collider()), c.get_position(), c.get_normal()])
		print("   dbg goal=", _pickup_goal(_player.global_position), " inp=", Input.get_vector("move_left", "move_right", "move_up", "move_down"), " bp_i=", _bp_i, " bp=", _bp.slice(0, 5), " cols=", cols, " los=", _los(_player.global_position, (_boss as Node2D).global_position))
		print("  t=%.0f boss_hp=%.0f mode=%d act=%d boss=%s player=%s php=%.0f" % [_t - _fight_start, float(_boss.get("health")), int(_boss.get("_mode")), int(_boss.get("_action")), str((_boss as Node2D).global_position), str(_player.global_position), Global.health])
	if _t - _fight_start > 400.0:
		print("  TIMEOUT boss mode=", _boss.get("_mode"), " state=", _boss.get("state"), " vel=", _boss.get("velocity"), " path=", _boss.get("_path"), " pi=", _boss.get("_path_index"), " arena=", _boss.get("_arena_pos"))
		print("  TIMEOUT boss hp=", _boss.get("health"), " boss=", (_boss as Node2D).global_position, " player=", _player.global_position, " php=", Global.health, " grace=", Global.grace_time, " inv=", Global.invuln_time, " log=", _log)
		_finish()
		return
	if Global.health <= 0.0:
		if _dead_since < 0.0:
			_dead_since = _t
			_deaths += 1
			_log.append("death@%.1f" % (_t - _fight_start))
			for a in ["move_left", "move_right", "move_up", "move_down"]:
				Input.action_release(a)
		if _t - _dead_since > 1.5:
			Global.lives = 3
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_R
			ev.keycode = KEY_R
			ev.pressed = true
			Input.parse_input_event(ev)
			var up := InputEventKey.new()
			up.physical_keycode = KEY_R
			up.keycode = KEY_R
			up.pressed = false
			Input.parse_input_event(up)
		return
	if _dead_since >= 0.0:
		_dead_since = -1.0
		_respawns += 1
		_log.append("respawn@%.1f mode=%d" % [_t - _fight_start, int(_boss.get("_mode"))])
	if _respawns > 0 and not _respawn_checked and Global.invuln_time <= 0.0:
		_respawn_checked = true
		print("  after respawn boss mode=", _boss.get("_mode"), " state=", _boss.get("state"), " hp=", _boss.get("health"))
	_bot_move(delta)
	_bot_shoot(delta)


func _los(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return _player.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _pick_target() -> Node2D:
	var p := _player.global_position
	var best: Node2D = null
	var best_d := 230.0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e == _boss or not e.is_alive():
			continue
		var d: float = (e as Node2D).global_position.distance_to(p)
		if d < best_d and _los(p, (e as Node2D).global_position):
			best_d = d
			best = e
	if best != null:
		return best
	if _los(p, (_boss as Node2D).global_position):
		return _boss as Node2D
	return null


func _bot_move(delta: float) -> void:
	var p := _player.global_position
	var bpos := (_boss as Node2D).global_position
	var to_boss := bpos - p
	var d := to_boss.length()
	var dir := to_boss.normalized() if d > 1.0 else Vector2.RIGHT
	var want := Vector2.ZERO
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.4)
		_strafe_sign = -_strafe_sign
	var goal := _pickup_goal(p)
	if goal.is_finite():
		want = _path_dir(p, goal)
		_press(want)
		return
	if not _los(p, bpos) or d > 320.0:
		want = _path_dir(p, bpos)
		_press(want)
		return
	var radial := 0.0
	if d < 120.0:
		radial = -1.0
	elif d > 200.0:
		radial = 0.8
	want = dir * radial + dir.orthogonal() * _strafe_sign * 0.9
	var act := int(_boss.get("_action"))
	if act == 4:
		var dd: Vector2 = _boss.get("_dash_dir")
		var side := signf(dd.orthogonal().dot(p - bpos))
		if side == 0.0:
			side = 1.0
		want = dd.orthogonal() * side
	elif act == 7 and d < 110.0:
		want = -dir
	if want.length() < 0.1:
		want = dir.orthogonal() * _strafe_sign
	if _dodge:
		var dg := _dodge_dir(p)
		if dg != Vector2.ZERO and act != 4:
			want = dg
	_press(_avoid(p, want.normalized()))


func _dodge_dir(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_t := 0.5
	for n in get_tree().current_scene.get_children():
		if not (n is Area2D) or (int(n.collision_layer) & 16) == 0:
			continue
		if bool(n.get("_spent")) or float(n.get("_age")) < 0.15:
			continue
		var bdir := Vector2.RIGHT.rotated(n.global_rotation)
		var rel: Vector2 = p - n.global_position
		var along := rel.dot(bdir)
		if along <= 0.0:
			continue
		var t := along / maxf(float(n.get("speed")), 1.0)
		if t > 0.45:
			continue
		var perp := rel - bdir * along
		if perp.length() < 20.0 and t < best_t:
			best_t = t
			best = perp.normalized() if perp.length() > 0.5 else bdir.orthogonal()
	return best


func _pickup_goal(p: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_d := 170.0
	for n in get_tree().get_nodes_in_group("pickups"):
		var pk := n as Node2D
		if pk == null:
			continue
		var kind := int(pk.get("kind"))
		var useful := (kind == 1 and Global.health < 70.0) or (kind == 0 and Global.total_ammo(0) < 60) or (kind == 2 and Global.lives < 3)
		if not useful:
			continue
		var dd := pk.global_position.distance_to(p)
		if dd < best_d:
			best_d = dd
			best = pk.global_position
	return best


var _bp: PackedVector2Array = PackedVector2Array()
var _bp_i: int = 0
var _bp_goal: Vector2 = Vector2.INF
var _bp_t: float = 0.0


func _path_dir(p: Vector2, goal: Vector2) -> Vector2:
	_bp_t -= get_physics_process_delta_time()
	if _bp_t <= 0.0 or not _bp_goal.is_finite() or _bp_goal.distance_to(goal) > 24.0:
		_bp = _level.find_path(p, goal)
		_bp_i = 0
		_bp_goal = goal
		_bp_t = 0.4
	while _bp_i < _bp.size() - 1 and _bp[_bp_i].distance_to(p) < 7.0:
		_bp_i += 1
	if _bp.is_empty():
		return (goal - p).normalized()
	return (_bp[_bp_i] - p).normalized()


var _stuck_t: float = 0.0
var _stuck_pos: Vector2 = Vector2.ZERO


func _press(want: Vector2) -> void:
	_stuck_t += get_physics_process_delta_time()
	if _stuck_t > 0.8:
		if _player.global_position.distance_to(_stuck_pos) < 8.0 and want.length() > 0.1:
			if not _bp.is_empty():
				_bp_i = mini(_bp_i + 1, _bp.size() - 1)
				_player.global_position = _bp[_bp_i]
			else:
				_player.global_position += want * 6.0
		_stuck_t = 0.0
		_stuck_pos = _player.global_position
	for i in range(_player.get_slide_collision_count()):
		var c := _player.get_slide_collision(i)
		if c.get_collider() is TileMapLayer or c.get_collider() is StaticBody2D:
			want += c.get_normal() * 0.9
	if want.length() > 0.05:
		want = want.normalized()
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if want.x > 0.38:
		Input.action_press("move_right")
	elif want.x < -0.38:
		Input.action_press("move_left")
	if want.y > 0.38:
		Input.action_press("move_down")
	elif want.y < -0.38:
		Input.action_press("move_up")


func _avoid(p: Vector2, want: Vector2) -> Vector2:
	for ang in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9, PI]:
		var w := want.rotated(ang)
		if _los(p, p + w * 22.0) and _level.is_walkable(p + w * 18.0):
			if ang >= 1.9 or ang <= -1.9:
				_strafe_sign = -_strafe_sign
			return w
	return want


func _bot_shoot(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			Global.reloading = false
			Global.reload()
		return
	if Global.current_weapon != 0:
		Global.switch_weapon(0)
	var target := _pick_target()
	if target == null:
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		if _pause_left <= 0.0:
			_burst_left = randf_range(0.6, 1.4)
		return
	_burst_left -= delta
	if _burst_left <= 0.0:
		var pause := randf_range(0.6, 1.4) * (1.0 - _uptime) / maxf(_uptime, 0.05)
		_pause_left = maxf(pause, 0.01)
		return
	if _fire_cd > 0.0:
		return
	if Global.ammo <= 0:
		if Global.reserve_ammo <= 0:
			_starved += 1
			Global.add_reserve_ammo(60, 0)
		_reload_left = Global.reload_time
		Global.reloading = true
		return
	Global.use_ammo()
	var err := randfn(0.0, _acc)
	var angle := (target.global_position - _player.global_position).angle() + deg_to_rad(err)
	var b = BALA.instantiate()
	b.shooter = _player
	b.damage = 22.0 * Global.damage_mult()
	b.speed = 900.0
	b.lifetime = 2.0
	b.tier = Global.flow_tier()
	get_tree().current_scene.add_child(b)
	b.global_rotation = angle
	b.global_position = _player.global_position + Vector2(34.0, 0.0).rotated(angle)
	_player.set("_shot_glow", 0.9)
	Global.make_noise(_player.global_position, 180.0, _player.global_position)
	_shots += 1
	if target == _boss:
		_expected += 22.0 * Global.damage_mult()
	_fire_cd = 0.1 * Global.fire_rate_mult()


var _shot_flags: Dictionary = {}


func _shots_timeline() -> void:
	var act := int(_boss.get("_action"))
	var ph := int(_boss.get("phase"))
	var at := float(_boss.get("_action_time"))
	var names := {1: "burst", 2: "fan", 3: "ring", 4: "dash", 7: "stomp"}
	if names.has(act) and at > 0.25 and at < 0.4:
		var k := "final_p%d_%s" % [ph, names[act]]
		if not _shot_flags.has(k):
			_shot_flags[k] = true
			_shot(k)
	if int(_boss.get("_mode")) == 2 and not _shot_flags.has("tr%d" % ph):
		_shot_flags["tr%d" % ph] = true
		_shot("final_p%d_transition" % ph)


func _after(_delta: float) -> void:
	if _frames == 5:
		_shot("final_boss_death")
	if _slow_ms < 0 and Engine.time_scale >= 1.0:
		_slow_ms = Time.get_ticks_msec() - _death_real_ms
	if _frames == 150:
		var ttk := _fight_end - _fight_start
		_check(_defeat_sigs == 1, "boss_defeated once")
		_check(not Global.boss_alive, "boss_alive false")
		_check(is_equal_approx(Engine.time_scale, 1.0), "time_scale restored (after %d ms)" % _slow_ms)
		_check(_phases_seen.has(0) and _phases_seen.has(1) and _phases_seen.has(2), "health signal phases 0-2")
		_check(Global.objective == "LLEGA A LA SALIDA", "objective back to exit (%s)" % Global.objective)
		print("RESULT diff=%d acc=%.1f up=%.2f ttk=%.1fs deaths=%d dmg_in=%.0f dps_in=%.1f dmg_phase=%s shots=%d boss_dmg=%.0f hit%%=%.0f starved=%d minion_kills=%d max_adds=%d boss_max_still=%.1fs" % [_diff, _acc, _uptime, ttk, _deaths, _dmg_in, _dmg_in / maxf(ttk, 1.0), str(_dmg_in_phase), _shots, _boss_dmg, 100.0 * _boss_dmg / maxf(1.0, _expected), _starved, _minion_kills, _max_minions, _boss_max_still])
		print("  log ", _log)
		print("  dmg hist ", _hist)
		var summary := {}
		for k in _actions:
			var parts := String(k).split(":")
			if parts[1] != "0":
				summary[k] = snappedf(float(_actions[k]) / 60.0, 0.1)
		print("  action seconds (phase:action) ", summary)
		for e in get_tree().get_nodes_in_group("Enemies"):
			if e != _boss and e.is_alive():
				e.die()
	if _frames == 170:
		_player.global_position = Vector2(400, 20)
	if _frames > 170 and _frames < 600 and Global.level_active:
		var ex := get_tree().get_first_node_in_group("exit_zone") as Node2D
		_press(_path_dir(_player.global_position, ex.global_position))
	if _frames == 600 or (_frames > 170 and not Global.level_active and _frames % 30 == 0):
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		_check(not Global.level_active, "exit completed the level")
		_check(GameManager.last_rank != "", "rank computed (%s)" % GameManager.last_rank)
		_finish()


func _finish() -> void:
	print("FIGHT_BOT_DONE fails=", _fails)
	get_tree().quit()
