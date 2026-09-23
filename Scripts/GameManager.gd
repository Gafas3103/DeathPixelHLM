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
		"twist": "",
		"mood": "atardecer",
		"variants": {"pesado": 1},
		"boss": false,
		"par_time": 150.0,
	},
	{
		"name": "COMPLEJO INDUSTRIAL",
		"scene": "res://Scenes/Levels/Level2.tscn",
		"preview": "res://Assest/UI/preview_nivel2.png",
		"desc": "Naves amplias y pasillos largos, sin electricidad. El último enemigo suelta la llave; la salida está en la esquina norte.",
		"enemies": [3, 5, 7],
		"twist": "apagon",
		"mood": "apagon",
		"variants": {"tirador": 2, "pesado": 1},
		"boss": false,
		"par_time": 210.0,
	},
	{
		"name": "EDIFICIO DE CUARTOS",
		"scene": "res://Scenes/Levels/Level3.tscn",
		"preview": "res://Assest/UI/preview_nivel3.png",
		"desc": "Seis habitaciones conectadas por un pasillo, con patrullas y torretas. Al tomar la llave salta la alarma: llegan refuerzos y el reloj corre.",
		"enemies": [4, 6, 9],
		"twist": "alarma",
		"mood": "noche",
		"variants": {"rapido": 2, "pesado": 1, "tirador": 1},
		"boss": false,
		"par_time": 240.0,
	},
	{
		"name": "LOS MUELLES",
		"scene": "res://Scenes/Levels/Level4.tscn",
		"preview": "res://Assest/UI/preview_nivel4.png",
		"desc": "Contenedores, grúas y niebla. Te están cazando: cada cierto tiempo delatan tu posición a todos.",
		"enemies": [5, 7, 10],
		"twist": "caceria",
		"mood": "noche",
		"variants": {"rapido": 2, "tirador": 2, "pesado": 1},
		"boss": false,
		"par_time": 270.0,
	},
	{
		"name": "LA SEDE",
		"scene": "res://Scenes/Levels/Level5.tscn",
		"preview": "res://Assest/UI/preview_nivel5.png",
		"desc": "La torre donde El Contratista reparte sus encargos. Él te espera al final.",
		"enemies": [6, 8, 11],
		"twist": "sede",
		"mood": "sede",
		"variants": {"pesado": 2, "tirador": 2, "rapido": 2},
		"boss": true,
		"par_time": 330.0,
	},
]

const TWISTS := {
	"": {"name": "ASALTO", "desc": "Limpia la zona, toma la llave y extrae."},
	"apagon": {"name": "APAGÓN", "desc": "No hay luz. Con la linterna apagada [L] casi no te ven, pero tú tampoco ves mucho. Disparar te delata."},
	"alarma": {"name": "ALARMA", "desc": "Al tomar la llave salta la alarma: llegan refuerzos y tienes poco tiempo para salir."},
	"caceria": {"name": "CACERÍA", "desc": "Un informante delata tu posición cada cierto tiempo. No te quedes quieto."},
	"sede": {"name": "LA SEDE", "desc": "Territorio del Contratista. Sus mejores hombres y él mismo."},
}

const RANKS: Array[String] = ["C", "B", "A", "S"]

## nivel más alto desbloqueado; el 1 siempre está abierto
var unlocked_index: int = 0
## nivel actual, -1 en un menú
var current_index: int = -1
var best_scores: Dictionary = {}  # "0" -> mejor puntaje
var best_ranks: Dictionary = {}
var prologue_seen: bool = false
var game_completed: bool = false
var last_rank: String = ""
var last_rank_new_best: bool = false
## ¿ya hizo el tutorial? si no, el menú lo recomienda
var tutorial_done: bool = false
## true en el tutorial (el reinicio vuelve a cargarlo)
var in_tutorial: bool = false

var _start_mode: int = 0  # START_FRESH / CARRY / RETRY de Global
var _victory: CanvasLayer = null
var _briefing_pending: bool = false


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
	if current_index < 0 or is_final_level(current_index):
		return false
	return is_playable(current_index + 1)


func best_score(index: int) -> int:
	return int(best_scores.get(str(index), 0))


func best_rank(index: int) -> String:
	return String(best_ranks.get(str(index), ""))


func level_data(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return LEVELS[index]


func twist_info(index: int) -> Dictionary:
	var key := String(level_data(index).get("twist", ""))
	return TWISTS.get(key, TWISTS[""])


func boss_level_index() -> int:
	var last := -1
	for i in range(LEVELS.size()):
		if not is_playable(i):
			continue
		if bool(LEVELS[i].get("boss", false)):
			return i
		last = i
	return last


func is_boss_level(index: int) -> bool:
	return index >= 0 and index == boss_level_index()


func is_final_level(index: int) -> bool:
	return is_boss_level(index)


func take_briefing() -> bool:
	var pending := _briefing_pending
	_briefing_pending = false
	return pending


func compute_rank() -> String:
	var par := float(level_data(current_index).get("par_time", 180.0))
	var points := 0
	var ratio := Global.level_time / maxf(par, 1.0)
	if ratio <= 1.0:
		points += 3
	elif ratio <= 1.5:
		points += 2
	elif ratio <= 2.2:
		points += 1
	if Global.deaths_this_level == 0:
		points += 2
	elif Global.deaths_this_level == 1:
		points += 1
	if Global.times_detected == 0:
		points += 3
	elif Global.times_detected <= 2:
		points += 2
	elif Global.times_detected <= 5:
		points += 1
	if points >= 7:
		return "S"
	if points >= 5:
		return "A"
	if points >= 3:
		return "B"
	return "C"


func rank_value(rank: String) -> int:
	return RANKS.find(rank)


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
	_briefing_pending = mode != Global.START_RETRY
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
	Engine.time_scale = 1.0
	Global.level_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func mark_prologue_seen() -> void:
	prologue_seen = true
	_save_progress()


func mark_game_completed() -> void:
	game_completed = true
	_save_progress()


## la llama Level al cargarse (también sirve con F6)
func begin_level(index: int) -> void:
	current_index = index
	Global.reset_for_level(_start_mode)
	_start_mode = Global.START_FRESH


# victoria

func complete_level() -> void:
	if _victory != null:
		return
	Global.level_active = false
	var key := str(current_index)
	if Global.score > int(best_scores.get(key, 0)):
		best_scores[key] = Global.score
	last_rank = compute_rank()
	last_rank_new_best = rank_value(last_rank) > rank_value(best_rank(current_index))
	if last_rank_new_best:
		best_ranks[key] = last_rank
	if is_final_level(current_index):
		game_completed = true
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
	best_ranks.clear()
	prologue_seen = false
	game_completed = false
	_save_progress()


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked_index", unlocked_index)
	cfg.set_value("progress", "best_scores", best_scores)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "best_ranks", best_ranks)
	cfg.set_value("progress", "prologue_seen", prologue_seen)
	cfg.set_value("progress", "game_completed", game_completed)
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
	var ranks: Variant = cfg.get_value("progress", "best_ranks", {})
	if ranks is Dictionary:
		best_ranks = ranks
	prologue_seen = bool(cfg.get_value("progress", "prologue_seen", false))
	game_completed = bool(cfg.get_value("progress", "game_completed", false))
