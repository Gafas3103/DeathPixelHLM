extends Node2D

const PauseMenu := preload("res://Scripts/UI/pause_menu.gd")
const KeyItemScene := preload("res://Scenes/Items/KeyItem.tscn")
const PickupScene := preload("res://Scenes/Items/Pickup.tscn")
const NoteItemScene := preload("res://Scenes/NoteItem.tscn")
const Story := preload("res://Scripts/story.gd")
const Cutscenes := preload("res://Scripts/cutscenes.gd")
const NO_CELL := Vector2i(-999999, -999999)

const ENEMY_PATH := "res://Scenes/Enemy.tscn"
const BOSS_PATH := "res://Scenes/Boss.tscn"
const LIGHTING_PATH := "res://Scripts/lighting.gd"
const BRIEFING_PATH := "res://Scripts/UI/briefing.gd"

const VARIANT_IDS := {"soldado": 0, "pesado": 1, "tirador": 2, "rapido": 3}
const VARIANT_ORDER: Array[String] = ["tirador", "rapido", "pesado"]
const VARIANT_BEHAVIORS := {"tirador": [0, 1], "rapido": [2, 1]}
const BEHAVIOR_PERSEGUIR := 2
const BEHAVIOR_INERTE := 3

const TIME_MULT: Array[float] = [1.3, 1.0, 0.8]
const ALARM_TIME := 80.0
const ALARM_FIRST_WAVE := 6.0
const ALARM_WAVE_TIME := 18.0
const ALARM_HEAVY_WAVE_TIME := 9.0
const MAX_REINFORCEMENTS := 5
const HUNT_TIME := 28.0
const REINFORCE_MIN_DIST := 260.0
const REINFORCE_MAX_DIST := 640.0

const NOTE_OBJECTIVE := "RECOGE LA LLAVE Y LEE LA NOTA"
const BOSS_OBJECTIVE := "DERROTA AL CONTRATISTA"

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIRS8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]


class SpawnRing extends Node2D:
	var color: Color = Color("#EF3E4A")
	var _t: float = 0.0

	func _init() -> void:
		z_index = 50
		light_mask = 0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= 0.6:
			queue_free()

	func _draw() -> void:
		var k := _t / 0.6
		draw_arc(Vector2.ZERO, 6.0 + k * 26.0, 0.0, TAU, 32, Color(color, 1.0 - k), 3.0 * (1.0 - k) + 1.0)
		draw_circle(Vector2.ZERO, 10.0 * (1.0 - k), Color(color, 0.35 * (1.0 - k)))


@export var level_index: int = 0
@export var objective_start: String = "ELIMINA A TODOS LOS ENEMIGOS"
@export var objective_key_dropped: String = "RECOGE LA LLAVE"
@export var objective_with_key: String = "ABRE LA PUERTA"
@export var objective_door_open: String = "LLEGA A LA SALIDA"
@export var tile_size: int = 16
@export var tutorial_mode: bool = false
@export var drop_note_on_clear: bool = false

@export_group("Botín de enemigos")
@export_range(0.0, 1.0, 0.05) var loot_chance: float = 0.65
@export var ammo_drop_min: int = 12
@export var ammo_drop_max: int = 20
@export var health_drop_amount: int = 35

var solid_rects: Array[Rect2] = []
var map_bounds: Rect2 = Rect2()
var twist: String = ""
var mood: String = ""

var _key_dropped: bool = false
var _astar: AStarGrid2D = null
var _grid_rect: Rect2i = Rect2i()

var _data: Dictionary = {}
var _chapter: Dictionary = {}
var _lighting = null
var _briefing = null
var _briefing_open: bool = false
var _begun: bool = false
var _twists_over: bool = false
var _door_radio_done: bool = false

var _boss_level: bool = false
var _boss_spawned: bool = false
var _boss_pending: bool = false
var _outro_started: bool = false

var _alarm_on: bool = false
var _alarm_used: bool = false
var _alarm_expired: bool = false
var _alarm_left: float = 0.0
var _wave_timer: float = 0.0
var _hunt_timer: float = 0.0

var _enemy_scene: PackedScene = null
var _reinforcements: Array[Node] = []
var _spawn_count: int = 0
var _reach: Dictionary = {}
var _reach_cells: Array[Vector2i] = []
var _reach_dirty: bool = true


func _ready() -> void:
	add_to_group("level")
	GameManager.begin_level(level_index)
	_build_grid()

	add_child(PauseMenu.new())
	if tutorial_mode:
		return

	_data = GameManager.level_data(level_index)
	_chapter = Story.chapter(level_index)
	twist = String(_data.get("twist", ""))
	mood = String(_data.get("mood", ""))
	_boss_level = GameManager.is_boss_level(level_index)
	_boss_spawned = not get_tree().get_nodes_in_group("boss").is_empty()

	Global.lights_out = twist == "apagon"
	_create_lighting()
	_assign_variants()

	Global.key_collected.connect(_on_key_collected)
	Global.door_opened.connect(_on_door_opened)
	Global.enemy_killed.connect(_on_enemy_killed)
	Global.boss_spawned.connect(_on_boss_spawned)
	Global.boss_defeated.connect(_on_boss_defeated)

	if get_tree().get_nodes_in_group("Enemies").is_empty():
		_key_dropped = true
		Global.set_objective("ENCUENTRA LA LLAVE")
	else:
		Global.set_objective(objective_start)

	if GameManager.trailer_mode:
		_begin()
	elif GameManager.take_briefing():
		call_deferred("_start_intro")
	else:
		_begin()


func _start_intro() -> void:
	if not is_inside_tree():
		return
	await Cutscenes.chapter_intro(self, level_index)
	if not is_inside_tree() or _begun:
		return
	if not _open_briefing():
		_begin()


func _process(delta: float) -> void:
	if tutorial_mode:
		return
	if not _begun:
		if _briefing_open and not is_instance_valid(_briefing):
			_begin()
		return
	if _twists_over or Global.cutscene_active:
		return
	if not Global.level_active:
		end_twists()
		return
	if Global.health <= 0.0:
		return

	if _alarm_on:
		_update_alarm(delta)

	if twist == "caceria":
		_hunt_timer -= delta
		if _hunt_timer <= 0.0:
			_hunt_timer = HUNT_TIME * _time_mult()
			_hunt_pulse()


func _begin() -> void:
	if _begun or not is_inside_tree() or is_queued_for_deletion():
		return
	_begun = true
	_briefing_open = false
	_briefing = null
	Global.level_active = true
	if Global.objective != "":
		Global.objective_changed.emit(Global.objective)
	if GameManager.trailer_mode:
		return
	_radio_lines(_chapter.get("radio_start", []))
	_radio_lines(Story.TWIST_START.get(twist, []))
	if twist == "caceria":
		_hunt_timer = HUNT_TIME * _time_mult()
	_intro_hints()


func end_twists() -> void:
	_twists_over = true
	_stop_alarm()


func _time_mult() -> float:
	return TIME_MULT[clampi(Settings.difficulty, 0, TIME_MULT.size() - 1)]


func _radio_lines(lines: Variant) -> void:
	if not (lines is Array):
		return
	for line in lines:
		if line is Array and line.size() >= 2:
			Global.radio(String(line[0]), String(line[1]))


func _load_script(path: String) -> GDScript:
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	return script


func _create_lighting() -> void:
	if mood == "":
		return
	var script := _load_script(LIGHTING_PATH)
	if script == null:
		return
	var node = script.new()
	if not (node is Node):
		return
	node.name = "Lighting"
	add_child(node)
	_lighting = node
	if node.has_method("setup"):
		node.setup(mood)


func _lighting_call(method: String, args: Array = []) -> void:
	if _lighting == null or not is_instance_valid(_lighting):
		return
	if _lighting.has_method(method):
		_lighting.callv(method, args)


func _pulse(color: Color, strength: float, duration: float) -> void:
	_lighting_call("pulse", [color, strength, duration])


func _open_briefing() -> bool:
	var script := _load_script(BRIEFING_PATH)
	if script == null:
		return false
	var b = script.new()
	if not (b is Node):
		return false
	if not b.has_signal("closed"):
		b.free()
		return false
	b.set("level_index", level_index)
	b.connect("closed", _begin)
	_briefing = b
	_briefing_open = true
	add_child(b)
	return true


func _assign_variants() -> void:
	var quotas: Variant = _data.get("variants", {})
	if not (quotas is Dictionary) or quotas.is_empty():
		return

	var remaining := {}
	for k in quotas:
		remaining[String(k)] = int(quotas[k])

	var pool: Array[Node] = []
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.is_in_group("boss") or not e.has_method("apply_variant"):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		if int(e.get("behavior")) == BEHAVIOR_INERTE:
			continue
		var current := _variant_key_of(e)
		if current != "soldado":
			if remaining.has(current):
				remaining[current] = int(remaining[current]) - 1
			continue
		pool.append(e)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (level_index + 3) + 101

	var order: Array[String] = []
	order.append_array(VARIANT_ORDER)
	for k in remaining:
		if not order.has(k):
			order.append(k)

	for key in order:
		if key == "soldado" or not VARIANT_IDS.has(key):
			continue
		var liked: Array = VARIANT_BEHAVIORS.get(key, [])
		for i in range(int(remaining.get(key, 0))):
			if pool.is_empty():
				return
			var candidates: Array[Node] = []
			for e in pool:
				if liked.is_empty() or liked.has(int(e.get("behavior"))):
					candidates.append(e)
			if candidates.is_empty():
				candidates = pool
			var pick: Node = candidates[rng.randi_range(0, candidates.size() - 1)]
			pool.erase(pick)
			pick.apply_variant(int(VARIANT_IDS[key]))


func _variant_key_of(e: Node) -> String:
	if e.has_method("variant_key"):
		return String(e.variant_key())
	var v: Variant = e.get("variant")
	if v == null:
		return "soldado"
	for k in VARIANT_IDS:
		if int(VARIANT_IDS[k]) == int(v):
			return String(k)
	return "soldado"


func _on_enemy_killed(pos: Vector2) -> void:
	call_deferred("_spawn_drops", pos)


func _spawn_drops(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	var pending := 0
	var guards_left := 0
	for e in get_tree().get_nodes_in_group("Enemies"):
		if not (e.has_method("is_alive") and e.is_alive()):
			continue
		if bool(e.get("guards_exit")):
			guards_left += 1
		else:
			pending += 1

	var last_enemy := pending == 0 and not _key_dropped and not Global.has_key
	if last_enemy:
		_key_dropped = true
		var key := KeyItemScene.instantiate() as Node2D
		key.position = to_local(pos)
		add_child(key)

		var story_note := Story.has_note(level_index)
		var with_note := drop_note_on_clear or story_note
		Global.set_objective(NOTE_OBJECTIVE if with_note else objective_key_dropped)
		if with_note:
			Global.show_message("¡LLAVE Y NOTA! · [%s] PARA LEER LA NOTA" % Settings.key_name("action"))
		elif guards_left > 0:
			Global.show_message("¡LLAVE! QUEDA UN CUSTODIO EN LA SALIDA")
		else:
			Global.show_message("¡EL ÚLTIMO SUELTA LA LLAVE!")

		if with_note:
			var note := NoteItemScene.instantiate() as Node2D
			if story_note:
				note.set("note_title", String(_chapter.get("note_title", "")))
				note.set("note_text", String(_chapter.get("note_text", "")))
				note.set("note_signature", String(_chapter.get("note_signature", "")))
			note.position = to_local(_free_spot(pos, Vector2(-22, 6)))
			add_child(note)
		_radio_lines(_chapter.get("radio_clear", []))

	var kind := _roll_loot()
	if kind >= 0:
		var pickup := PickupScene.instantiate() as Node2D
		pickup.set("kind", kind)
		var amount_mult := Settings.diff("loot_amount")
		match kind:
			0:
				pickup.set("amount", maxi(1, int(round(float(randi_range(ammo_drop_min, ammo_drop_max)) * amount_mult))))
			1:
				pickup.set("amount", maxi(1, int(round(float(health_drop_amount) * amount_mult))))
			3:
				pickup.set("amount", maxi(1, int(round(float(randi_range(3, 6)) * amount_mult))))
		var spot := _free_spot(pos, Vector2(18, -8)) if last_enemy else pos
		pickup.position = to_local(spot)
		add_child(pickup)


func _free_spot(origin: Vector2, offset: Vector2) -> Vector2:
	for i in range(4):
		var p := origin + offset.rotated(PI * 0.5 * float(i))
		if is_walkable(p):
			return p
	return origin


func _roll_loot() -> int:
	var hard := Settings.difficulty >= 2
	var rifle_total := Global.total_ammo(0)
	var shell_total := Global.total_ammo(1)
	var health_ratio := Global.health / Global.max_health
	var missing_hearts := Global.MAX_LIVES - Global.lives

	var low_on_ammo := rifle_total < (8 if hard else 15) and shell_total < (2 if hard else 4)
	var desperate := health_ratio < (0.3 if hard else 0.5) or low_on_ammo
	if not desperate and randf() > loot_chance * Settings.diff("loot_chance"):
		return -1

	var rifle_need := clampf(1.0 - float(rifle_total) / 80.0, 0.0, 1.0)
	var shell_need := clampf(1.0 - float(shell_total) / 24.0, 0.0, 1.0)
	var w_ammo := 0.4 + rifle_need * 3.5
	var w_shells := 0.3 + shell_need * 3.0
	var w_health := 0.4 + (1.0 - health_ratio) * 4.0
	var w_heart := float(missing_hearts) * 0.7

	var roll := randf() * (w_ammo + w_health + w_heart + w_shells)
	if roll < w_ammo:
		return 0
	roll -= w_ammo
	if roll < w_health:
		return 1
	roll -= w_health
	if roll < w_heart:
		return 2
	return 3


func _intro_hints() -> void:
	if tutorial_mode or level_index != 0 or GameManager.tutorial_done:
		return
	var hints: Array[String] = [
		"1 RIFLE · 2 ESCOPETA · 3 CUCHILLO · R RECARGAR",
		"SIGILO: LOS ENEMIGOS TE DETECTAN POCO A POCO. MANTÉN SHIFT PARA CAMINAR DESPACIO",
		"CUCHILLO [F] O CLIC DERECHO: POR LA ESPALDA MATA EN SILENCIO",
		"¿PRIMERA VEZ? EL TUTORIAL ESTÁ EN EL MENÚ PRINCIPAL",
	]
	var tween := create_tween()
	tween.tween_interval(5.0)
	for hint in hints:
		tween.tween_callback(Global.show_message.bind(hint))
		tween.tween_interval(6.0)


func _has_closed_door() -> bool:
	for door in get_tree().get_nodes_in_group("doors"):
		if door.get("is_open") != true:
			return true
	return false


func _on_key_collected() -> void:
	Global.show_message("LLAVE OBTENIDA")
	if _has_closed_door():
		Global.set_objective(objective_with_key)
	else:
		Global.set_objective(objective_door_open)
	_radio_lines(_chapter.get("radio_key", []))
	if twist == "alarma":
		_start_alarm()
	if not _has_closed_door():
		_request_boss()


func _on_door_opened() -> void:
	Global.show_message("¡PUERTA ABIERTA!")
	if not Global.has_key:
		return
	Global.set_objective(objective_door_open)
	if not _door_radio_done:
		_door_radio_done = true
		_radio_lines(_chapter.get("radio_door", []))
	_request_boss()


func _start_alarm() -> void:
	if _alarm_used or _twists_over:
		return
	_alarm_used = true
	_alarm_on = true
	_alarm_expired = false
	_alarm_left = ALARM_TIME * _time_mult()
	_wave_timer = ALARM_FIRST_WAVE
	Global.set_alarm(true, _alarm_left)
	_lighting_call("set_alarm", [true])
	Global.show_message("¡ALARMA! LLEGAN REFUERZOS")


func _stop_alarm() -> void:
	if not _alarm_on:
		return
	_alarm_on = false
	Global.set_alarm(false, 0.0)
	_lighting_call("set_alarm", [false])


func _update_alarm(delta: float) -> void:
	_alarm_left = maxf(0.0, _alarm_left - delta)
	if _alarm_left <= 0.0 and not _alarm_expired:
		_alarm_expired = true
		_wave_timer = 0.0
		_radio_lines(Story.ALARM_EXPIRED)
		Global.show_message("¡SE ACABÓ EL TIEMPO!")
		_pulse(Color(1.0, 0.1, 0.08), 0.6, 0.7)
	Global.set_alarm(true, _alarm_left)

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = ALARM_HEAVY_WAVE_TIME if _alarm_expired else ALARM_WAVE_TIME
		_alarm_wave()


func _alarm_wave() -> void:
	var room := MAX_REINFORCEMENTS - _alive_reinforcements()
	if room <= 0:
		return
	var wave: Array[int] = []
	if _alarm_expired:
		wave = [int(VARIANT_IDS["pesado"]), int(VARIANT_IDS["rapido"])]
	else:
		wave = [int(VARIANT_IDS["rapido"]), int(VARIANT_IDS["soldado"])]
	var spawned := 0
	for v in wave:
		if spawned >= room:
			break
		if spawn_reinforcement(v) != null:
			spawned += 1
	if spawned > 0 and not _alarm_expired:
		Global.show_message("¡LLEGAN REFUERZOS!")


func _alive_reinforcements() -> int:
	var alive := 0
	for e in _reinforcements.duplicate():
		if not is_instance_valid(e):
			_reinforcements.erase(e)
			continue
		if e.has_method("is_alive") and e.is_alive():
			alive += 1
		else:
			_reinforcements.erase(e)
	return alive


func _hunt_pulse() -> void:
	var player := _player()
	if player == null:
		return
	var target := player.global_position
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.has_method("is_alive") and e.is_alive():
			_alert_enemy(e, target)
	if not Story.HUNT_PULSE.is_empty():
		var line: Array = Story.HUNT_PULSE[randi() % Story.HUNT_PULSE.size()]
		Global.radio(String(line[0]), String(line[1]))
	Global.show_message("¡TE LOCALIZARON!")
	_pulse(Color(1.0, 0.2, 0.15), 0.35, 0.5)


func _alert_enemy(e: Node, point: Vector2) -> void:
	if e.has_method("alert_to"):
		e.alert_to(point)
	elif e.has_method("_investigate"):
		e._investigate(point)


func _request_boss() -> void:
	if not _boss_level or _boss_spawned or _boss_pending or _twists_over:
		return
	if not ResourceLoader.exists(BOSS_PATH):
		return
	_boss_pending = true
	call_deferred("_spawn_boss")


func _spawn_boss() -> void:
	_boss_pending = false
	if _boss_spawned or not is_inside_tree():
		return
	var scene := load(BOSS_PATH) as PackedScene
	if scene == null:
		return
	var inst := scene.instantiate()
	var boss := inst as Node2D
	if boss == null:
		inst.free()
		return
	_boss_spawned = true
	var parent := _enemies_parent()
	boss.position = parent.to_local(_boss_spawn_point())
	var cinematic := Global.health > 0.0
	boss.set("cinematic_death", cinematic)
	if cinematic:
		Global.set_cutscene(true)
	parent.add_child(boss, true)
	if cinematic:
		call_deferred("_play_boss_intro", boss)


func _play_boss_intro(boss: Node2D) -> void:
	if not is_inside_tree():
		Global.set_cutscene(false)
		return
	await Cutscenes.boss_intro(self, boss)
	if is_instance_valid(boss) and boss.has_method("finish_intro"):
		boss.finish_intro()


func _play_boss_down() -> void:
	var pos := Vector2.INF
	var corpse := get_tree().get_first_node_in_group("boss") as Node2D
	if corpse != null:
		pos = corpse.global_position
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	timer.wait_time = 1.3
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
	if not is_inside_tree() or Global.health <= 0.0 or not pos.is_finite() or _outro_started:
		return
	await Cutscenes.boss_down(self, pos)


func play_outro() -> void:
	if _outro_started:
		return
	_outro_started = true
	end_twists()
	if GameManager.trailer_mode or Global.health <= 0.0 or not is_inside_tree():
		GameManager.complete_level()
		return
	await Cutscenes.level_outro(self, level_index, _boss_level)
	if is_inside_tree():
		GameManager.complete_level()


func _boss_spawn_point() -> Vector2:
	var p := Vector2.INF
	var marker := get_tree().get_first_node_in_group("boss_spawn") as Node2D
	if marker != null:
		p = marker.global_position
	else:
		var ex := get_tree().get_first_node_in_group("exit_zone") as Node2D
		if ex != null:
			p = ex.global_position
	if not p.is_finite():
		var player := _player()
		p = random_walkable_point(player.global_position if player != null else map_bounds.get_center(), 200.0)
	return _walkable_near(p)


func _on_boss_spawned(_boss: Node) -> void:
	_boss_spawned = true
	Global.set_objective(BOSS_OBJECTIVE)
	if _alarm_on:
		_stop_alarm()
		call_deferred("_radio_lines", Story.BOSS_ALARM_OFF)


func _on_boss_defeated() -> void:
	if Global.has_key:
		Global.set_objective(objective_door_open)
	Global.show_message("¡EL CONTRATISTA HA CAÍDO!")
	if Global.health > 0.0 and not GameManager.trailer_mode:
		call_deferred("_play_boss_down")


func spawn_reinforcement(variant: int, near: Vector2 = Vector2.INF) -> Node:
	if not is_inside_tree() or _twists_over:
		return null
	if _enemy_scene == null and ResourceLoader.exists(ENEMY_PATH):
		_enemy_scene = load(ENEMY_PATH) as PackedScene
	if _enemy_scene == null:
		return null

	var player := _player()
	var player_pos := map_bounds.get_center()
	if player != null:
		player_pos = player.global_position
	elif near.is_finite():
		player_pos = near
	var spot := _spot_near(near) if near.is_finite() else _spot_far(player_pos)
	if not spot.is_finite():
		return null

	var inst := _enemy_scene.instantiate()
	var enemy := inst as Node2D
	if enemy == null:
		inst.free()
		return null
	enemy.set("behavior", BEHAVIOR_PERSEGUIR)
	enemy.set("patrol_distance", 80.0)
	_spawn_count += 1
	enemy.name = "Refuerzo%d" % _spawn_count
	var parent := _enemies_parent()
	enemy.position = parent.to_local(spot)
	_reinforcements.append(enemy)
	var ring := not near.is_finite()
	if Engine.is_in_physics_frame():
		_attach_enemy.call_deferred(enemy, parent, variant, ring)
	else:
		_attach_enemy(enemy, parent, variant, ring)
	return enemy


func _attach_enemy(enemy: Node2D, parent: Node2D, variant: int, ring: bool) -> void:
	if not is_instance_valid(enemy):
		return
	if not is_instance_valid(parent) or not parent.is_inside_tree() or _twists_over:
		_reinforcements.erase(enemy)
		enemy.free()
		return
	parent.add_child(enemy, true)
	if enemy.is_queued_for_deletion():
		return
	if variant != 0 and enemy.has_method("apply_variant"):
		enemy.apply_variant(variant)
	var player := _player()
	if player != null:
		_alert_enemy(enemy, player.global_position)
	if ring:
		var fx := SpawnRing.new()
		fx.position = to_local(enemy.global_position)
		add_child(fx)


func random_walkable_point(avoid: Vector2, min_dist: float) -> Vector2:
	if _astar == null:
		return avoid + Vector2.RIGHT.rotated(randf() * TAU) * min_dist
	var cells := _reachable_cells()
	if cells.is_empty():
		return _walkable_near(avoid)
	var best := Vector2.INF
	var best_d := -1.0
	for i in range(48):
		var c := cells[randi() % cells.size()]
		var p := _cell_center(c)
		var d := p.distance_to(avoid)
		if d >= min_dist and _is_roomy(c):
			return p
		if d > best_d:
			best_d = d
			best = p
	return best


func _spot_far(player_pos: Vector2) -> Vector2:
	var best := Vector2.INF
	var best_score := -INF
	for i in range(16):
		var p := random_walkable_point(player_pos, REINFORCE_MIN_DIST)
		if not p.is_finite():
			break
		var d := p.distance_to(player_pos)
		var score := 0.0
		if d >= REINFORCE_MIN_DIST:
			score += 4.0
		if d <= REINFORCE_MAX_DIST:
			score += 2.0
		if not _line_of_sight(p, player_pos):
			score += 3.0
		if score >= 9.0:
			return p
		score -= absf(d - REINFORCE_MIN_DIST) * 0.001
		if score > best_score:
			best_score = score
			best = p
	return best


func _spot_near(near: Vector2) -> Vector2:
	if _astar == null:
		return near + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 140.0)
	var fallback := Vector2.INF
	for i in range(28):
		var p := near + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40.0, 140.0)
		var c := _cell_of(p)
		if not _is_open(c):
			continue
		var center := _cell_center(c)
		if not _line_of_sight(near, center):
			continue
		if _is_roomy(c):
			return center
		if not fallback.is_finite():
			fallback = center
	if fallback.is_finite():
		return fallback
	return _walkable_near(near)


func _line_of_sight(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var query := PhysicsRayQueryParameters2D.create(a, b, 1)
	return space.intersect_ray(query).is_empty()


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _enemies_parent() -> Node2D:
	var n := get_node_or_null("Enemies") as Node2D
	return n if n != null else self


func _walkable_near(point: Vector2) -> Vector2:
	if _astar == null:
		return point
	var c := _nearest_open_cell(point)
	if c == NO_CELL or c == _cell_of(point):
		return point
	return _cell_center(c)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(tile_size)


func _is_roomy(cell: Vector2i) -> bool:
	for d in DIRS8:
		if not _is_open(cell + d):
			return false
	return true


func _reachable_cells() -> Array[Vector2i]:
	var player := _player()
	var start := NO_CELL
	if player != null:
		start = _nearest_open_cell(player.global_position)
	if start == NO_CELL:
		return _reach_cells
	if _reach_dirty or not _reach.has(start):
		_flood(start)
	return _reach_cells


func _flood(start: Vector2i) -> void:
	_reach.clear()
	_reach_cells.clear()
	_reach_dirty = false
	_reach[start] = true
	_reach_cells.append(start)
	var head := 0
	while head < _reach_cells.size():
		var c := _reach_cells[head]
		head += 1
		for d in DIRS4:
			var n: Vector2i = c + d
			if _reach.has(n) or not _is_open(n):
				continue
			_reach[n] = true
			_reach_cells.append(n)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _astar == null:
		out.append(to)
		return out

	var a := _nearest_open_cell(from)
	var b := _nearest_open_cell(to)
	if a == NO_CELL or b == NO_CELL:
		return out

	var half := Vector2(tile_size, tile_size) * 0.5
	for id in _astar.get_id_path(a, b):
		out.append(Vector2(id) * float(tile_size) + half)
	return out


func is_walkable(point: Vector2) -> bool:
	if _astar == null:
		return true
	return _is_open(_cell_of(point))


func set_solid_rect(rect: Rect2, solid: bool) -> void:
	if _astar == null:
		return
	var r := rect.grow(-3.0)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var c0 := _cell_of(r.position)
	var c1 := _cell_of(r.end)
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var id := Vector2i(x, y)
			if _astar.is_in_boundsv(id):
				_astar.set_point_solid(id, solid)
	_reach_dirty = true


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / float(tile_size)).floor())


func _is_open(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


func _nearest_open_cell(point: Vector2) -> Vector2i:
	var c := _cell_of(point)
	if _is_open(c):
		return c
	for ring in range(1, 4):
		var best := NO_CELL
		var best_d := INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var n := c + Vector2i(dx, dy)
				if not _is_open(n):
					continue
				var d := ((Vector2(n) + Vector2(0.5, 0.5)) * float(tile_size)).distance_to(point)
				if d < best_d:
					best_d = d
					best = n
		if best != NO_CELL:
			return best
	return NO_CELL


func _limit_camera(bounds: Rect2) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = int(floor(bounds.position.x))
	cam.limit_top = int(floor(bounds.position.y))
	cam.limit_right = int(ceil(bounds.end.x))
	cam.limit_bottom = int(ceil(bounds.end.y))


func _cell_has_tile(layer: TileMapLayer, cell: Vector2i) -> bool:
	var atlas := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	return atlas != null and atlas.has_tile(layer.get_cell_atlas_coords(cell))


func _build_grid() -> void:
	var layers: Array[TileMapLayer] = []
	for n in find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		if layer != null and layer.tile_set != null:
			layers.append(layer)
	if layers.is_empty():
		return

	var t := float(tile_size)
	var bounds := Rect2()
	var have_bounds := false
	var covered := {}

	for layer in layers:
		var has_physics := layer.tile_set.get_physics_layers_count() > 0 and layer.collision_enabled
		for cell in layer.get_used_cells():
			if not _cell_has_tile(layer, cell):
				continue
			var local_center := layer.map_to_local(cell)
			var center := layer.to_global(local_center)
			covered[Vector2i((center / t).floor())] = true

			var r := Rect2(center - Vector2(t, t) * 0.5, Vector2(t, t))
			bounds = r if not have_bounds else bounds.merge(r)
			have_bounds = true

			if not has_physics:
				continue
			var data := layer.get_cell_tile_data(cell)
			if data == null:
				continue
			for i in range(data.get_collision_polygons_count(0)):
				var pts := data.get_collision_polygon_points(0, i)
				if pts.is_empty():
					continue
				var rect := Rect2(layer.to_global(local_center + pts[0]), Vector2.ZERO)
				for p in pts:
					rect = rect.expand(layer.to_global(local_center + p))
				solid_rects.append(rect)

	if not have_bounds:
		return

	map_bounds = bounds
	_limit_camera(bounds)

	var origin := Vector2i((bounds.position / t).floor())
	var end_cell := Vector2i((bounds.end / t).ceil())
	_grid_rect = Rect2i(origin, end_cell - origin)

	_astar = AStarGrid2D.new()
	_astar.region = _grid_rect
	_astar.cell_size = Vector2(t, t)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	_astar.update()

	for x in range(_grid_rect.position.x, _grid_rect.end.x):
		for y in range(_grid_rect.position.y, _grid_rect.end.y):
			var id := Vector2i(x, y)
			if not covered.has(id):
				_astar.set_point_solid(id, true)

	for rect in solid_rects:
		set_solid_rect(rect, true)

	for door in get_tree().get_nodes_in_group("doors"):
		if door.has_method("get_solid_rect") and not door.is_open:
			set_solid_rect(door.get_solid_rect(), true)
