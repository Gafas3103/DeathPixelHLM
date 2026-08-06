extends CharacterBody2D


const SPEED = 300.0
@export var speed = 300
func _physics_process(delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()
