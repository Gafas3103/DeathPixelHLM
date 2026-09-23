extends Node

const OUT := "C:/Users/crist/AppData/Local/Temp/claude/C--Users-crist-OneDrive-Documentos-SWAT2D/f3e8f042-81eb-4cf2-b044-6d3d4328f17c/scratchpad/"

var _step: int = 0
var _wait: int = 0


func _ready() -> void:
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	GameManager.start_level(2)
	_step = 1
	_wait = 40


func _level() -> Node:
	return get_tree().get_first_node_in_group("level")


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _shot(file_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + file_name)
	print("SHOT ", file_name, " ", img.get_size())


func _close_briefing() -> void:
	var lv := _level()
	if lv == null:
		return
	var b = lv.get("_briefing")
	if b != null and is_instance_valid(b) and b.has_method("close"):
		b.close()


func _process(_d: float) -> void:
	if _wait > 0:
		_wait -= 1
		return
	match _step:
		1:
			_shot("hud_0_briefing.png")
			_close_briefing()
			Global.invuln_time = 99999.0
			_wait = 90
			_step = 2
		2:
			for e in get_tree().get_nodes_in_group("Enemies"):
				if e.has_method("is_alive") and e.is_alive():
					e.die()
			_wait = 20
			_step = 3
		3:
			var keys := get_tree().get_nodes_in_group("key_items")
			if keys.size() > 0:
				_player().global_position = keys[0].global_position
			_wait = 150
			_step = 4
		4:
			_shot("hud_1_alarm.png")
			for d in get_tree().get_nodes_in_group("doors"):
				d.try_open()
			_wait = 150
			_step = 5
		5:
			var boss = Global.boss_node
			if boss != null and is_instance_valid(boss) and boss.has_method("take_damage"):
				boss.take_damage(float(boss.get("max_health")) * 0.4)
			_wait = 40
			_step = 6
		6:
			_shot("hud_2_boss.png")
			GameManager.start_level(1)
			_wait = 40
			_step = 7
		7:
			_close_briefing()
			Global.invuln_time = 99999.0
			_wait = 120
			_step = 8
		8:
			_shot("hud_3_apagon.png")
			get_tree().quit()
