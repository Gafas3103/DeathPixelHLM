extends CharacterBody2D

@export var speed: float = 300.0
@export var is_active: bool = false 

func _physics_process(delta):
	if Input.is_action_just_pressed("action"):
		is_active = not is_active

	if is_active:
		look_at(get_global_mouse_position())

		var direction = Vector2.ZERO

		if Input.is_action_pressed("move_up"):
			direction = transform.x
		elif Input.is_action_pressed("move_down"):
			direction = -transform.x

		velocity = direction * speed
	else:
		velocity = Vector2.ZERO 

	move_and_slide()
