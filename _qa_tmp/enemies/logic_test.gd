extends Node

const EnemyScene := preload("res://Scenes/Enemy.tscn")
const BossScene := preload("res://Scenes/Boss.tscn")
const BalaScene := preload("res://Scenes/Bala.tscn")
const BalaEnemyScene := preload("res://Scenes/BalaEnemy.tscn")

var _step: int = 0
var _frames: int = 0
var _fails: int = 0
var _level: Node = null
var _player: CharacterBody2D = null
var _holder: Node2D = null
var _tir: Node = null
var _tir_log: Array = []
var _tir_shots: Array = []
var _tir_prev_timer: float = 0.0
var _enemy_bullets_before: int = 0
var _lit: Node = null
var _dark_aw: float = 0.0
var _lit_aw: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	Settings.difficulty = 1
	GameManager.start_level(1, Global.START_RETRY)
	_step = 1


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		print("  FAIL ", label)
		_fails += 1


func _spawn(v: int, behavior: int, pos: Vector2, rot: float = 0.0) -> Node:
	var e := EnemyScene.instantiate()
	e.set("behavior", behavior)
	e.set("appears_from", 0)
	_holder.add_child(e)
	e.global_position = pos
	e.global_rotation = rot
	e.set("_base_rotation", rot)
	e.set("_home_position", pos)
	if v != 0:
		e.apply_variant(v)
	return e


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("Enemies"):
		e.remove_from_group("Enemies")
		e.queue_free()


func _physics_process(_d: float) -> void:
	_frames += 1
	match _step:
		1:
			var cs := get_tree().current_scene
			if _frames > 20 and cs != null and cs.name == "Level2":
				_level = cs
				_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
				_holder = _level.get_node("Enemies") as Node2D
				print("LEVEL2 lights_out=", Global.lights_out, " level_active=", Global.level_active)
				_clear_enemies()
				_step = 2
				_frames = 0
		2:
			if _frames == 2:
				_variant_stats()
				_alert_checks()
				_bullet_checks()
			if _frames == 4:
				_light_setup()
			if _frames > 4 and _frames < 184:
				_light_tick()
			if _frames == 184:
				_light_report()
			if _frames == 190:
				_detection_checks()
			if _frames == 200:
				_tirador_setup()
			if _frames > 200 and _frames < 560:
				_tirador_tick()
			if _frames == 560:
				_tirador_report()
				_boss_checks()
			if _frames == 700:
				_boss_report()
				print("LOGIC_TEST_DONE fails=", _fails)
				get_tree().quit()


func _variant_stats() -> void:
	print("VARIANTS")
	var far := _player.global_position + Vector2(0, 2000)
	var base := _spawn(0, 0, far)
	var p := _spawn(1, 0, far + Vector2(40, 0))
	var t := _spawn(2, 0, far + Vector2(80, 0))
	var r := _spawn(3, 0, far + Vector2(120, 0))
	var bh := float(base.max_health)
	_check(base.variant_key() == "soldado" and p.variant_key() == "pesado" and t.variant_key() == "tirador" and r.variant_key() == "rapido", "variant keys")
	_check(is_equal_approx(p.max_health, bh * 2.4) and is_equal_approx(p.health, p.max_health), "pesado hp x2.4 and full")
	_check(is_equal_approx(p.speed, base.speed * 0.75) and is_equal_approx(p.patrol_speed, base.patrol_speed * 0.75), "pesado speed x0.75")
	_check(is_equal_approx(p.knockback, base.knockback * 0.3) and is_equal_approx(p.fire_rate, base.fire_rate * 1.35), "pesado knockback/fire_rate")
	_check(p.pellets == 4 and is_equal_approx(p.fan_degrees, 14.0) and not p.can_flee and p.kill_points == 150, "pesado pellets/fan/flee/points")
	_check(is_equal_approx(t.vision_range, base.vision_range * 1.7) and is_equal_approx(t.vision_angle, base.vision_angle * 0.6), "tirador vision")
	_check(is_equal_approx(t.attack_range, base.attack_range * 1.6) and is_equal_approx(t.fire_rate, base.fire_rate * 2.2), "tirador range/fire_rate")
	_check(is_equal_approx(t.reaction_time, base.reaction_time * 1.5) and is_equal_approx(t.spread_degrees, base.spread_degrees * 0.2), "tirador reaction/spread")
	_check(is_equal_approx(t.bullet_speed_mult, 1.9) and is_equal_approx(t.bullet_damage_mult, 2.2) and t.stop_to_shoot and t.has_laser and t.kill_points == 130, "tirador bullets/laser/points")
	_check(is_equal_approx(r.speed, base.speed * 1.55) and is_equal_approx(r.patrol_speed, base.patrol_speed * 1.3) and is_equal_approx(r.max_health, bh * 0.6), "rapido speed/hp")
	_check(is_equal_approx(r.fire_rate, base.fire_rate * 0.55) and is_equal_approx(r.spread_degrees, base.spread_degrees * 1.5) and is_equal_approx(r.attack_range, base.attack_range * 0.6), "rapido fire/spread/range")
	_check(is_equal_approx(r.reaction_time, base.reaction_time * 0.6) and not r.can_flee and r.kill_points == 120, "rapido reaction/flee/points")
	var sb: Vector2 = base.anim.scale
	_check(p.anim.scale.is_equal_approx(sb * 1.18) and r.anim.scale.is_equal_approx(sb * 0.92) and t.anim.scale.is_equal_approx(sb), "variant sprite scales")
	var cols := []
	for e in [base, p, t, r]:
		var m := e.anim.material as ShaderMaterial
		cols.append(m.get_shader_parameter("albedo_color"))
	print("  albedo: ", cols)
	_check(cols[0] != cols[1] and cols[1] != cols[2] and cols[2] != cols[3] and cols[0] != cols[3], "variant tints distinct")
	_check(base.anim.material != p.anim.material and p.anim.material != r.anim.material, "variant materials not shared")
	p.apply_variant(3)
	_check(p.variant_key() == "pesado" and is_equal_approx(p.max_health, bh * 2.4), "second apply_variant ignored")
	base.apply_variant(0)
	_check(base.variant_key() == "soldado" and not base.get("_variant_applied"), "apply_variant(SOLDADO) no-op")
	var pre := EnemyScene.instantiate()
	pre.set("behavior", 0)
	pre.set("variant", 1)
	_holder.add_child(pre)
	pre.global_position = far + Vector2(160, 0)
	_check(pre.variant_key() == "pesado" and is_equal_approx(pre.max_health, bh * 2.4), "inspector variant applied in _ready")
	var laser := t.get_node_or_null("Laser") as Line2D
	_check(laser != null and laser.light_mask == 0, "laser light_mask 0")
	var icon_ok := false
	for c in base.get_children():
		if c is Node2D and (c as Node2D).top_level and c.get_script() != null:
			icon_ok = (c as CanvasItem).light_mask == 0
	_check(icon_ok, "awareness icon light_mask 0")
	for e in [base, p, t, r, pre]:
		e.queue_free()


func _alert_checks() -> void:
	print("ALERT_TO")
	var far := _player.global_position + Vector2(0, 2400)
	var e := _spawn(0, 1, far)
	var target := far + Vector2(60, 0)
	e.alert_to(target)
	_check(e.state == 4 and (e.get("_investigate_pos") as Vector2).is_equal_approx(target), "alert_to -> INVESTIGAR at point")
	e.set("state", 1)
	e.alert_to(far + Vector2(-60, 0))
	_check(e.state == 1, "alert_to ignored while ATACAR")
	e.set("state", 5)
	e.alert_to(far)
	_check(e.state == 5, "alert_to ignored while HUIR")
	e.set("state", 0)
	e.die()
	e.alert_to(far)
	_check(e.state == 3, "alert_to ignored when dead")
	var inert := _spawn(0, 3, far + Vector2(40, 0))
	inert.alert_to(far)
	_check(inert.state == 0, "alert_to ignored for INERTE")
	var t := _spawn(0, 0, far + Vector2(80, 0))
	t.alert_to(far + Vector2(80, -100))
	_check(t.state == 4, "turret alert_to investigates")
	for n in [e, inert, t]:
		n.queue_free()


func _bullet_checks() -> void:
	print("BULLETS")
	var b := BalaScene.instantiate()
	var eb := BalaEnemyScene.instantiate()
	add_child(b)
	add_child(eb)
	_check(b.light_mask == 0 and eb.light_mask == 0, "bullet light_mask 0")
	_check((b.get_node("Sprite2D") as CanvasItem).light_mask == 0, "bullet sprite light_mask 0")
	var tr := b.get("_trail") as Line2D
	_check(tr != null and tr.light_mask == 0, "trail light_mask 0")
	_check(is_equal_approx(float(b.size_mult), 1.0) and b.glow_color.a == 0.0 and b.scale == Vector2.ONE, "player bullet defaults unchanged")
	_check((b.get("_glow_color") as Color).is_equal_approx(Color(1.0, 0.78, 0.22)), "player bullet glow default")
	_check((eb.get("_glow_color") as Color).is_equal_approx(Color(1.0, 0.32, 0.22)), "enemy bullet glow default")
	b.set("_spent", true)
	eb.set("_spent", true)
	b.queue_free()
	eb.queue_free()


func _light_setup() -> void:
	print("LIGHT_VISIBILITY")
	_player.global_position = Vector2(-40, -40) if _level.is_walkable(Vector2(-40, -40)) else _player.global_position
	Global.grace_time = 0.0
	Global.set_flashlight(false)
	var lv := float(_player.get("light_visibility"))
	_check(Global.lights_out and is_equal_approx(lv, 0.5), "apagon, flashlight off -> light_visibility 0.5 (%s)" % lv)
	var spot := _los_spot(_player.global_position, 150.0)
	_lit = _spawn(0, 0, spot, (_player.global_position - spot).angle())
	_lit.set("turret_sweep_degrees", 0.0)
	var reach: float = _lit._sight_range(_player)
	print("  enemy at dist=", spot.distance_to(_player.global_position), " vision=", _lit.vision_range, " reach=", reach)
	_check(is_equal_approx(reach, _lit.vision_range * 0.5), "sight range halved in the dark")


func _los_spot(origin: Vector2, dist: float) -> Vector2:
	var space := _player.get_world_2d().direct_space_state
	for i in range(48):
		var c := origin + Vector2.RIGHT.rotated(TAU * float(i) / 48.0) * dist
		if not _level.is_walkable(c):
			continue
		var q := PhysicsRayQueryParameters2D.create(origin, c, 1)
		if space.intersect_ray(q).is_empty():
			return c
	return origin + Vector2(dist, 0)


func _light_tick() -> void:
	_player.set("_shot_glow", 0.0)
	_lit.global_rotation = (_player.global_position - _lit.global_position).angle()
	_lit.set("_base_rotation", _lit.global_rotation)
	Global.grace_time = 0.0
	if _frames < 94:
		Global.set_flashlight(false)
		_dark_aw = maxf(_dark_aw, float(_lit.awareness))
	else:
		Global.set_flashlight(true)
		_lit_aw = maxf(_lit_aw, float(_lit.awareness))


func _light_report() -> void:
	print("  awareness dark=", _dark_aw, " lit=", _lit_aw, " state=", _lit.state)
	_check(_dark_aw < 0.01, "no detection in the dark beyond halved range")
	_check(_lit_aw > 0.2, "detection grows with the flashlight on")
	Global.set_flashlight(false)
	_lit.queue_free()


func _detection_checks() -> void:
	print("DETECTION")
	Global.level_active = true
	var e := _spawn(0, 0, _player.global_position + Vector2(0, 3000))
	var before := Global.times_detected
	e.set("_target", _player)
	e._enter_attack()
	_check(Global.times_detected == before + 1, "register_detection on calm -> ATACAR")
	Global.set("_last_detection_time", -100.0)
	e._enter_attack()
	_check(Global.times_detected == before + 1, "no detection when already attacking")
	var e2 := _spawn(0, 0, _player.global_position + Vector2(40, 3000))
	Global.set("_last_detection_time", -100.0)
	Global.boss_alive = true
	e2.set("_target", _player)
	e2._enter_attack()
	Global.boss_alive = false
	_check(Global.times_detected == before + 1, "no detection penalty during the boss fight")
	var sk := Global.stealth_kills
	var v := _spawn(1, 0, _player.global_position + Vector2(80, 3000), 0.0)
	v.melee_hit(45.0, v.global_position + Vector2(-20, 0))
	_check(not v.is_alive() and Global.stealth_kills == sk + 1, "stealth kill on unaware pesado from behind")
	var f := _spawn(0, 0, _player.global_position + Vector2(120, 3000), 0.0)
	f.melee_hit(45.0, f.global_position + Vector2(20, 0))
	_check(f.is_alive() and Global.stealth_kills == sk + 1, "frontal knife is not a stealth kill")
	var a := _spawn(0, 0, _player.global_position + Vector2(160, 3000), 0.0)
	a.set("state", 1)
	a.melee_hit(45.0, a.global_position + Vector2(-20, 0))
	_check(a.is_alive() and Global.stealth_kills == sk + 1, "alerted enemy is not stealth killed")
	for n in [e, e2, v, f, a]:
		n.queue_free()


func _tirador_setup() -> void:
	print("TIRADOR")
	Global.max_health = 100000.0
	Global.health = 100000.0
	Global.invuln_time = 0.0
	Global.grace_time = 0.0
	Global.set_flashlight(true)
	var far := _player.global_position
	for dd in [380.0, 340.0, 300.0, 270.0]:
		var c := _los_spot(_player.global_position, dd)
		if _level.is_walkable(c) and _clear(c, _player.global_position):
			far = c
			break
	_tir = _spawn(2, 2, far, (_player.global_position - far).angle())
	_tir.set("attack_range", 160.0)
	_tir.set("_target", _player)
	_tir._enter_attack()
	_tir_prev_timer = float(_tir.get("_shoot_timer"))
	print("  tirador dist=", far.distance_to(_player.global_position), " attack_range=", _tir.attack_range)


func _clear(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return _player.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _tirador_tick() -> void:
	Global.grace_time = 0.0
	if not is_instance_valid(_tir) or not _tir.is_alive():
		return
	var laser := _tir.get_node("Laser") as Line2D
	var timer := float(_tir.get("_shoot_timer"))
	var dist: float = _tir.global_position.distance_to(_player.global_position)
	var fired := float(_tir.get("_laser_flash")) > 0.09
	if fired:
		_tir_shots.append({"frame": _frames, "dist": dist})
	_tir_log.append({"f": _frames, "timer": timer, "alpha": laser.default_color.a, "width": laser.width, "rot": _tir.global_rotation, "state": _tir.state, "dist": dist})
	_tir_prev_timer = timer


func _tirador_report() -> void:
	print("  shots at frames: ", _tir_shots)
	_check(not _tir_shots.is_empty(), "tirador fired")
	var ok_lead := true
	var ok_lock := true
	for s in _tir_shots:
		var fs: int = s["frame"]
		var charge := 0
		var lock_ok := true
		var rot_at_lock := INF
		for i in range(_tir_log.size()):
			var r: Dictionary = _tir_log[i]
			if r["f"] >= fs or r["f"] < fs - 60:
				continue
			if float(r["timer"]) <= 0.6 and float(r["timer"]) > 0.0 and float(r["alpha"]) >= 0.3:
				charge += 1
			if float(r["timer"]) <= 0.18 and float(r["timer"]) > 0.0:
				if rot_at_lock == INF:
					rot_at_lock = float(r["rot"])
				elif absf(angle_difference(rot_at_lock, float(r["rot"]))) > 0.001:
					lock_ok = false
		print("  shot@", fs, " telegraph_frames=", charge, " lock_steady=", lock_ok)
		if charge < 30:
			ok_lead = false
		if not lock_ok:
			ok_lock = false
	_check(ok_lead, "every tirador shot telegraphed >= 0.5 s by the laser")
	_check(ok_lock, "tirador aim locked before firing")
	var hold := true
	for r in _tir_log:
		if int(r["state"]) == 1 and float(r["dist"]) > float(_tir.attack_range) + 2.0 and float(r["timer"]) < 0.59:
			hold = false
	_check(hold, "out of range tirador keeps the telegraph charge")
	Global.max_health = 100.0
	Global.health = 100.0
	_tir.queue_free()


var _boss: Node = null
var _boss_hp0: float = 0.0


func _boss_checks() -> void:
	print("BOSS")
	var spot := _los_spot(_player.global_position, 160.0)
	_boss = BossScene.instantiate()
	_holder.add_child(_boss)
	_boss.global_position = spot
	_boss_hp0 = float(_boss.health)
	_check(_boss.is_in_group("boss") and _boss.is_in_group("Enemies"), "boss groups")
	_check(Global.boss_alive and Global.boss_node == _boss, "boss registered")
	_boss.take_damage(100.0)
	_check(is_equal_approx(float(_boss.health), _boss_hp0), "boss immune during intro")
	_boss.set("_mode", 1)
	_boss.set("state", 0)
	_boss.global_rotation = 0.0
	var hp := float(_boss.health)
	_boss.melee_hit(45.0, _boss.global_position + Vector2(-20, 0))
	_check(_boss.is_alive() and is_equal_approx(float(_boss.health), hp - 45.0), "boss cannot be stealth killed (knife = 45)")
	_boss.apply_variant(1)
	_check(_boss.variant_key() == "jefe", "boss ignores apply_variant")
	var aw: Variant = _boss.get("vision_angle")
	print("  boss hp=", _boss_hp0, " vision_angle=", aw)


func _boss_report() -> void:
	_boss.set("_mode", 1)
	_boss.take_damage(float(_boss.health) + 10.0)
	_check(_boss.phase == 1 and _boss.is_alive(), "single huge hit only reaches the next phase")
	Global.health = 100.0
	_boss.queue_free()
	Global.clear_boss()
