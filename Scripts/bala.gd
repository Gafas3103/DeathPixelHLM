extends Area2D

@export var speed: float = 600.0
@export var damage: float = 25.0
@export var lifetime: float = 3.0

var shooter: Node2D = null

var _life: float = 0.0

func _ready() -> void:
	_life = lifetime
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(from: Node2D, from_enemy: bool) -> void:
	shooter = from
	collision_layer = 8
	if from_enemy:
		collision_mask = 1 | 2
	else:
		collision_mask = 1 | 4

func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	global_position += transform.x * speed * delta

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area == shooter:
		return
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
