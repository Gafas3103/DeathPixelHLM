extends Node2D

@export var speed: float = 600.0

func _ready():
	# Elimina la bala automáticamente después de 3 segundos para optimizar memoria
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _process(delta: float) -> void:
	# Hace que la bala avance en línea recta hacia donde apunta
	position += transform.x * speed * delta
