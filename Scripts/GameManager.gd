extends Node

## Autoload GameManager: niveles, progreso guardado, cambio de escena y victoria.
## Para agregar un nivel: copiar Level1.tscn a Scenes/Levels/ y llenar su entrada en LEVELS.

const MAIN_MENU := "res://Scenes/UI/MainMenu.tscn"
const LEVEL_SELECT := "res://Scenes/UI/LevelSelect.tscn"
const SETTINGS_SCREEN := "res://Scenes/UI/SettingsMenu.tscn"
const TUTORIAL_SCENE := "res://Scenes/Levels/Tutorial.tscn"
const SAVE_PATH := "user://progress.cfg"
const VictoryScreen := preload("res://Scripts/UI/victory_screen.gd")

## índice 0-based; "scene" vacío = próximamente
const LEVELS := [
	{
		"name": "CALLE PRINCIPAL",
		"scene": "res://Scenes/Levels/Level1.tscn",
		"preview": "res://Assest/UI/preview_nivel1.png",
		"desc": "Una calle tomada por hombres armados. Elimina a todos: el último en caer suelta la llave. Con ella abre el cuarto del sur para extraer.",
		"enemies": [2, 3, 5],
	},
	{
		"name": "COMPLEJO INDUSTRIAL",
		"scene": "res://Scenes/Levels/Level2.tscn",
		"preview": "res://Assest/UI/preview_nivel2.png",
		"desc": "Naves amplias y pasillos largos. El último enemigo suelta la llave; la salida está en la esquina norte.",
		"enemies": [3, 5, 7],
	},
	{
		"name": "EDIFICIO DE CUARTOS",
		"scene": "res://Scenes/Levels/Level3.tscn",
		"preview": "res://Assest/UI/preview_nivel3.png",
		"desc": "Seis habitaciones conectadas por un pasillo, con patrullas y torretas. La llave la suelta el último enemigo de afuera y abre la sala del fondo, custodiada por un guardia.",
		"enemies": [4, 6, 9],
	},
	{"name": "PRÓXIMAMENTE", "scene": "", "preview": "", "desc": "Este nivel todavía está en desarrollo.", "enemies": [0, 0, 0]},
	{"name": "PRÓXIMAMENTE", "scene": "", "preview": "", "desc": "Este nivel todavía está en desarrollo.", "enemies": [0, 0, 0]},
]

## nivel más alto desbloqueado; el 1 siempre está abierto
var unlocked_index: int = 0
## nivel actual, -1 en un menú
var current_index: int = -1
var best_scores: Dictionary = {}  # "0" -> mejor puntaje
## ¿ya hizo el tutorial? si no, el menú lo recomienda
var tutorial_done: bool = false
## true en el tutorial (el reinicio vuelve a cargarlo)
var in_tutorial: bool = false

var _start_mode: int = 0  # START_FRESH / CARRY / RETRY de Global
var _victory: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# el color de la paleta fuera del mapa
	RenderingServer.set_default_clear_color(Color("#161923"))
	_load_progress()


# consultas

func level_count() -> int:
	return LEVELS.size()


## ¿existe la escena del nivel?
func is_playable(index: int) -> bool:
	if index < 0 or index >= LEVELS.size():
		return false
	var path: String = LEVELS[index]["scene"]
	return path != "" and ResourceLoader.exists(path)


func is_unlocked(index: int) -> bool:
	if not is_playable(index):
		return false
	return Settings.unlock_all_levels or index <= unlocked_index


func has_next_level() -> bool:
	return current_index >= 0 and is_playable(current_index + 1)


func best_score(index: int) -> int:
	return int(best_scores.get(str(index), 0))


# navegación

## campo de entrenamiento de 12 pasos (Scripts/Tutorial/tutorial.gd)
func start_tutorial() -> void:
	current_index = -1
	in_tutorial = true
	_start_mode = Global.START_FRESH
	_change_scene(TUTORIAL_SCENE)


func mark_tutorial_done() -> void:
	tutorial_done = true
	_save_progress()


func start_level(index: int, mode: int = 0) -> void:
	if not is_playable(index):
		return
	in_tutorial = false
	current_index = index
	_start_mode = mode
	_change_scene(LEVELS[index]["scene"])


func restart_level() -> void:
	if in_tutorial:
		start_tutorial()
		return
	if current_index < 0:
		go_to_menu()
		return
	start_level(current_index, Global.START_RETRY)


## sin vidas: se pierde todo y se vuelve al nivel 1 (los niveles desbloqueados se conservan)
func game_over_restart() -> void:
	start_level(0, Global.START_FRESH)


func next_level() -> void:
	if has_next_level():
		# al pasar de nivel se conserva vida, corazones, balas y puntaje
		start_level(current_index + 1, Global.START_CARRY)
	else:
		go_to_menu()


func go_to_menu() -> void:
	in_tutorial = false
	current_index = -1
	_change_scene(MAIN_MENU)


## pantalla de ajustes propia; al cerrarla vuelve al menú
func go_to_settings() -> void:
	current_index = -1
	_change_scene(SETTINGS_SCREEN)


func go_to_level_select() -> void:
	current_index = -1
	_change_scene(LEVEL_SELECT)


func _change_scene(path: String) -> void:
	_close_victory()
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


## la llama Level al cargarse (también sirve con F6)
func begin_level(index: int) -> void:
	current_index = index
	Global.reset_for_level(_start_mode)
	_start_mode = Global.START_FRESH


# victoria

func complete_level() -> void:
	if _victory != null:
		return
	var key := str(current_index)
	if Global.score > int(best_scores.get(key, 0)):
		best_scores[key] = Global.score
	# solo se desbloquea el siguiente si existe
	if current_index + 1 > unlocked_index and is_playable(current_index + 1):
		unlocked_index = current_index + 1
	_save_progress()

	_victory = VictoryScreen.new()
	get_tree().current_scene.add_child(_victory)


func _close_victory() -> void:
	if _victory != null and is_instance_valid(_victory):
		_victory.queue_free()
	_victory = null


# progreso guardado

func reset_progress() -> void:
	tutorial_done = false
	unlocked_index = 0
	best_scores.clear()
	_save_progress()


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_index", unlocked_index)
	cfg.set_value("progress", "best_scores", best_scores)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.save(SAVE_PATH)


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	unlocked_index = clampi(int(cfg.get_value("progress", "unlocked_index", 0)), 0, LEVELS.size() - 1)
	# el progreso nunca apunta a un nivel que no existe
	while unlocked_index > 0 and not is_playable(unlocked_index):
		unlocked_index -= 1
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	var scores: Variant = cfg.get_value("progress", "best_scores", {})
	if scores is Dictionary:
		best_scores = scores
