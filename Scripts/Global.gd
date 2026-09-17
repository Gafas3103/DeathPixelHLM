extends Node

# SEÑALES: Permiten al HUD reaccionar a cambios en el juego de forma automática
signal health_changed(new_health)
signal ammo_changed(new_ammo)
signal lives_changed(new_lives)
signal player_died
signal player_respawned

# VARIABLES DE ESTADO DEL JUGADOR
var max_health: float = 100.0
var health: float = 100.0
var max_ammo: int = 8
var ammo: int = 8
var lives: int = 3
# Función para aplicar daño al jugador
func take_damage(amount: float):
	health = clamp(health - amount, 0.0, max_health)
	health_changed.emit(health)
	
	if health <= 0.0:
		player_died.emit()

# Función para curar al jugador
func heal(amount: float):
	health = clamp(health + amount, 0.0, max_health)
	health_changed.emit(health)

# Función para gastar munición al disparar
func use_ammo():
	if ammo > 0:
		ammo -= 1
		ammo_changed.emit(ammo)
		return true
	return false

# Función para recargar munición
func reload():
	ammo = max_ammo
	ammo_changed.emit(ammo)

# Restablecer el estado tras morir y perder una vida (Checkpoint / Respawn)
func respawn():
	if lives > 0:
		lives -= 1
		lives_changed.emit(lives)
	
	health = max_health
	health_changed.emit(health)
	ammo = max_ammo
	ammo_changed.emit(ammo)
	player_respawned.emit()


func reset_game():
	lives = 3
	health = max_health
	ammo = max_ammo
	get_tree().reload_current_scene()
