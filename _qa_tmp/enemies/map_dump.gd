extends Node

var _frames: int = 0
var _idx: int = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	GameManager.start_level(_idx, Global.START_RETRY)


func _physics_process(_d: float) -> void:
	_frames += 1
	if _frames != 30:
		return
	var lv := get_tree().get_first_node_in_group("level")
	var b: Rect2 = lv.map_bounds
	print("bounds ", b)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var exit := get_tree().get_first_node_in_group("exit_zone") as Node2D
	var y := b.position.y + 8.0
	while y < b.end.y:
		var row := ""
		var x := b.position.x + 8.0
		while x < b.end.x:
			var p := Vector2(x, y)
			var ch := "#"
			if lv.is_walkable(p):
				ch = "."
			if player != null and player.global_position.distance_to(p) < 8.0:
				ch = "P"
			if exit != null and exit.global_position.distance_to(p) < 8.0:
				ch = "X"
			row += ch
			x += 16.0
		print(row)
		y += 16.0
	get_tree().quit()
