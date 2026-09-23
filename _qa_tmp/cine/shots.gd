extends Node

var _t: float = 0.0
var _step: int = 0
var _step_t: float = 0.0
var _shot_t: float = 0.0
var _n: int = 0
var _tag: String = "intro"
var _level_index: int = 2

func _ready() -> void:
	if get_parent() == get_tree().root and get_tree().current_scene != self:
		return
	call_deferred("_detach")

func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("level="):
			_level_index = int(a.substr(6))
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.start_level(_level_index)

func _shot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(960, 540)
	img.save_png("res://_qa_tmp/cine/%s_%02d.png" % [_tag, _n])
	_n += 1

func _level() -> Node:
	return get_tree().get_first_node_in_group("level")

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	_t += real
	_step_t += real
	_shot_t += real
	if _shot_t >= 1.0:
		_shot_t = 0.0
		if get_tree().current_scene != null:
			_shot()
	var lv := _level()
	match _step:
		0:
			if lv != null and lv.get("_briefing") != null and is_instance_valid(lv.get("_briefing")):
				print("intro done at ", _t)
				_advance("brief")
		1:
			if _step_t > 1.5:
				lv.get("_briefing").close()
				_advance("play")
		2:
			if _step_t > 2.0:
				Global.invuln_time = 999.0
				for e in get_tree().get_nodes_in_group("Enemies"):
					if e.has_method("is_alive") and e.is_alive() and not e.is_in_group("boss"):
						e.die()
				_advance("key")
		3:
			if _step_t > 1.5:
				Global.collect_key()
				_advance("door")
		4:
			if _step_t > 2.5:
				var p := get_tree().get_first_node_in_group("player") as Node2D
				var d := get_tree().get_first_node_in_group("doors") as Node2D
				if p != null and d != null:
					p.global_position = d.global_position + Vector2(0, -26)
				for dn in get_tree().get_nodes_in_group("doors"):
					dn.open()
				_advance("boss")
		5:
			if _step_t > 1.0 and not Global.cutscene_active:
				print("boss intro done at ", _t)
				_advance("fight")
		6:
			if _step_t > 3.0:
				var b := get_tree().get_first_node_in_group("boss")
				if b != null:
					b.set("phase", 2)
					b.call("die")
				_advance("down")
		7:
			if _step_t > 3.0 and not Global.cutscene_active:
				print("boss down done at ", _t)
				_advance("exit")
		8:
			if _step_t > 1.5:
				var p := get_tree().get_first_node_in_group("player") as Node2D
				var ex := get_tree().get_first_node_in_group("exit_zone") as Node2D
				if p != null and ex != null:
					p.global_position = ex.global_position
				_advance("outro")
		9:
			if _step_t > 12.0 or (get_tree().paused and _step_t > 2.0):
				print("outro done at ", _t, " paused=", get_tree().paused)
				_shot()
				get_tree().quit()
	if _t > 150.0:
		print("TIMEOUT step ", _step)
		get_tree().quit()

func _advance(tag: String) -> void:
	_step += 1
	_step_t = 0.0
	_tag = tag
	_n = 0
