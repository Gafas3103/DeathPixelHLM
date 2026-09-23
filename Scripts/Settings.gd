extends Node

## Ajustes (autoload Settings): se guardan en user://settings.cfg y se aplican de verdad.
## El menú solo llama a los setters de aquí.

signal changed

const SAVE_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144]  # 0 = sin límite
const DIFFICULTIES: Array[String] = ["FÁCIL", "NORMAL", "DIFÍCIL"]

## acciones reasignables y su nombre en el menú
const REBINDABLE := {
	"move_up": "MOVER ARRIBA",
	"move_down": "MOVER ABAJO",
	"move_left": "MOVER IZQUIERDA",
	"move_right": "MOVER DERECHA",
	"action": "INTERACTUAR",
	"reload": "RECARGAR",
	"melee": "MELEE RÁPIDO (CUCHILLO)",
	"sneak": "SIGILO (CAMINAR LENTO)",
	"weapon_next": "CAMBIAR ARMA",
	"flashlight": "LINTERNA",
}

const LIGHTING_QUALITIES: Array[String] = ["BAJA", "MEDIA", "ALTA"]
const DEFAULT_LIGHTING_QUALITY := 2

# gráficos
var fullscreen: bool = true
var resolution_index: int = 0
var vsync: bool = true
var fps_index: int = 0
var brightness: float = 1.0
var show_fps: bool = false
var lighting_quality: int = DEFAULT_LIGHTING_QUALITY

# audio (0.0 a 1.0)
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.8
var muted: bool = false

# general
var difficulty: int = 1
var show_minimap: bool = true
var crosshair_scale: float = 1.0
var unlock_all_levels: bool = false

# controles
var keybinds: Dictionary = {}  # acción -> physical_keycode
var _default_keys: Dictionary = {}  # los originales

var _save_queued: bool = false
var _overlay_layer: CanvasLayer
var _brightness_rect: ColorRect
var _fps_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_keys()
	_build_overlay()
	load_settings()
	apply_all()


func _process(_delta: float) -> void:
	if _fps_label != null and _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# guardar / cargar

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "resolution_index", resolution_index)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "fps_index", fps_index)
	cfg.set_value("graphics", "brightness", brightness)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("graphics", "lighting_quality", lighting_quality)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("general", "difficulty", difficulty)
	cfg.set_value("general", "show_minimap", show_minimap)
	cfg.set_value("general", "crosshair_scale", crosshair_scale)
	cfg.set_value("general", "unlock_all_levels", unlock_all_levels)
	cfg.set_value("controls", "keybinds", keybinds)
	cfg.save(SAVE_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", fullscreen))
	resolution_index = clampi(int(cfg.get_value("graphics", "resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(cfg.get_value("graphics", "vsync", vsync))
	fps_index = clampi(int(cfg.get_value("graphics", "fps_index", fps_index)), 0, FPS_LIMITS.size() - 1)
	brightness = clampf(float(cfg.get_value("graphics", "brightness", brightness)), 0.5, 1.5)
	show_fps = bool(cfg.get_value("graphics", "show_fps", show_fps))
	lighting_quality = clampi(int(cfg.get_value("graphics", "lighting_quality", lighting_quality)), 0, LIGHTING_QUALITIES.size() - 1)
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", muted))
	difficulty = clampi(int(cfg.get_value("general", "difficulty", difficulty)), 0, DIFFICULTIES.size() - 1)
	show_minimap = bool(cfg.get_value("general", "show_minimap", show_minimap))
	crosshair_scale = clampf(float(cfg.get_value("general", "crosshair_scale", crosshair_scale)), 0.5, 2.0)
	unlock_all_levels = bool(cfg.get_value("general", "unlock_all_levels", unlock_all_levels))
	var saved: Variant = cfg.get_value("controls", "keybinds", {})
	if saved is Dictionary:
		keybinds = saved


# aplicar

func apply_all() -> void:
	apply_display()
	apply_audio()
	apply_brightness()
	_apply_keybinds()
	if _fps_label != null:
		_fps_label.visible = show_fps


func apply_display() -> void:
	# en el editor embebido puede no tener efecto
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = RESOLUTIONS[resolution_index]
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.screen_get_size()
		var origin := DisplayServer.screen_get_position()
		DisplayServer.window_set_position(origin + (screen - size) / 2)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[fps_index]


func apply_audio() -> void:
	_set_bus("Master", master_volume, muted)
	_set_bus("Music", music_volume, false)
	_set_bus("SFX", sfx_volume, false)


func _set_bus(bus_name: String, linear: float, mute: bool) -> void:
	var idx := _ensure_bus(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, mute or linear <= 0.001)


## crea los buses Music y SFX si no existen
func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


func apply_brightness() -> void:
	if _brightness_rect == null:
		return
	var mat := _brightness_rect.material as CanvasItemMaterial
	if brightness < 1.0:
		# oscurecer: capa negra
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		_brightness_rect.color = Color(0, 0, 0, (1.0 - brightness))
	else:
		# aclarar: capa blanca aditiva
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_brightness_rect.color = Color(1, 1, 1, (brightness - 1.0) * 0.4)


func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 100
	add_child(_overlay_layer)

	_brightness_rect = ColorRect.new()
	_brightness_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_rect.material = CanvasItemMaterial.new()
	_brightness_rect.color = Color(0, 0, 0, 0)
	_overlay_layer.add_child(_brightness_rect)

	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fps_label.offset_left = -60
	_fps_label.offset_right = 60
	_fps_label.offset_top = 4
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color("#39E58C"))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.visible = false
	_overlay_layer.add_child(_fps_label)


# setters

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	_commit()


func set_resolution_index(value: int) -> void:
	resolution_index = clampi(value, 0, RESOLUTIONS.size() - 1)
	apply_display()
	_commit()


func set_vsync(value: bool) -> void:
	vsync = value
	apply_display()
	_commit()


func set_fps_index(value: int) -> void:
	fps_index = clampi(value, 0, FPS_LIMITS.size() - 1)
	apply_display()
	_commit()


func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.5, 1.5)
	apply_brightness()
	_commit()


func set_show_fps(value: bool) -> void:
	show_fps = value
	if _fps_label != null:
		_fps_label.visible = value
	_commit()


func set_lighting_quality(value: int) -> void:
	lighting_quality = clampi(value, 0, LIGHTING_QUALITIES.size() - 1)
	_commit()


func set_master_volume(value: float) -> void:
	master_volume = value
	apply_audio()
	_commit()


func set_music_volume(value: float) -> void:
	music_volume = value
	apply_audio()
	_commit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	apply_audio()
	_commit()


func set_muted(value: bool) -> void:
	muted = value
	apply_audio()
	_commit()


func set_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, DIFFICULTIES.size() - 1)
	_commit()


func set_show_minimap(value: bool) -> void:
	show_minimap = value
	_commit()


func set_crosshair_scale(value: float) -> void:
	crosshair_scale = clampf(value, 0.5, 2.0)
	_commit()


func set_unlock_all_levels(value: bool) -> void:
	unlock_all_levels = value
	_commit()


## guarda con retraso: un slider llama esto decenas de veces por segundo
func _commit() -> void:
	changed.emit()
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		_save_queued = false
		save_settings())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_queued:
		save_settings()


## valores de fábrica de gráficos, audio y general (no toca las teclas)
func reset_defaults() -> void:
	fullscreen = true
	resolution_index = 0
	vsync = true
	fps_index = 0
	brightness = 1.0
	show_fps = false
	lighting_quality = DEFAULT_LIGHTING_QUALITY
	master_volume = 0.8
	music_volume = 0.7
	sfx_volume = 0.8
	muted = false
	difficulty = 1
	show_minimap = true
	crosshair_scale = 1.0
	unlock_all_levels = false
	apply_all()
	_commit()


# dificultad

## multiplicadores [FÁCIL, NORMAL, DIFÍCIL]; el balance se ajusta aquí
const DIFFICULTY_TABLE := {
	"damage": [0.6, 1.0, 1.5],  # daño de sus balas
	"reaction": [1.5, 1.0, 0.6],  # tarda en disparar tras detectarte
	"detect_time": [1.8, 1.2, 0.8],  # segundos para detectarte de cerca (menos = más listo)
	"vision_range": [0.75, 1.0, 1.25],  # distancia de visión
	"vision_angle": [0.85, 1.0, 1.15],  # ancho del cono
	"spread": [1.6, 1.0, 0.55],  # dispersión (menos = mejor puntería)
	"fire_rate": [1.3, 1.0, 0.8],  # intervalo entre disparos
	"speed": [0.85, 1.0, 1.12],  # velocidad
	"alert": [0.7, 1.0, 1.4],  # a quién avisan
	"hearing": [0.7, 1.0, 1.3],  # qué tan lejos oyen
	"give_up": [0.6, 1.0, 1.6],  # cuánto te buscan
	"health": [0.8, 1.0, 1.25],  # vida
	"loot_chance": [1.25, 1.0, 0.55],  # probabilidad de botín
	"loot_amount": [1.3, 1.0, 0.75],  # balas / curación por objeto
	"score": [0.75, 1.0, 1.5],  # puntaje
}
## reserva de rifle y cartuchos con los que empiezas un nivel desde cero
const START_RESERVE: Array[int] = [60, 40, 24]
const START_SHELLS: Array[int] = [18, 12, 6]
## segundos de gracia al aparecer
const SPAWN_GRACE: Array[float] = [6.0, 4.0, 3.0]

const DIFFICULTY_DESCRIPTIONS: Array[String] = [
	"FÁCIL: menos enemigos, más lentos y con peor puntería; te detectan más tarde. Más munición y botiquines. Recarga automática.",
	"NORMAL: la experiencia base. Recarga automática al vaciar el cargador.",
	"DIFÍCIL: más enemigos, más rápidos y precisos que te detectan y te oyen antes. Poco botín. La recarga es SOLO manual [R].",
]


## multiplicador de una categoría para la dificultad actual
func diff(key: String) -> float:
	return float(DIFFICULTY_TABLE[key][difficulty])


## multiplicador del daño enemigo
func enemy_damage_mult() -> float:
	return diff("damage")


## multiplicador del tiempo de reacción (más alto = más lento)
func enemy_reaction_mult() -> float:
	return diff("reaction")


func start_reserve() -> int:
	return START_RESERVE[difficulty]


func start_shells() -> int:
	return START_SHELLS[difficulty]


func spawn_grace() -> float:
	return SPAWN_GRACE[difficulty]


## en Difícil no hay recarga automática
func auto_reload() -> bool:
	return difficulty < 2


# teclas

func _capture_default_keys() -> void:
	for action in REBINDABLE:
		var ev := _primary_key_event(action)
		if ev != null:
			_default_keys[action] = ev.physical_keycode


func _primary_key_event(action: String) -> InputEventKey:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev
	return null


## nombre legible de la tecla de una acción
func key_name(action: String) -> String:
	var ev := _primary_key_event(action)
	if ev == null:
		return "—"
	var code: int = ev.physical_keycode
	if code == 0:
		code = ev.keycode
	elif DisplayServer.get_name() != "headless":
		code = DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(code).to_upper()


## "" si se pudo, o el nombre de la acción que ya usa esa tecla
func rebind(action: String, event: InputEventKey) -> String:
	var code: int = event.physical_keycode
	if code == 0:
		return "TECLA NO VÁLIDA"
	for other in REBINDABLE:
		if other == action:
			continue
		var ev := _primary_key_event(other)
		if ev != null and ev.physical_keycode == code:
			return String(REBINDABLE[other])
	_set_primary_key(action, code)
	keybinds[action] = code
	_commit()
	return ""


func reset_keybinds() -> void:
	for action in _default_keys:
		_set_primary_key(action, int(_default_keys[action]))
	keybinds.clear()
	_commit()


func _apply_keybinds() -> void:
	for action in keybinds:
		if REBINDABLE.has(action):
			_set_primary_key(String(action), int(keybinds[action]))


## cambia solo la tecla principal (las alternativas se conservan)
func _set_primary_key(action: String, physical_code: int) -> void:
	if not InputMap.has_action(action):
		return
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var replaced := false
	for ev in events:
		if not replaced and ev is InputEventKey:
			var new_ev := InputEventKey.new()
			new_ev.physical_keycode = physical_code as Key
			InputMap.action_add_event(action, new_ev)
			replaced = true
		else:
			InputMap.action_add_event(action, ev)
	if not replaced:
		var new_ev := InputEventKey.new()
		new_ev.physical_keycode = physical_code as Key
		InputMap.action_add_event(action, new_ev)
