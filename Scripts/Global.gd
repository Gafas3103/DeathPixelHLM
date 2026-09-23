extends Node

## Estado global (autoload Global): vida, armas, munición, puntaje, combo, flow, llave y ruido.

const Weapons := preload("res://Scripts/weapons.gd")

# señales para el HUD
signal health_changed(new_health: float)
signal ammo_changed(new_ammo: int)
signal reserve_changed(new_reserve: int)
signal weapon_changed(index: int)
signal lives_changed(new_lives: int)
signal player_died
signal player_respawned
signal score_changed(new_score: int)
signal combo_changed(multiplier: int, time_fraction: float)
signal key_collected
signal door_opened
signal objective_changed(text: String)
## aviso corto en pantalla
signal message(text: String)
## murió un enemigo (el nivel suelta llave y botín ahí)
signal enemy_killed(position: Vector2)
## ruido que los enemigos pueden oír (origen, radio, y a dónde van a mirar)
signal noise_made(origin: Vector2, radius: float, investigate_at: Vector2)
signal radio_message(speaker: String, text: String)
signal boss_spawned(boss: Node)
signal boss_health_changed(current: float, maximum: float, phase: int)
signal boss_defeated
signal alarm_changed(active: bool, time_left: float)
signal flashlight_changed(on: bool)

# combo: cada baja lo sube y alarga el tiempo para la siguiente
const COMBO_BASE_WINDOW := 8.0  # segundos que dura tras una baja
const COMBO_WINDOW_PER_LEVEL := 1.0  # segundos extra por nivel de combo
const COMBO_MAX_WINDOW := 16.0
const QUICK_KILL_TIME := 2.5  # dos bajas dentro de este tiempo = racha rápida (+2)
const MAX_COMBO := 20
const KILL_POINTS := 100
const MAX_LIVES := 3

# flow: más combo, más daño, velocidad y cadencia
const FLOW_NAMES: Array[String] = ["", "FLOW", "FRENESÍ", "BERSERK"]
const FLOW_COMBO_STEPS: Array[int] = [3, 6, 10]  # combo necesario para cada nivel
const DAMAGE_PER_COMBO := 0.15  # +15% de daño por punto de combo
const FLOW_SPEED: Array[float] = [1.0, 1.08, 1.16, 1.28]
const FLOW_FIRE_RATE: Array[float] = [1.0, 0.9, 0.8, 0.65]  # intervalo entre disparos, menos es más rápido
const FLOW_RELOAD: Array[float] = [1.0, 0.9, 0.75, 0.5]

# cómo empieza un nivel
const START_FRESH := 0
const START_CARRY := 1  # se conserva vida, corazones, armas y puntaje
const START_RETRY := 2  # todo nuevo pero el puntaje vuelve al de la entrada
const MIN_START_MAG := 1  # cargadores mínimos con los que se entra
const INVULN_AFTER_SPAWN := 2.0  # segundos sin daño al aparecer

# jugador
var max_health: float = 100.0
var health: float = 100.0
var lives: int = 3
var reloading: bool = false  # lo lee el HUD

## 0 rifle, 1 escopeta, 2 cuchillo (ver weapons.gd)
var current_weapon: int = 0
var _mags: Array[int] = [20, 6, 0]
var _reserves: Array[int] = [40, 12, 0]

## munición del arma equipada
var ammo: int:
	get:
		return _mags[current_weapon]
	set(value):
		_mags[current_weapon] = value
var reserve_ammo: int:
	get:
		return _reserves[current_weapon]
	set(value):
		_reserves[current_weapon] = value
var max_ammo: int:
	get:
		return int(Weapons.LIST[current_weapon]["mag"])
var max_reserve: int:
	get:
		return int(Weapons.LIST[current_weapon]["max_reserve"])
var reload_time: float:
	get:
		return float(Weapons.LIST[current_weapon]["reload"]) * reload_mult()

# puntaje y combo
var score: int = 0
var kills: int = 0
var combo: int = 1
var combo_time: float = 0.0
var combo_window: float = COMBO_BASE_WINDOW  # duración del combo actual (para la barra)
var last_multiplier: int = 1
var last_kill_weapon: int = 0  # 0 rifle, 1 escopeta, 2 cuchillo
var last_kill_silent: bool = false

# aparición
var grace_time: float = 0.0  # mientras sea > 0 no te detectan
var invuln_time: float = 0.0  # mientras sea > 0 no recibes daño

# nivel
var has_key: bool = false
var objective: String = ""

var level_active: bool = false
var level_time: float = 0.0
var times_detected: int = 0
var deaths_this_level: int = 0
var stealth_kills: int = 0
var boss_alive: bool = false
var boss_node: Node = null
var lights_out: bool = false
var flashlight_on: bool = false
var alarm_active: bool = false

var _score_at_level_start: int = 0
var _kills_at_level_start: int = 0
var _last_detection_time: float = -100.0


func _process(delta: float) -> void:
	# se pausa con el árbol
	grace_time = maxf(0.0, grace_time - delta)
	invuln_time = maxf(0.0, invuln_time - delta)
	if level_active and health > 0.0:
		level_time += delta

	if combo_time > 0.0:
		combo_time -= delta
		if combo_time <= 0.0:
			combo_time = 0.0
			combo = 1
			combo_changed.emit(combo, 0.0)
		else:
			combo_changed.emit(combo, combo_time / combo_window)


# flow

## 0 normal, 1 FLOW, 2 FRENESÍ, 3 BERSERK
func flow_tier() -> int:
	var tier := 0
	for i in range(FLOW_COMBO_STEPS.size()):
		if combo >= FLOW_COMBO_STEPS[i]:
			tier = i + 1
	return tier


func flow_name() -> String:
	return FLOW_NAMES[flow_tier()]


## multiplicador de daño según el combo
func damage_mult() -> float:
	return 1.0 + DAMAGE_PER_COMBO * float(combo - 1)


func speed_mult() -> float:
	return FLOW_SPEED[flow_tier()]


func fire_rate_mult() -> float:
	return FLOW_FIRE_RATE[flow_tier()]


func reload_mult() -> float:
	return FLOW_RELOAD[flow_tier()]


# vida

func take_damage(amount: float) -> void:
	if health <= 0.0 or invuln_time > 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health)

	if health <= 0.0:
		combo = 1
		combo_time = 0.0
		combo_changed.emit(combo, 0.0)
		deaths_this_level += 1
		player_died.emit()


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health)


## recupera un corazón, false si ya estaban todos
func add_life() -> bool:
	if lives >= MAX_LIVES:
		return false
	lives += 1
	lives_changed.emit(lives)
	return true


# armas y munición

func is_melee_weapon() -> bool:
	return bool(Weapons.LIST[current_weapon]["melee"])


func switch_weapon(index: int) -> void:
	index = clampi(index, 0, Weapons.LIST.size() - 1)
	if index == current_weapon:
		return
	current_weapon = index
	reloading = false
	weapon_changed.emit(index)
	ammo_changed.emit(ammo)
	reserve_changed.emit(reserve_ammo)


func cycle_weapon(direction: int) -> void:
	switch_weapon(posmod(current_weapon + direction, Weapons.LIST.size()))


func use_ammo() -> bool:
	if ammo > 0:
		ammo -= 1
		ammo_changed.emit(ammo)
		return true
	return false


func can_reload() -> bool:
	return max_ammo > 0 and ammo < max_ammo and reserve_ammo > 0


# pasa balas de la reserva al cargador
func reload() -> void:
	var taken := mini(max_ammo - ammo, reserve_ammo)
	if taken <= 0:
		return
	ammo += taken
	reserve_ammo -= taken
	ammo_changed.emit(ammo)
	reserve_changed.emit(reserve_ammo)


## munición total (cargador + reserva)
func total_ammo(weapon: int) -> int:
	return _mags[weapon] + _reserves[weapon]


## false si la reserva de esa arma ya estaba llena
func add_reserve_ammo(amount: int, weapon: int = 0) -> bool:
	var cap := int(Weapons.LIST[weapon]["max_reserve"])
	if _reserves[weapon] >= cap:
		return false
	_reserves[weapon] = mini(_reserves[weapon] + amount, cap)
	if weapon == current_weapon:
		reserve_changed.emit(_reserves[weapon])
	return true


## llena cargadores y deja buena reserva (lo usa el tutorial)
func refill_weapons() -> void:
	for i in range(Weapons.LIST.size() - 1):
		_mags[i] = int(Weapons.LIST[i]["mag"])
		_reserves[i] = maxi(_reserves[i], int(Weapons.LIST[i]["max_reserve"]) / 2)
	ammo_changed.emit(ammo)
	reserve_changed.emit(reserve_ammo)


func reserve_full(weapon: int) -> bool:
	return _reserves[weapon] >= int(Weapons.LIST[weapon]["max_reserve"])


# puntaje y combo

## cuando el jugador mata a un enemigo; devuelve los puntos.
## Puntos por combo actual; el combo sube +1 (o +2 si la baja fue rápida).
func add_kill(base_points: int = KILL_POINTS) -> int:
	kills += 1
	last_multiplier = combo
	var earned := int(round(float(base_points * combo) * Settings.diff("score")))
	score += earned
	score_changed.emit(score)

	# racha rápida si pasó poco desde la baja anterior
	var since_last := combo_window - combo_time
	var quick := combo_time > 0.0 and since_last <= QUICK_KILL_TIME
	combo = mini(combo + (2 if quick else 1), MAX_COMBO)
	combo_window = minf(COMBO_BASE_WINDOW + COMBO_WINDOW_PER_LEVEL * float(combo - 1), COMBO_MAX_WINDOW)
	combo_time = combo_window
	combo_changed.emit(combo, 1.0)
	return earned


# objetivos

func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func collect_key() -> void:
	if has_key:
		return
	has_key = true
	key_collected.emit()


func show_message(text: String) -> void:
	message.emit(text)


func make_noise(origin: Vector2, radius: float, investigate_at: Vector2) -> void:
	noise_made.emit(origin, radius, investigate_at)


func radio(speaker: String, text: String) -> void:
	radio_message.emit(speaker, text)


func register_detection() -> void:
	if not level_active:
		return
	if level_time - _last_detection_time > 4.0:
		times_detected += 1
	_last_detection_time = level_time


func register_stealth_kill() -> void:
	stealth_kills += 1


func set_flashlight(on: bool) -> void:
	if flashlight_on == on:
		return
	flashlight_on = on
	flashlight_changed.emit(on)


func set_boss(boss: Node) -> void:
	boss_node = boss
	boss_alive = boss != null
	if boss != null:
		boss_spawned.emit(boss)


func clear_boss() -> void:
	if not boss_alive:
		return
	boss_alive = false
	boss_node = null
	boss_defeated.emit()


func set_alarm(active: bool, time_left: float) -> void:
	alarm_active = active
	alarm_changed.emit(active, time_left)


# respawn y reinicio

func respawn() -> void:
	if lives > 0:
		lives -= 1
		lives_changed.emit(lives)

	health = max_health
	health_changed.emit(health)
	reloading = false
	for i in range(Weapons.LIST.size() - 1):
		_mags[i] = int(Weapons.LIST[i]["mag"])
		_reserves[i] = maxi(_reserves[i], int(Weapons.LIST[i]["mag"]))
	ammo_changed.emit(ammo)
	reserve_changed.emit(reserve_ammo)
	# vuelve al inicio con gracia e invulnerabilidad
	grace_time = Settings.spawn_grace()
	invuln_time = INVULN_AFTER_SPAWN
	player_respawned.emit()


## deja todo listo para empezar un nivel (START_FRESH, START_CARRY o START_RETRY)
func reset_for_level(mode: int = START_FRESH) -> void:
	if mode == START_CARRY:
		health = maxf(health, 1.0)
		lives = maxi(lives, 1)
		# munición de emergencia: un cargador de cada arma
		for i in range(Weapons.LIST.size() - 1):
			var mag := int(Weapons.LIST[i]["mag"])
			if _mags[i] + _reserves[i] < mag * MIN_START_MAG:
				_reserves[i] = mag * MIN_START_MAG - _mags[i]
	else:
		lives = MAX_LIVES
		health = max_health
		_mags = [int(Weapons.LIST[0]["mag"]), int(Weapons.LIST[1]["mag"]), 0]
		_reserves = [Settings.start_reserve(), Settings.start_shells(), 0]
		current_weapon = 0
		if mode == START_RETRY:
			score = _score_at_level_start
			kills = _kills_at_level_start
		else:
			score = 0
			kills = 0

	combo = 1
	combo_time = 0.0
	combo_window = COMBO_BASE_WINDOW
	has_key = false
	reloading = false
	objective = ""
	level_active = false
	level_time = 0.0
	times_detected = 0
	deaths_this_level = 0
	stealth_kills = 0
	boss_alive = false
	boss_node = null
	lights_out = false
	flashlight_on = false
	alarm_active = false
	_last_detection_time = -100.0
	grace_time = Settings.spawn_grace()
	invuln_time = INVULN_AFTER_SPAWN
	_score_at_level_start = score
	_kills_at_level_start = kills

	lives_changed.emit(lives)
	health_changed.emit(health)
	weapon_changed.emit(current_weapon)
	ammo_changed.emit(ammo)
	reserve_changed.emit(reserve_ammo)
	score_changed.emit(score)
	combo_changed.emit(combo, 0.0)


# 0 vidas: vuelve al nivel 1 y se pierde todo
func reset_game() -> void:
	GameManager.game_over_restart()
