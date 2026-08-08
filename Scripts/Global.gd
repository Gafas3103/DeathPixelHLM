extends Node

signal health_changed(new_health)
signal ammo_changed(new_ammo)
signal lives_changed(new_lives)
signal character_swapped(active_char_id)
signal player_died
signal player_respawned
signal enemies_changed(remaining)
signal level_cleared

var max_health: float = 100.0
var health: float = 100.0
var max_ammo: int = 8
var ammo: int = 8
var lives: int = 3
var active_character: int = 0
var enemies_remaining: int = 0
var level_finished: bool = false

var is_dead: bool = false

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = clamp(health - amount, 0.0, max_health)
	health_changed.emit(health)
	if health <= 0.0:
		is_dead = true
		player_died.emit()

func heal(amount: float) -> void:
	if is_dead:
		return
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health)

func use_ammo() -> bool:
	if is_dead:
		return false
	if ammo > 0:
		ammo -= 1
		ammo_changed.emit(ammo)
		return true
	return false

func reload() -> void:
	if is_dead:
		return
	ammo = max_ammo
	ammo_changed.emit(ammo)

func set_active_character(char_id: int) -> void:
	if is_dead or char_id == active_character:
		return
	active_character = char_id
	character_swapped.emit(active_character)

func register_enemy() -> void:
	enemies_remaining += 1
	enemies_changed.emit(enemies_remaining)

func enemy_died() -> void:
	enemies_remaining = max(enemies_remaining - 1, 0)
	enemies_changed.emit(enemies_remaining)
	if enemies_remaining == 0 and not level_finished:
		level_finished = true
		level_cleared.emit()

func respawn() -> void:
	if lives > 0:
		lives -= 1
		lives_changed.emit(lives)
	is_dead = false
	health = max_health
	health_changed.emit(health)
	ammo = max_ammo
	ammo_changed.emit(ammo)
	player_respawned.emit()

func reset_game() -> void:
	lives = 3
	is_dead = false
	level_finished = false
	enemies_remaining = 0
	health = max_health
	ammo = max_ammo
	active_character = 0
	health_changed.emit(health)
	ammo_changed.emit(ammo)
	lives_changed.emit(lives)
	character_swapped.emit(active_character)
	get_tree().call_deferred("reload_current_scene")
