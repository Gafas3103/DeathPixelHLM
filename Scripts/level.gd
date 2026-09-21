extends Node2D

## Raíz de un nivel jugable (Scenes/Levels/LevelN.tscn): limpia el estado, crea la pausa, lleva los
## objetivos (llave, puerta, salida) y arma la cuadrícula de pathfinding con las colisiones del mapa.

const PauseMenu := preload("res://Scripts/UI/pause_menu.gd")
const KeyItemScene := preload("res://Scenes/Items/KeyItem.tscn")
const PickupScene := preload("res://Scenes/Items/Pickup.tscn")
const NoteItemScene := preload("res://Scenes/NoteItem.tscn")
const NO_CELL := Vector2i(-999999, -999999)

## posición en GameManager.LEVELS (0 = nivel 1)
@export var level_index: int = 0
@export var objective_start: String = "ELIMINA A TODOS LOS ENEMIGOS"
@export var objective_key_dropped: String = "RECOGE LA LLAVE"
@export var objective_with_key: String = "ABRE LA PUERTA"
@export var objective_door_open: String = "LLEGA A LA SALIDA"
@export var tile_size: int = 16
## true en el tutorial: no hay objetivos ni botín
@export var tutorial_mode: bool = false
## al matar al último aparece la nota (solo nivel 1)
@export var drop_note_on_clear: bool = false

@export_group("Botín de enemigos")
## probabilidad de botín cuando el jugador no lo necesita
@export_range(0.0, 1.0, 0.05) var loot_chance: float = 0.65
## balas por caja (mín. y máx.)
@export var ammo_drop_min: int = 12
@export var ammo_drop_max: int = 20
## vida que cura un botiquín
@export var health_drop_amount: int = 35

## rectángulos sólidos del mapa (los usa el minimapa)
var solid_rects: Array[Rect2] = []

## rectángulo del mapa
var map_bounds: Rect2 = Rect2()

var _key_dropped: bool = false
var _astar: AStarGrid2D = null
var _grid_rect: Rect2i = Rect2i()


func _ready() -> void:
	add_to_group("level")
	GameManager.begin_level(level_index)
	_build_grid()

	add_child(PauseMenu.new())
	if tutorial_mode:
		return

	Global.key_collected.connect(_on_key_collected)
	Global.door_opened.connect(_on_door_opened)
	Global.enemy_killed.connect(_on_enemy_killed)

	# la llave la suelta el último enemigo; si no hay, se busca una puesta a mano
	if get_tree().get_nodes_in_group("Enemies").is_empty():
		_key_dropped = true
		Global.set_objective("ENCUENTRA LA LLAVE")
	else:
		Global.set_objective(objective_start)
	_intro_hints()


# botín

func _on_enemy_killed(pos: Vector2) -> void:
	# viene de una colisión de bala: crear física va diferido
	call_deferred("_spawn_drops", pos)


func _spawn_drops(pos: Vector2) -> void:
	# la llave cae al morir el último de afuera; los guards_exit no cuentan
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
		key.position = pos
		add_child(key)
		Global.set_objective(objective_key_dropped)
		if drop_note_on_clear:
			Global.show_message("¡LLAVE Y NOTA! · [E] PARA LEER LA NOTA")
		elif guards_left > 0:
			Global.show_message("¡LLAVE! QUEDA UN CUSTODIO EN LA SALIDA")
		else:
			Global.show_message("¡EL ÚLTIMO SUELTA LA LLAVE!")
		if drop_note_on_clear:
			var note := NoteItemScene.instantiate() as Node2D
			note.position = pos + Vector2(-22, 6)
			add_child(note)

	# según lo que le falte al jugador
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
		# si también cae la llave, sale un poco al lado
		pickup.position = pos + (Vector2(18, -8) if last_enemy else Vector2.ZERO)
		add_child(pickup)


## tipo de botín: 0 balas de rifle, 1 botiquín, 2 corazón, 3 cartuchos, -1 nada.
## Cuanto más falta algo, más probable; la dificultad cambia cuánto suelta.
func _roll_loot() -> int:
	var hard := Settings.difficulty >= 2
	var rifle_total := Global.total_ammo(0)
	var shell_total := Global.total_ammo(1)
	var health_ratio := Global.health / Global.max_health
	var missing_hearts := Global.MAX_LIVES - Global.lives

	# si estás mal, siempre cae algo (en Difícil hay que estar peor)
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


## consejos al empezar el nivel 1 si no hiciste el tutorial
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


func _on_key_collected() -> void:
	Global.show_message("LLAVE OBTENIDA")
	# sin puertas, el objetivo pasa a la salida
	if get_tree().get_nodes_in_group("doors").is_empty():
		Global.set_objective(objective_door_open)
	else:
		Global.set_objective(objective_with_key)


func _on_door_opened() -> void:
	Global.show_message("¡PUERTA ABIERTA!")
	if Global.has_key:
		Global.set_objective(objective_door_open)


# pathfinding

## camino de from a to rodeando paredes, vacío si no hay
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


## ¿se puede caminar ahí?
func is_walkable(point: Vector2) -> bool:
	if _astar == null:
		return true
	return _is_open(_cell_of(point))


## marca o desmarca un área como sólida (las puertas al abrirse)
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


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / float(tile_size)).floor())


func _is_open(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


func _nearest_open_cell(point: Vector2) -> Vector2i:
	var c := _cell_of(point)
	if _is_open(c):
		return c
	# cae dentro de una pared: celda libre más cercana
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


## la cámara no sale del mapa
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
	var covered := {}  # celdas con algún tile

	for layer in layers:
		var has_physics := layer.tile_set.get_physics_layers_count() > 0 and layer.collision_enabled
		for cell in layer.get_used_cells():
			# celda con tile que no existe en el atlas: Godot no la dibuja, no cuenta
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

	# fuera del mapa = sólido
	for x in range(_grid_rect.position.x, _grid_rect.end.x):
		for y in range(_grid_rect.position.y, _grid_rect.end.y):
			var id := Vector2i(x, y)
			if not covered.has(id):
				_astar.set_point_solid(id, true)

	for rect in solid_rects:
		set_solid_rect(rect, true)

	# las puertas cerradas también bloquean
	for door in get_tree().get_nodes_in_group("doors"):
		if door.has_method("get_solid_rect") and not door.is_open:
			set_solid_rect(door.get_solid_rect(), true)
