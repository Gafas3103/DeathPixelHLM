extends "res://Scripts/Enemy/enemy.gd"

const Story := preload("res://Scripts/story.gd")
const PICKUP_SCENE_PATH := "res://Scenes/Items/Pickup.tscn"
const ENEMY_SCENE_PATH := "res://Scenes/Enemy.tscn"

enum Mode { INTRO, FIGHT, TRANSITION, DORMANT, DEAD }
enum Action { NONE, BURST, FAN, RING, DASH_AIM, DASH, RECOVER, STOMP }

const PHASE_MARKS: Array[float] = [0.66, 0.33]
const INTRO_TIME := 2.0
const TRANSITION_TIME := 1.2
const STRAFE_MIN := 150.0
const STRAFE_MAX := 230.0
const DASH_SPEED := 520.0
const DASH_TIME := 0.35
const DASH_AIM_TIME := 0.55
const RECOVER_TIME := 0.65
const BURST_AIM := 0.4
const BURST_LOCK := 0.14
const BURST_GAP := 0.12
const FAN_AIM := 0.5
const FAN_LOCK := 0.15
const FAN_PELLETS := 7
const FAN_DEGREES := 40.0
const RING_CHARGE := 0.6
const RING_BULLETS := 14
const RING_GAP := 0.34
const WAKE_RANGE := 280.0
const CLOSE_RANGE := 80.0
const STOMP_CHARGE := 0.5
const STOMP_RADIUS := 72.0
const STOMP_DAMAGE := 16.0
const BOSS_POINTS := 2500
const SLOW_MO_SCALE := 0.35
const SLOW_MO_TIME := 1.2
const COLOR_BURST := Color(1.0, 0.2, 0.35, 1.0)
const COLOR_FAN := Color(1.0, 0.42, 0.18, 1.0)
const COLOR_RING := Color(1.0, 0.16, 0.6, 1.0)
const COLOR_DANGER := Color(1.0, 0.12, 0.12, 1.0)
const COLOR_SHIELD := Color(1.0, 0.69, 0.0, 1.0)


class BossLayer extends Node2D:
	var boss: Node = null
	var aura: bool = false

	func _init() -> void:
		light_mask = 0

	func _process(_delta: float) -> void:
		if boss == null or not is_instance_valid(boss):
			queue_free()
			return
		if not aura:
			global_position = boss.global_position
			global_rotation = 0.0
		queue_redraw()

	func _draw() -> void:
		if boss == null or not is_instance_valid(boss):
			return
		if aura:
			boss.draw_aura(self)
		else:
			boss.draw_fx(self)


class Shockwave extends Node2D:
	var radius: float = 6.0
	var alpha: float = 1.0
	var color: Color = Color.WHITE
	var width: float = 4.0

	func _init() -> void:
		z_index = 45
		light_mask = 0
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat

	func start(max_radius: float, duration: float) -> void:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "radius", max_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "alpha", 0.0, duration)
		tween.chain().tween_callback(queue_free)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(color, alpha), maxf(1.0, width * alpha))
		draw_circle(Vector2.ZERO, radius * 0.9, Color(color, alpha * 0.08))


@export_group("Jefe")
@export var custom_frames: SpriteFrames = null
@export var tinted: bool = true
@export var dash_damage: float = 30.0

var phase: int = 0

var _mode: int = Mode.INTRO
var _mode_time: float = 0.0
var _action: int = Action.NONE
var _action_time: float = 0.0
var _action_cd: float = 1.0
var _last_action: int = Action.NONE
var _shots_left: int = 0
var _shot_cd: float = 0.0
var _burst_angle: float = 0.0
var _burst_sweep: float = 1.0
var _rings_total: int = 0
var _rings_fired: int = 0
var _ring_spin: float = 0.0
var _fan_fired: bool = false
var _fan_second: bool = false
var _dash_dir: Vector2 = Vector2.RIGHT
var _dash_len: float = 0.0
var _dash_hit: bool = false
var _dash_cd: float = 0.0
var _stomp_cd: float = 0.0
var _stomp_done: bool = false
var _recover_time: float = 0.0
var _strafe_point: Vector2 = NO_POINT
var _strafe_timer: float = 0.0
var _strafe_dir: float = 1.0
var _arena_pos: Vector2 = Vector2.ZERO
var _cd_mult: float = 1.0
var _tele_mult: float = 1.0
var _dmg_scale: float = 1.0
var _summoned: bool = false
var _roared: bool = false
var _immune_note: float = 0.0
var _shield_flash: float = 0.0
var _fx_time: float = 0.0
var _glow: float = 0.3
var _glow_scale: float = 1.0
var _mat: ShaderMaterial = null
var _aura_layer: Node2D = null
var _fx_layer: Node2D = null
var _intro_tween: Tween = null
var cinematic_death: bool = false


func _ready() -> void:
	add_to_group("boss")
	if not is_in_group("Enemies"):
		add_to_group("Enemies")
	behavior = Behavior.PERSEGUIR
	can_flee = false
	_variant_applied = true

	if custom_frames != null and anim != null:
		anim.sprite_frames = custom_frames
		AnimNames.play(anim, AnimNames.IDLE)
	if anim != null and anim.material is ShaderMaterial:
		_mat = (anim.material as ShaderMaterial).duplicate() as ShaderMaterial
		anim.material = _mat
		if not tinted:
			_mat.set_shader_parameter("albedo_color", Color.WHITE)
			_glow_scale = 0.4

	_apply_difficulty()
	health = max_health
	_home_position = global_position
	_arena_pos = global_position
	_last_known_position = global_position
	set_collision_mask_value(3, true)

	if vision_ray != null:
		vision_ray.enabled = true
		vision_ray.collision_mask = 1

	_aura_layer = BossLayer.new()
	_aura_layer.aura = true
	_aura_layer.boss = self
	_aura_layer.name = "Aura"
	add_child(_aura_layer)
	move_child(_aura_layer, 0)

	_fx_layer = BossLayer.new()
	_fx_layer.boss = self
	_fx_layer.name = "Telegraphs"
	_fx_layer.top_level = true
	_fx_layer.z_index = 40
	add_child(_fx_layer)

	state = State.ATACAR
	awareness = 1.0
	_mode = Mode.INTRO
	_mode_time = 0.0
	var player := _closest_player()
	if player != null:
		_face(player.global_position)

	Global.set_boss(self)
	_emit_health()
	if not Global.cutscene_active:
		_radio_lines(Story.BOSS_INTRO)
		Global.show_message("¡%s!" % Story.BOSS_NAME)
	_intro_fx()


func _apply_difficulty() -> void:
	max_health *= Settings.diff("health")
	speed *= lerpf(1.0, Settings.diff("speed"), 0.5)
	spread_degrees *= Settings.diff("spread")
	_cd_mult = lerpf(1.0, Settings.diff("fire_rate"), 0.5)
	var tele: Array[float] = [1.2, 1.0, 0.9]
	_tele_mult = tele[clampi(Settings.difficulty, 0, 2)]
	var dmg: Array[float] = [1.0, 1.0, 0.85]
	_dmg_scale = dmg[clampi(Settings.difficulty, 0, 2)]


func apply_variant(_v: int) -> void:
	pass


func variant_key() -> String:
	return "jefe"


func alert_to(_point: Vector2) -> void:
	if _mode == Mode.DORMANT and Global.health > 0.0 and _mode_time > 1.0:
		_wake()


func _physics_process(delta: float) -> void:
	_fx_time += delta
	_immune_note = maxf(0.0, _immune_note - delta)
	_shield_flash = maxf(0.0, _shield_flash - delta)
	if state == State.MUERTO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_glow(delta)
		return

	if _cutscene_hold():
		_update_glow(delta)
		return

	_mode_time += delta
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_stomp_cd = maxf(0.0, _stomp_cd - delta)
	var player := _closest_player()
	var player_ok := player != null and Global.health > 0.0

	match _mode:
		Mode.INTRO:
			_tick_intro(delta, player)
		Mode.TRANSITION:
			_tick_transition(delta, player)
		Mode.DORMANT:
			_tick_dormant(delta, player, player_ok)
		Mode.FIGHT:
			if player_ok:
				_tick_fight(delta, player)
			else:
				_enter_dormant()

	move_and_slide()
	if _action == Action.DASH:
		_check_dash_contact(player)
	elif _mode == Mode.FIGHT or _mode == Mode.DORMANT:
		_check_stuck(delta)
	_update_glow(delta)


func _tick_intro(delta: float, player: Node2D) -> void:
	_brake(delta)
	if player != null:
		_face_smooth(player.global_position, delta)
	if not _roared and _mode_time >= INTRO_TIME * 0.55:
		_roared = true
		_shake(8.0)
		_shockwave(global_position, COLOR_DANGER, 120.0, 0.55, 5.0)
	if _mode_time >= INTRO_TIME:
		if Global.health > 0.0:
			_start_fight(0.5)
		else:
			_enter_dormant()


func finish_intro() -> void:
	if _mode == Mode.INTRO:
		_mode_time = maxf(_mode_time, INTRO_TIME * 0.5)


func _start_fight(first_delay: float) -> void:
	_mode = Mode.FIGHT
	_mode_time = 0.0
	_action = Action.NONE
	_action_time = 0.0
	_action_cd = first_delay
	_strafe_point = NO_POINT
	state = State.ATACAR
	awareness = 1.0


func _enter_dormant() -> void:
	_cancel_action()
	_mode = Mode.DORMANT
	_mode_time = 0.0
	_strafe_point = NO_POINT
	_target = null
	state = State.VOLVER
	awareness = 0.0


func _wake() -> void:
	if _mode != Mode.DORMANT:
		return
	_start_fight(0.9)
	_shake(4.0)
	_shockwave(global_position, COLOR_DANGER, 80.0, 0.4, 4.0)


func _tick_dormant(delta: float, player: Node2D, player_ok: bool) -> void:
	if global_position.distance_to(_arena_pos) > 14.0:
		_go_to(_arena_pos, delta, speed * 0.8)
	else:
		_brake(delta)
		state = State.PATRULLA
	if not player_ok or Global.grace_time > 0.0 or _mode_time < 1.0:
		return
	if global_position.distance_to(player.global_position) <= WAKE_RANGE and not _wall_between(player.global_position):
		_wake()


func _begin_transition(next_phase: int) -> void:
	_cancel_action()
	phase = clampi(next_phase, 0, 2)
	_mode = Mode.TRANSITION
	_mode_time = 0.0
	_summoned = false
	_emit_health()
	if phase < Story.BOSS_PHASE_LINES.size():
		_radio_lines(Story.BOSS_PHASE_LINES[phase])
	Global.show_message("¡EL CONTRATISTA PIDE REFUERZOS!" if phase == 1 else "¡EL CONTRATISTA ESTÁ FURIOSO!")
	_shake(7.0)
	_shockwave(global_position, COLOR_SHIELD, 110.0, 0.5, 5.0)
	_pulse_light(Color(1.0, 0.18, 0.12), 0.8, 0.5)
	_burst_fx(global_position, Color(1.0, 0.3, 0.15, 1.0), 26, 120.0, 300.0, 0.5)


func _tick_transition(delta: float, player: Node2D) -> void:
	_brake(delta)
	if player != null:
		_face_smooth(player.global_position, delta)
	if not _summoned and _mode_time >= 0.45:
		_summoned = true
		_summon_wave(phase)
		call_deferred("_drop_supplies")
	if _mode_time >= TRANSITION_TIME:
		if Global.health > 0.0:
			_start_fight(0.7)
		else:
			_enter_dormant()


func _tick_fight(delta: float, player: Node2D) -> void:
	if Global.grace_time > 0.0 and _action == Action.NONE and global_position.distance_to(player.global_position) > WAKE_RANGE and _wall_between(player.global_position):
		_enter_dormant()
		return
	_target = player
	_last_known_position = player.global_position
	awareness = 1.0
	state = State.ATACAR
	var spd := speed * _speed_mult()
	_action_time += delta
	match _action:
		Action.NONE:
			_strafe(delta, player, spd)
			_action_cd -= delta
			if _action_cd <= 0.0:
				_start_action(_pick_action(player), player)
		Action.BURST:
			_tick_burst(delta, player, spd)
		Action.FAN:
			_tick_fan(delta, player)
		Action.RING:
			_tick_ring(delta)
		Action.DASH_AIM:
			_tick_dash_aim(delta)
		Action.DASH:
			_tick_dash(delta)
		Action.RECOVER:
			_tick_recover(delta)
		Action.STOMP:
			_tick_stomp(delta, player)


func _speed_mult() -> float:
	if phase >= 2:
		return 1.2
	if phase == 1:
		return 1.06
	return 1.0


func _pick_action(player: Node2D) -> int:
	var d := global_position.distance_to(player.global_position)
	var los := not _wall_between(player.global_position)
	if not los:
		if phase >= 2 and d < 170.0 and _last_action != Action.RING:
			return Action.RING
		return Action.NONE
	if d < CLOSE_RANGE:
		if _stomp_cd <= 0.0:
			return Action.STOMP
		if phase >= 2 and _last_action != Action.RING and randf() < 0.5:
			return Action.RING
		_strafe_point = _retreat_point(player.global_position)
		_strafe_timer = 0.8
		return Action.NONE
	var dash_ok := _dash_cd <= 0.0 and d > 60.0 and d < 340.0
	if dash_ok:
		dash_ok = _dash_reach((player.global_position - global_position).normalized()) >= minf(d, 90.0)
	var options: Array[int] = []
	var weights: Array[float] = []
	match phase:
		0:
			options = [Action.BURST]
			weights = [1.0]
		1:
			options = [Action.BURST, Action.FAN]
			weights = [1.0, 1.0]
			if dash_ok:
				options.append(Action.DASH_AIM)
				weights.append(0.9)
		_:
			options = [Action.RING, Action.BURST, Action.FAN]
			weights = [1.1, 0.9, 0.6]
			if dash_ok:
				options.append(Action.DASH_AIM)
				weights.append(0.7)
	var total := 0.0
	for i in range(options.size()):
		if options[i] == _last_action and options.size() > 1:
			weights[i] *= 0.35
		total += weights[i]
	var roll := randf() * total
	for i in range(options.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[options.size() - 1]


func _start_action(a: int, player: Node2D) -> void:
	if a == Action.NONE:
		_action_cd = 0.3
		return
	_action = a
	_action_time = 0.0
	_last_action = a
	match a:
		Action.BURST:
			_shots_left = 4 if phase >= 2 else 3
			_shot_cd = 0.0
		Action.FAN:
			_fan_fired = false
			_fan_second = phase >= 2
		Action.RING:
			_rings_total = 3 if phase >= 2 else 2
			_rings_fired = 0
		Action.STOMP:
			_stomp_done = false
			_stomp_cd = 3.2
		Action.DASH_AIM:
			_dash_dir = (player.global_position - global_position).normalized()
			if _dash_dir == Vector2.ZERO:
				_dash_dir = Vector2.RIGHT.rotated(global_rotation)
			_dash_len = _dash_reach(_dash_dir)
			_dash_hit = false
			global_rotation = _dash_dir.angle()


func _end_action(cooldown: float) -> void:
	_action = Action.NONE
	_action_time = 0.0
	_action_cd = cooldown * _cd_mult * (0.8 if phase >= 2 else 1.0)


func _cancel_action() -> void:
	_action = Action.NONE
	_action_time = 0.0
	velocity *= 0.3


func _tick_burst(delta: float, player: Node2D, spd: float) -> void:
	_strafe(delta, player, spd * 0.45)
	var aim := BURST_AIM * _tele_mult
	if _action_time < aim - BURST_LOCK:
		_burst_angle = (player.global_position - global_position).angle()
	if _action_time < aim:
		global_rotation = _burst_angle
		return
	global_rotation = _burst_angle
	_shot_cd -= delta
	if _shot_cd <= 0.0 and _shots_left > 0:
		var index := (4 if phase >= 2 else 3) - _shots_left
		_shots_left -= 1
		_shot_cd = BURST_GAP
		var sweep := (float(index) - 1.0) * 3.5 * _burst_sweep
		var angle := _burst_angle + deg_to_rad(sweep + randf_range(-spread_degrees, spread_degrees))
		_spawn_bullet(angle, 0.74, 0.6 * _dmg_scale, COLOR_BURST, 1.25)
		if visuals != null:
			visuals.fire()
	if _shots_left <= 0:
		_burst_sweep = -_burst_sweep
		_end_action(randf_range(1.4, 1.9) if phase == 0 else randf_range(1.1, 1.5))


func _tick_fan(delta: float, player: Node2D) -> void:
	_brake(delta)
	var aim := FAN_AIM * _tele_mult
	if _action_time < aim - FAN_LOCK:
		_face(player.global_position)
	if not _fan_fired and _action_time >= aim:
		_fan_fired = true
		_fire_fan(0.0)
		if not _fan_second:
			_end_action(randf_range(1.0, 1.4))
		return
	if _fan_fired and _fan_second and _action_time >= aim + 0.3:
		_fire_fan(FAN_DEGREES / float(FAN_PELLETS - 1) * 0.5)
		_end_action(randf_range(1.0, 1.4))


func _fire_fan(offset_deg: float) -> void:
	for i in range(FAN_PELLETS):
		var t := float(i) / float(FAN_PELLETS - 1)
		var angle := global_rotation + deg_to_rad(lerpf(-FAN_DEGREES * 0.5, FAN_DEGREES * 0.5, t) + offset_deg)
		_spawn_bullet(angle, 0.72, 0.58 * _dmg_scale, COLOR_FAN, 0.95)
	if visuals != null:
		visuals.fire()
	_shake(2.5)


func _tick_ring(delta: float) -> void:
	_brake(delta)
	var charge := RING_CHARGE * _tele_mult
	if _action_time < charge:
		return
	var since := _action_time - charge
	if _rings_fired < _rings_total and since >= float(_rings_fired) * RING_GAP:
		_fire_ring(_rings_fired)
		_rings_fired += 1
	if _rings_fired >= _rings_total and since >= float(_rings_total - 1) * RING_GAP + 0.25:
		_ring_spin += 0.37
		_end_action(1.25)


func _fire_ring(index: int) -> void:
	var step := TAU / float(RING_BULLETS)
	var base := _ring_spin + (step * 0.5 if index % 2 == 1 else 0.0) + 0.12 * float(index)
	for i in range(RING_BULLETS):
		var angle := base + step * float(i)
		_spawn_bullet(angle, 0.38, 0.68 * _dmg_scale, COLOR_RING, 1.35, global_position + Vector2.RIGHT.rotated(angle) * 22.0)
	if visuals != null:
		visuals.fire()
	_shake(3.0)
	_shockwave(global_position, COLOR_RING, 46.0, 0.25, 3.0)


func _dash_reach(dir: Vector2) -> float:
	var reach := DASH_SPEED * DASH_TIME * (1.08 if phase >= 2 else 1.0)
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + dir * (reach + 16.0), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		reach = maxf(0.0, from.distance_to(hit["position"]) - 16.0)
	return reach


func _tick_dash_aim(delta: float) -> void:
	_brake(delta)
	global_rotation = _dash_dir.angle()
	if _action_time >= DASH_AIM_TIME * _tele_mult:
		_action = Action.DASH
		_action_time = 0.0
		_dash_hit = false
		_shake(3.0)


func _tick_dash(_delta: float) -> void:
	global_rotation = _dash_dir.angle()
	velocity = _dash_dir * DASH_SPEED * (1.08 if phase >= 2 else 1.0)
	if _action_time >= DASH_TIME:
		_finish_dash(false)
	elif _action_time > 0.08 and get_real_velocity().length() < DASH_SPEED * 0.25:
		_finish_dash(true)


func _finish_dash(hit_wall: bool) -> void:
	velocity *= 0.15
	_dash_cd = 3.6
	_action = Action.RECOVER
	_action_time = 0.0
	_recover_time = RECOVER_TIME + (0.4 if hit_wall else 0.0)
	if hit_wall:
		_shake(5.0)
		_shockwave(global_position + _dash_dir * 14.0, COLOR_SHIELD, 50.0, 0.3, 4.0)
		FloatingText.spawn(get_tree().current_scene, global_position + Vector2(0, -34), "ATURDIDO", UIStyle.OBJECTIVE, 11)


func _tick_stomp(delta: float, player: Node2D) -> void:
	_brake(delta)
	var charge := STOMP_CHARGE * _tele_mult
	if not _stomp_done and _action_time >= charge:
		_stomp_done = true
		_shake(6.0)
		_shockwave(global_position, COLOR_DANGER, STOMP_RADIUS + 8.0, 0.3, 6.0)
		_burst_fx(global_position, Color(1.0, 0.3, 0.2, 1.0), 24, 140.0, 260.0, 0.35)
		if Global.health > 0.0 and global_position.distance_to(player.global_position) <= STOMP_RADIUS and not _wall_between(player.global_position):
			if player.has_method("take_damage"):
				player.take_damage(STOMP_DAMAGE * Settings.enemy_damage_mult() * _dmg_scale)
	if _stomp_done and _action_time >= charge + 0.3:
		_strafe_point = _retreat_point(player.global_position)
		_strafe_timer = 0.9
		_end_action(0.5)


func _retreat_point(p: Vector2) -> Vector2:
	var away := global_position - p
	var base_angle := away.angle() if away.length() > 1.0 else randf() * TAU
	for r in [140.0, 110.0, 90.0]:
		for i in range(7):
			var angle := base_angle + (float(i) - 3.0) * 0.35
			var c: Vector2 = p + Vector2.RIGHT.rotated(angle) * float(r)
			if _is_walkable(c) and not _segment_blocked(global_position, c):
				return c
	return _pick_strafe_point(p)


func _tick_recover(delta: float) -> void:
	_brake(delta)
	if _action_time >= _recover_time:
		_end_action(0.6)


func _check_dash_contact(player: Node2D) -> void:
	if _dash_hit or player == null or Global.health <= 0.0:
		return
	var touching := global_position.distance_to(player.global_position) < 30.0
	if not touching:
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			if col != null and col.get_collider() == player:
				touching = true
				break
	if not touching:
		return
	_dash_hit = true
	if player.has_method("take_damage"):
		player.take_damage(dash_damage * Settings.enemy_damage_mult() * _dmg_scale)
	_shake(9.0)
	_finish_dash(false)


func _strafe(delta: float, player: Node2D, spd: float) -> void:
	var p := player.global_position
	_face(p)
	if _wall_between(p):
		_strafe_point = NO_POINT
		_go_to(p, delta, spd, false)
		return
	_strafe_timer -= delta
	if _strafe_point == NO_POINT or _strafe_timer <= 0.0 or global_position.distance_to(_strafe_point) < 14.0:
		_strafe_point = _pick_strafe_point(p)
		_strafe_timer = randf_range(0.9, 1.6)
	if _go_to(_strafe_point, delta, spd * 0.85, false):
		_strafe_timer = minf(_strafe_timer, 0.15)


func _pick_strafe_point(p: Vector2) -> Vector2:
	var away := global_position - p
	var base_angle := away.angle() if away.length() > 1.0 else randf() * TAU
	var dist := lerpf(clampf(away.length(), STRAFE_MIN, STRAFE_MAX), randf_range(STRAFE_MIN, STRAFE_MAX), 0.6)
	if randf() < 0.25:
		_strafe_dir = -_strafe_dir
	var scales: Array[float] = [1.0, 0.72, 0.5]
	for k in scales:
		var r := maxf(dist * k, 80.0)
		for attempt in range(6):
			if attempt == 3:
				_strafe_dir = -_strafe_dir
			var angle := base_angle + randf_range(0.3, 0.85) * _strafe_dir
			var c := p + Vector2.RIGHT.rotated(angle) * r
			if _is_walkable(c) and _is_walkable(c.lerp(p, 0.5)) and not _segment_blocked(c, p):
				return c
	var dir := away.normalized() if away.length() > 1.0 else Vector2.RIGHT
	for r in [STRAFE_MIN, 110.0, 80.0]:
		var fallback: Vector2 = p + dir * float(r)
		if _is_walkable(fallback) and not _segment_blocked(fallback, p):
			return fallback
	return global_position


func _segment_blocked(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _on_stuck() -> void:
	_strafe_point = NO_POINT
	_strafe_dir = -_strafe_dir
	_repath_timer = 0.0


func _on_noise(_origin: Vector2, _radius: float, _investigate_at: Vector2) -> void:
	pass


func _summon_wave(p: int) -> void:
	var wave: Array[int] = []
	if p == 1:
		wave = [Variant.RAPIDO, Variant.RAPIDO]
	elif p >= 2:
		wave = [Variant.RAPIDO, Variant.SOLDADO]
	if Settings.difficulty <= 0 and wave.size() > 1:
		wave.resize(1)
	for v in wave:
		_summon(v)


func _summon(v: int) -> void:
	var player := _closest_player()
	var lv := _get_level()
	var minion: Node = null
	if lv != null and lv.has_method("spawn_reinforcement"):
		minion = lv.spawn_reinforcement(v, global_position)
	else:
		var scene := load(ENEMY_SCENE_PATH) as PackedScene
		if scene == null:
			return
		minion = scene.instantiate()
		minion.set("behavior", Behavior.PERSEGUIR)
		var holder := get_parent()
		if holder == null:
			holder = get_tree().current_scene
		var spot := _point_near(global_position, 40.0, 140.0)
		holder.add_child(minion)
		(minion as Node2D).global_position = spot
		if minion.has_method("apply_variant"):
			minion.apply_variant(v)
		if player != null and minion.has_method("alert_to"):
			minion.alert_to(player.global_position)
	if minion != null:
		call_deferred("_minion_fx", minion)


func _minion_fx(minion: Node) -> void:
	if not is_instance_valid(minion) or not minion.is_inside_tree():
		return
	var body := minion as Node2D
	if body == null:
		return
	_shockwave(body.global_position, COLOR_DANGER, 36.0, 0.4, 3.0)
	_burst_fx(body.global_position, Color(1.0, 0.25, 0.2, 1.0), 14, 60.0, 160.0, 0.4)


func _point_near(center: Vector2, min_d: float, max_d: float) -> Vector2:
	for i in range(14):
		var c := center + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(min_d, max_d)
		if _is_walkable(c) and not _segment_blocked(center, c):
			return c
	return center


func _drop_supplies() -> void:
	if state == State.MUERTO:
		return
	var scene := load(PICKUP_SCENE_PATH) as PackedScene
	if scene == null:
		return
	var holder: Node = _get_level()
	if holder == null:
		holder = get_parent()
	if holder == null:
		return
	var spot := global_position
	var player := _closest_player()
	if player != null:
		var mid := global_position.lerp(player.global_position, 0.5)
		if _is_walkable(mid):
			spot = mid
	var drops: Array[Vector2i] = []
	if Global.total_ammo(0) < 120:
		drops.append(Vector2i(0, 30))
	if Global.total_ammo(1) < 12:
		drops.append(Vector2i(3, 8))
	if Global.health < Global.max_health * 0.6:
		drops.append(Vector2i(1, 30))
	var offsets: Array[Vector2] = [Vector2.ZERO, Vector2(18, 10), Vector2(-18, 10), Vector2(0, -18)]
	for i in range(drops.size()):
		var at := spot + offsets[i % offsets.size()]
		if not _is_walkable(at) or _segment_blocked(spot, at):
			at = spot
		_place_pickup(scene, holder, drops[i].x, drops[i].y, at)


func _place_pickup(scene: PackedScene, holder: Node, kind: int, amount: int, spot: Vector2) -> void:
	var pickup := scene.instantiate() as Node2D
	if pickup == null:
		return
	pickup.set("kind", kind)
	pickup.set("amount", amount)
	var holder_2d := holder as Node2D
	pickup.position = holder_2d.to_local(spot) if holder_2d != null else spot
	holder.add_child(pickup)


func apply_bullet_hit(amount: float, from_direction: Vector2) -> void:
	if state == State.MUERTO:
		return
	if from_direction != Vector2.ZERO and _action != Action.DASH:
		velocity += from_direction.normalized() * knockback
	take_damage(amount)


func melee_hit(amount: float, from_pos: Vector2) -> void:
	if state == State.MUERTO:
		return
	_killed_by_melee = true
	if _action != Action.DASH:
		velocity += (global_position - from_pos).normalized() * knockback * 2.0
	take_damage(amount)
	if state != State.MUERTO:
		_killed_by_melee = false


func is_invulnerable() -> bool:
	return _mode == Mode.INTRO or _mode == Mode.TRANSITION


func take_damage(amount: float) -> void:
	if state == State.MUERTO or amount <= 0.0:
		return
	if is_invulnerable():
		_immune_feedback()
		return
	health -= amount
	_flash_hit()
	if phase < PHASE_MARKS.size():
		var floor_hp := max_health * PHASE_MARKS[phase]
		if health <= floor_hp:
			health = floor_hp
			_begin_transition(phase + 1)
			return
	_emit_health()
	if health <= 0.0:
		die()
		return
	if _mode == Mode.DORMANT:
		_wake()


func _immune_feedback() -> void:
	_shield_flash = 0.18
	if _immune_note <= 0.0:
		_immune_note = 0.5
		FloatingText.spawn(get_tree().current_scene, global_position + Vector2(0, -34), "INMUNE", UIStyle.OBJECTIVE, 11)


func die() -> void:
	if state == State.MUERTO:
		return
	_cancel_action()
	_set_state(State.MUERTO)
	_mode = Mode.DEAD
	health = 0.0
	velocity = Vector2.ZERO
	_emit_health()

	Engine.time_scale = SLOW_MO_SCALE
	var timer := get_tree().create_timer(SLOW_MO_TIME, true, false, true)
	timer.timeout.connect(Callable(Engine, "set").bind("time_scale", 1.0))

	Global.last_kill_weapon = 2 if _killed_by_melee else Global.current_weapon
	Global.last_kill_silent = false
	var earned := Global.add_kill(BOSS_POINTS)
	FloatingText.spawn(get_tree().current_scene, global_position + Vector2(0, -30), "+%d" % earned, UIStyle.OBJECTIVE, 22)

	_death_fx()
	Global.clear_boss()
	if not cinematic_death:
		_radio_lines(Story.BOSS_DEFEAT)
	Global.enemy_killed.emit(global_position)

	if visuals != null:
		visuals.set_dead(true)
	else:
		AnimNames.play(anim, AnimNames.DEAD)
	set_collision_layer_value(3, false)
	set_collision_mask_value(2, false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	_send_corpse_back()


func _exit_tree() -> void:
	if _mode == Mode.DEAD and Engine.time_scale < 1.0:
		Engine.time_scale = 1.0


func _emit_health() -> void:
	Global.boss_health_changed.emit(maxf(health, 0.0), max_health, phase)


func _radio_lines(lines: Array) -> void:
	for line in lines:
		if line is Array and line.size() >= 2:
			Global.radio(String(line[0]), String(line[1]))


func _shake(amount: float) -> void:
	var player := _closest_player()
	if player != null and player.has_method("add_shake"):
		player.add_shake(amount)


func _pulse_light(color: Color, strength: float, duration: float) -> void:
	var lighting := get_tree().get_first_node_in_group("level_lighting")
	if lighting != null and lighting.has_method("pulse"):
		lighting.pulse(color, strength, duration)


func _shockwave(at: Vector2, color: Color, max_radius: float, duration: float, width: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var wave := Shockwave.new()
	wave.color = color
	wave.width = width
	scene_root.add_child(wave)
	wave.global_position = at
	wave.start(max_radius, duration)


func _burst_fx(at: Vector2, color: Color, count: int, vmin: float, vmax: float, life: float) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var p := CPUParticles2D.new()
	p.light_mask = 0
	p.z_index = 46
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = life
	p.local_coords = false
	p.gravity = Vector2.ZERO
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.damping_min = 120.0
	p.damping_max = 260.0
	p.color = color
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	scene_root.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


func _intro_fx() -> void:
	_shake(6.0)
	_pulse_light(Color(1.0, 0.1, 0.1), 0.7, 0.6)
	_shockwave(global_position, COLOR_DANGER, 90.0, 0.6, 5.0)
	_burst_fx(global_position, Color(1.0, 0.15, 0.15, 1.0), 36, 80.0, 260.0, 0.6)
	if anim != null:
		anim.modulate = Color(4.0, 0.6, 0.6, 1.0)
		_intro_tween = create_tween()
		_intro_tween.tween_property(anim, "modulate", Color.WHITE, 0.9)


func _death_fx() -> void:
	_shake(16.0)
	_pulse_light(Color(1.0, 0.25, 0.2), 1.0, 0.9)
	_shockwave(global_position, COLOR_DANGER, 170.0, 0.9, 7.0)
	_shockwave(global_position, Color(1.0, 0.9, 0.7), 90.0, 0.5, 4.0)
	_burst_fx(global_position, Color(1.0, 0.18, 0.12, 1.0), 70, 150.0, 460.0, 0.9)
	_burst_fx(global_position, Color(1.0, 0.85, 0.6, 1.0), 24, 60.0, 220.0, 0.6)
	_burst_fx(global_position, Color(0.12, 0.08, 0.1, 0.8), 22, 20.0, 90.0, 1.2)


func _update_glow(delta: float) -> void:
	if _mat == null:
		return
	var target := 0.16 + 0.1 * float(phase)
	match _action:
		Action.BURST:
			if _action_time < BURST_AIM * _tele_mult:
				target = 0.55
		Action.FAN:
			target = 0.65
		Action.RING:
			target = 0.8
		Action.DASH_AIM:
			target = 0.75 + 0.25 * sin(_fx_time * 40.0)
		Action.RECOVER:
			target = 0.02
		Action.STOMP:
			target = 0.9 if not _stomp_done else 0.25
	if is_invulnerable():
		target = 0.6 + 0.25 * sin(_fx_time * 20.0)
	if state == State.MUERTO:
		target = 0.0
	_glow = move_toward(_glow, target, delta * 4.0)
	_mat.set_shader_parameter("emission_energy_multiplier", clampf(_glow * _glow_scale, 0.0, 5.0))


func draw_aura(c: Node2D) -> void:
	if state == State.MUERTO:
		return
	var pulse := 0.5 + 0.5 * sin(_fx_time * (3.0 + 2.5 * float(phase)))
	var r := 20.0 + 2.5 * pulse
	c.draw_circle(Vector2.ZERO, r + 5.0, Color(0.55, 0.02, 0.05, 0.16 + 0.07 * float(phase)))
	c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.12, 0.12, 0.3 + 0.3 * pulse), 2.0)


func draw_fx(c: Node2D) -> void:
	if state == State.MUERTO:
		return
	var t := _fx_time
	var aim_dir := Vector2.RIGHT.rotated(global_rotation)
	match _action:
		Action.BURST:
			var aim := BURST_AIM * _tele_mult
			if _action_time < aim:
				var k := clampf(_action_time / aim, 0.0, 1.0)
				var tip := aim_dir * muzzle_distance
				var locked := _action_time >= aim - BURST_LOCK
				c.draw_circle(tip, 3.0 + 5.0 * k, Color(COLOR_BURST, 0.35 + 0.5 * k))
				if locked:
					c.draw_line(tip, tip + aim_dir * 130.0, Color(COLOR_BURST, 0.9 if fmod(t * 30.0, 2.0) < 1.0 else 0.5), 2.5)
				else:
					c.draw_line(tip, tip + aim_dir * (40.0 + 70.0 * k), Color(COLOR_BURST, 0.2 + 0.3 * k), 2.0)
		Action.FAN:
			var aim := FAN_AIM * _tele_mult
			if not _fan_fired or (_fan_second and _action_time < aim + 0.3):
				var k := clampf(_action_time / aim, 0.0, 1.0)
				var locked := _action_time >= aim - FAN_LOCK
				var length := 210.0
				var pts := PackedVector2Array([Vector2.ZERO])
				for i in range(9):
					var a := global_rotation + deg_to_rad(lerpf(-FAN_DEGREES * 0.5, FAN_DEGREES * 0.5, float(i) / 8.0))
					pts.append(Vector2.RIGHT.rotated(a) * length)
				c.draw_colored_polygon(pts, Color(COLOR_FAN, 0.06 + 0.16 * k))
				var edge_alpha := 0.25 + 0.6 * k
				if locked and fmod(t * 24.0, 2.0) < 1.0:
					edge_alpha = 1.0
				c.draw_line(Vector2.ZERO, pts[1], Color(COLOR_FAN, edge_alpha), 2.0)
				c.draw_line(Vector2.ZERO, pts[pts.size() - 1], Color(COLOR_FAN, edge_alpha), 2.0)
		Action.RING:
			var charge := RING_CHARGE * _tele_mult
			if _action_time < charge:
				var k := clampf(_action_time / charge, 0.0, 1.0)
				c.draw_arc(Vector2.ZERO, 22.0 + 60.0 * (1.0 - k), 0.0, TAU, 48, Color(COLOR_RING, 0.3 + 0.6 * k), 2.0 + 3.0 * k)
				var step := TAU / float(RING_BULLETS)
				for i in range(RING_BULLETS):
					var dot := Vector2.RIGHT.rotated(_ring_spin + step * float(i)) * (30.0 + 10.0 * k)
					c.draw_circle(dot, 1.5 + 1.8 * k, Color(COLOR_RING, 0.3 + 0.7 * k))
		Action.DASH_AIM:
			var aim := DASH_AIM_TIME * _tele_mult
			var k := clampf(_action_time / aim, 0.0, 1.0)
			var end := _dash_dir * _dash_len
			c.draw_line(Vector2.ZERO, end, Color(COLOR_DANGER, 0.1 + 0.22 * k), 28.0)
			var blink := k < 0.6 or fmod(t * 18.0, 2.0) < 1.0
			c.draw_line(Vector2.ZERO, end, Color(1.0, 0.35, 0.3, (0.45 + 0.55 * k) if blink else 0.25), 2.5)
			var side := _dash_dir.orthogonal() * 7.0
			for i in range(3):
				var f := fmod(0.3 + 0.22 * float(i) + t * 1.6, 1.0)
				var at := end * f
				c.draw_line(at - _dash_dir * 6.0 + side, at, Color(COLOR_DANGER, 0.7 * k), 2.0)
				c.draw_line(at - _dash_dir * 6.0 - side, at, Color(COLOR_DANGER, 0.7 * k), 2.0)
			c.draw_circle(end, 5.0 + 5.0 * k, Color(COLOR_DANGER, 0.25 + 0.35 * k))
		Action.DASH:
			c.draw_line(Vector2.ZERO, -_dash_dir * 46.0, Color(COLOR_DANGER, 0.45), 18.0)
			c.draw_line(Vector2.ZERO, -_dash_dir * 30.0, Color(1.0, 0.7, 0.6, 0.5), 5.0)
		Action.STOMP:
			if not _stomp_done:
				var charge := STOMP_CHARGE * _tele_mult
				var k := clampf(_action_time / charge, 0.0, 1.0)
				c.draw_circle(Vector2.ZERO, STOMP_RADIUS, Color(COLOR_DANGER, 0.05 + 0.14 * k))
				c.draw_arc(Vector2.ZERO, STOMP_RADIUS, 0.0, TAU, 56, Color(COLOR_DANGER, 0.4 + 0.6 * k), 2.0 + 1.5 * k)
				c.draw_arc(Vector2.ZERO, STOMP_RADIUS * k, 0.0, TAU, 48, Color(1.0, 0.5, 0.4, 0.3 + 0.5 * k), 2.0)
		Action.RECOVER:
			for i in range(3):
				var a := t * 6.0 + TAU * float(i) / 3.0
				c.draw_circle(Vector2(cos(a) * 11.0, -32.0 + sin(a) * 4.0), 2.2, COLOR_SHIELD)
	if is_invulnerable() or _shield_flash > 0.0:
		var pulse := 0.5 + 0.5 * sin(t * 12.0)
		var alpha := 0.35 + 0.3 * pulse + (0.35 if _shield_flash > 0.0 else 0.0)
		var hexa := PackedVector2Array()
		for i in range(7):
			hexa.append(Vector2.RIGHT.rotated(TAU * float(i) / 6.0 + t * 0.8) * 30.0)
		c.draw_polyline(hexa, Color(COLOR_SHIELD, clampf(alpha, 0.0, 1.0)), 2.5)
		c.draw_circle(Vector2.ZERO, 29.0, Color(COLOR_SHIELD, 0.06 + 0.06 * pulse))
