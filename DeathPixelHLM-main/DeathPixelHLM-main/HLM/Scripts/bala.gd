extends Node2D

@export var speed: float = 600.0

func _process(delta: float) -> void:
	# Hace que la bala avance en línea recta hacia donde apunta
	position += transform.x * speed * delta
