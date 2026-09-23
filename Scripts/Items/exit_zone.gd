extends Area2D

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const BOSS_EXIT_DELAY := 1.6

@export var size: Vector2 = Vector2(36, 36)
@export var requires_key: bool = true

var _time: float = 0.0
var _done: bool = false
var _warn_cooldown: float = 0.0
var _boss_lock: float = 0.0


func _ready() -> void:
	add_to_group("exit_zone")
	collision_layer = 0
	collision_mask = 2
	light_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _unlocked() -> bool:
	return (Global.has_key or not requires_key) and not Global.boss_alive and _boss_lock <= 0.0


func _process(delta: float) -> void:
	_time += delta
	_warn_cooldown = maxf(0.0, _warn_cooldown - delta)
	if Global.boss_alive:
		_boss_lock = BOSS_EXIT_DELAY
	else:
		_boss_lock = maxf(0.0, _boss_lock - delta)
	queue_redraw()
	if _done or not _unlocked() or Global.health <= 0.0 or Global.cutscene_active:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_finish()
			return


func _on_body_entered(body: Node2D) -> void:
	if _done or not body.is_in_group("player") or Global.health <= 0.0 or Global.cutscene_active:
		return
	if requires_key and not Global.has_key:
		_warn("NECESITAS LA LLAVE PARA SALIR")
		return
	if Global.boss_alive:
		_warn("¡PRIMERO ACABA CON EL CONTRATISTA!")
		return
	if _boss_lock > 0.0:
		return
	_finish()


func _warn(text: String) -> void:
	if _warn_cooldown > 0.0:
		return
	Global.show_message(text)
	_warn_cooldown = 2.0


func _finish() -> void:
	_done = true
	var level := get_tree().get_first_node_in_group("level")
	if level != null and level.has_method("play_outro"):
		level.call_deferred("play_outro")
		return
	if level != null and level.has_method("end_twists"):
		level.end_twists()
	GameManager.complete_level()


func _draw() -> void:
	var boss_lock := Global.boss_alive
	var active := _unlocked()
	var color := UIStyle.BAR_EMPTY
	if boss_lock:
		color = UIStyle.LIFE
	elif active:
		color = UIStyle.BAR_FILL
	var pulse := 0.5 + 0.5 * sin(_time * (6.0 if boss_lock else 3.0))
	var rect := Rect2(-size * 0.5, size)
	var fill := 0.0
	if active:
		fill = 0.12 + pulse * 0.12
	elif boss_lock:
		fill = 0.08 + pulse * 0.14
	draw_rect(rect, Color(color, fill))
	draw_rect(rect, Color(color, 0.9), false, 1.5)
	if boss_lock:
		var k := size * 0.22
		draw_line(-k, k, Color(color, 0.6 + pulse * 0.4), 2.0)
		draw_line(Vector2(k.x, -k.y), Vector2(-k.x, k.y), Color(color, 0.6 + pulse * 0.4), 2.0)
		return
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = dir * (size.x * 0.32)
		draw_line(p, p + dir * -4.0, Color(color, 0.9), 1.5)
	draw_circle(Vector2.ZERO, 2.0, color)
