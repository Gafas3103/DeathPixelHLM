extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/TopBar/HBox/VBoxHealth/HealthBar
@onready var character_name: Label = $Control/TopBar/HBox/VBoxHealth/CharacterName
@onready var character_portrait: TextureRect = $Control/TopBar/HBox/CharacterPortrait
@onready var lives_label: Label = $Control/TopBar/HBox/VBoxStats/LivesLabel
@onready var ammo_label: Label = $Control/TopBar/HBox/VBoxStats/AmmoLabel
@onready var objective_label: Label = $Control/ObjectivePanel/ObjectiveLabel
@onready var game_over_panel: ColorRect = $Control/GameOverScreen
@onready var prompt_label: Label = $Control/GameOverScreen/VBox/PromptLabel
@onready var title_label: Label = $Control/GameOverScreen/VBox/TitleLabel

const PORTRAIT_SILENCER = preload("res://Assest/hitman1_silencer.png")
const PORTRAIT_HOLD = preload("res://Assest/hitman1_hold.png")

func _ready() -> void:
	Global.health_changed.connect(_on_health_changed)
	Global.ammo_changed.connect(_on_ammo_changed)
	Global.lives_changed.connect(_on_lives_changed)
	Global.character_swapped.connect(_on_character_swapped)
	Global.player_died.connect(_on_player_died)
	Global.enemies_changed.connect(_on_enemies_changed)
	Global.level_cleared.connect(_on_level_cleared)

	health_bar.max_value = Global.max_health
	_on_health_changed(Global.health)
	_on_ammo_changed(Global.ammo)
	_on_lives_changed(Global.lives)
	_on_character_swapped(Global.active_character)
	_on_enemies_changed(Global.enemies_remaining)
	game_over_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not game_over_panel.visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R):
		game_over_panel.visible = false
		if Global.lives > 0:
			Global.respawn()
		else:
			Global.reset_game()
		get_viewport().set_input_as_handled()

func _on_health_changed(new_health: float) -> void:
	health_bar.value = new_health

func _on_ammo_changed(new_ammo: int) -> void:
	ammo_label.text = "MUN: %d / %d" % [new_ammo, Global.max_ammo]

func _on_lives_changed(new_lives: int) -> void:
	if new_lives <= 0:
		lives_label.text = "VIDAS: SIN VIDAS"
		return
	lives_label.text = "VIDAS: " + "♥".repeat(new_lives)

func _on_character_swapped(char_id: int) -> void:
	if char_id == 0:
		character_name.text = "AGENTE: SILENCIADOR"
		character_portrait.texture = PORTRAIT_SILENCER
	else:
		character_name.text = "AGENTE: PORTADOR"
		character_portrait.texture = PORTRAIT_HOLD

func _on_enemies_changed(remaining: int) -> void:
	if remaining > 0:
		objective_label.text = "OBJETIVO: ELIMINAR %d ENEMIGOS" % remaining

func _on_level_cleared() -> void:
	objective_label.text = "ZONA DESPEJADA: BUSCA LA NOTA"

func _on_player_died() -> void:
	game_over_panel.visible = true
	title_label.text = "AGENTE CAIDO"
	if Global.lives > 0:
		prompt_label.text = "Presiona [R] para reaparecer (-1 Vida)"
	else:
		prompt_label.text = "JUEGO TERMINADO\nPresiona [R] para reiniciar desde cero"
