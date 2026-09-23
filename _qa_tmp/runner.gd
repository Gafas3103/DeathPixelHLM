extends Node

var _levels: Array = []
var _frames: int = 0
var _phase: int = 0

func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")
		return

func _detach() -> void:
	var r := get_tree().root
	var me := self
	get_parent().remove_child(me)
	r.add_child(me)
	get_tree().current_scene = null
	_start()

func _start() -> void:
	var files: Array[String] = []
	_collect("res://Scripts", files)
	_collect("res://Scenes", files)
	var bad := 0
	for f in files:
		var r = load(f)
		if r == null:
			print("LOAD_FAIL ", f)
			bad += 1
		elif r is GDScript and not r.can_instantiate():
			print("SCRIPT_BAD ", f)
			bad += 1
	print("LOADED ", files.size(), " BAD ", bad)
	for i in range(GameManager.level_count()):
		if GameManager.is_playable(i):
			_levels.append(i)
	_levels.append(-1)
	_next()

func _next() -> void:
	if _levels.is_empty():
		print("ALL_LEVELS_DONE")
		get_tree().quit()
		return
	var idx: int = _levels.pop_front()
	_frames = 0
	_phase = 0
	if idx == -1:
		print("RUN tutorial")
		GameManager.start_tutorial()
	else:
		print("RUN level ", idx)
		GameManager.start_level(idx)

func _process(_d: float) -> void:
	if _phase < 0:
		return
	_frames += 1
	var cs := get_tree().current_scene
	if _frames >= 10 and _frames <= 170 and cs != null:
		var lv := get_tree().get_first_node_in_group("level")
		if lv != null:
			for c in lv.get_children():
				if "skipped" in c and not c.skipped:
					c.skipped = true
					print("  skipped cutscene at frame ", _frames)
			var b = lv.get("_briefing")
			if b != null and is_instance_valid(b) and b.has_method("close") and not b.is_queued_for_deletion():
				b.close()
				print("  closed briefing at frame ", _frames, " active=", Global.level_active)
	if _frames == 180 and cs != null:
		print("  scene=", cs.name, " enemies=", get_tree().get_nodes_in_group("Enemies").size())
		if not GameManager.in_tutorial:
			for e in get_tree().get_nodes_in_group("Enemies"):
				if e.has_method("die") and e.has_method("is_alive") and e.is_alive():
					e.die()
	if _frames == 300 and cs != null and not GameManager.in_tutorial:
		print("  key_items=", get_tree().get_nodes_in_group("key_items").size(), " objective=", Global.objective)
		Global.collect_key()
		for dnode in get_tree().get_nodes_in_group("doors"):
			if dnode.has_method("open"):
				dnode.open()
	if _frames == 420:
		_next()

func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".gdshader"):
			out.append(dir + "/" + f)
