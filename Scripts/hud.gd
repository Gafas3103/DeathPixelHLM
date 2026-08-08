extends CanvasLayer

# NODOS DE LA INTERFAZ
@onready var health_bar = $Control/TopBar/HBox/VBoxHealth/HealthBar
@onready var character_name = $Control/TopBar/HBox/VBoxHealth/CharacterName
@onready var character_portrait = $Control/TopBar/HBox/CharacterPortrait
@onready var lives_label = $Control/TopBar/HBox/VBoxStats/LivesLabel
@onready var ammo_label = $Control/TopBar/HBox/VBoxStats/AmmoLabel
@onready var game_over_panel = $Control/GameOverScreen

# Texturas que ya existen en el proyecto
const PORTRAIT_SILENCER = preload("res://Assest/hitman1_silencer.png")
const PORTRAIT_HOLD = preload("res://Assest/hitman1_hold.png")

func _ready():
	# Conectar las señales del script Global para actualizar la UI automáticamente
	Global.health_changed.connect(_on_health_changed)
	Global.ammo_changed.connect(_on_ammo_changed)
	Global.lives_changed.connect(_on_lives_changed)
	Global.character_swapped.connect(_on_character_swapped)
	Global.player_died.connect(_on_player_died)
	
	# Inicializar la UI con los valores actuales
	_on_health_changed(Global.health)
	_on_ammo_changed(Global.ammo)
	_on_lives_changed(Global.lives)
	_on_character_swapped(Global.active_character)
	game_over_panel.visible = false

func _process(delta):
	# Si la pantalla de muerte está visible y se presiona R, reaparecer
	# OJO: los paréntesis importan. Sin ellos "and" se evalúa antes que "or"
	# y bastaba presionar R en cualquier momento para reaparecer.
	if game_over_panel.visible and (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R)):
		if Global.lives > 0:
			Global.respawn()
			game_over_panel.visible = false
		else:
			# Si ya no le quedan vidas, reinicia el juego desde el principio
			Global.reset_game()
			game_over_panel.visible = false

# Funciones de respuesta a señales de Global
func _on_health_changed(new_health: float):
	health_bar.value = new_health

func _on_ammo_changed(new_ammo: int):
	ammo_label.text = "MUN: %d / %d" % [new_ammo, Global.max_ammo]

func _on_lives_changed(new_lives: int):
	var heart_icons = ""
	for i in range(new_lives):
		heart_icons += "♥"
	if heart_icons == "":
		heart_icons = "SIN VIDAS"
	lives_label.text = "VIDAS: " + heart_icons

func _on_character_swapped(char_id: int):
	if char_id == 0:
		character_name.text = "AGENTE: SILENCIADOR"
		character_portrait.texture = PORTRAIT_SILENCER
	else:
		character_name.text = "AGENTE: PORTADOR"
		character_portrait.texture = PORTRAIT_HOLD

func _on_player_died():
	game_over_panel.visible = true
	var prompt = $Control/GameOverScreen/VBox/PromptLabel
	if Global.lives > 0:
		prompt.text = "Presiona [R] para reaparecer (-1 Vida)"
	else:
		prompt.text = "¡JUEGO TERMINADO!\nPresiona [R] para reiniciar desde cero"
