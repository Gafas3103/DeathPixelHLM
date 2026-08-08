extends CharacterBody2D

const BALA_SCENE = preload("res://Scenes/Bala.tscn")

@export var speed: float = 90.0
@export var max_health: float = 50.0
@export var vision_range: float = 340.0
@export var attack_range: float = 220.0
@export var shot_damage: float = 10.0
@export var fire_rate: float = 1.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_ray: RayCast2D = $VisionRay
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle

var health: float = 0.0
var is_dead: bool = false

var _cooldown: float = 0.0

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	Global.register_enemy()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_cooldown = maxf(_cooldown - delta, 0.0)

	var target := _find_target()
	if target == null:
		velocity = Vector2.ZERO
		_play("Stop")
		move_and_slide()
		return

	var to_target: Vector2 = target.global_position - global_position
	rotation = to_target.angle()

	if to_target.length() > attack_range:
		velocity = to_target.normalized() * speed
		_play("Walk")
	else:
		velocity = Vector2.ZERO
		_play("Attack")
		if _cooldown <= 0.0:
			_cooldown = fire_rate
			_shoot()

	move_and_slide()

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := vision_range
	for p in get_tree().get_nodes_in_group("player"):
		if Global.is_dead or not p.is_active:
			continue
		var d := global_position.distance_to(p.global_position)
		if d <= best_distance and _has_line_of_sight(p):
			best_distance = d
			best = p
	return best

func _has_line_of_sight(p: Node2D) -> bool:
	vision_ray.target_position = vision_ray.to_local(p.global_position)
	vision_ray.force_raycast_update()
	if not vision_ray.is_colliding():
		return true
	return vision_ray.get_collider() == p

func _shoot() -> void:
	var bullet = BALA_SCENE.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.global_rotation = global_rotation
	bullet.damage = shot_damage
	bullet.setup(self, true)
	get_tree().current_scene.add_child(bullet)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	_play("Dead")
	body_shape.set_deferred("disabled", true)
	set_physics_process(false)
	Global.enemy_died()

func _play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
