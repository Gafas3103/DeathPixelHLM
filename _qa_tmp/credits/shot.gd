extends Node

var _f: int = 0
var _menu: Node = null

func _ready() -> void:
	_menu = load("res://Scenes/UI/MainMenu.tscn").instantiate()
	add_child(_menu)

func _process(_d: float) -> void:
	_f += 1
	if _f == 5:
		_menu.call("_on_credits")
	if _f == 40:
		get_viewport().get_texture().get_image().save_png("res://_qa_tmp/credits/final_credits.png")
		get_tree().quit()
