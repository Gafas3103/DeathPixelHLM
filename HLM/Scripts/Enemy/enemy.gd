extends CharacterBody2D

@export var speed: float = 100.0

func _physics_process(delta: float) -> void:
	# Lógica Top-Down para enemigos (sin gravedad de plataformas)
	move_and_slide()
