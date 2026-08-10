extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event is InputEventKey and event.pressed:
		get_tree().paused = false
		queue_free()
