extends Node

const BossScene := preload("res://Scenes/Boss.tscn")
const EnemyScene := preload("res://Scenes/Enemy.tscn")

var _frames: int = 0
var _boss: Node = null
var _player: Node2D = null
var _level: Node = null
var _step: int = 0
var _out: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	Settings.fullscreen = false
	Settings.apply_display()
	_out = ProjectSettings.globalize_path("res://_qa_tmp/enemies/")
	GameManager.start_level(2, Global.START_RETRY)
	_step = 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + name + ".png")
	print("SHOT ", name)


func _physics_process(_d: float) -> void:
	_frames += 1
	match _step:
		1:
			var cs := get_tree().current_scene
			if _frames > 30 and cs != null and cs.name == "Level3":
				_setup()
				_step = 2
				_frames = 0
		2:
			if _boss != null and is_instance_valid(_boss):
				_boss.set("_action_cd", 99.0)
			if _frames == 20:
				_shot("b01_intro")
			if _frames == 150:
				_force(2)
			if _frames == 172:
				_shot("b02_fan_tele")
			if _frames == 200:
				_boss.set("phase", 1)
				_force(4)
			if _frames == 222:
				_shot("b03_dash_tele")
			if _frames == 300:
				_boss.set("phase", 2)
				_force(3)
			if _frames == 322:
				_shot("b04_ring_tele")
			if _frames == 350:
				_shot("b05_ring_fire")
			if _frames == 420:
				_force(7)
			if _frames == 440:
				_shot("b06_stomp")
			if _frames == 470:
				_force(1)
			if _frames == 492:
				_shot("b07_burst")
			if _frames == 530:
				_boss.set("_mode", 2)
				_boss.set("_mode_time", 0.0)
				_boss.take_damage(10.0)
			if _frames == 540:
				_shot("b08_shield")
			if _frames == 620:
				_spawn_variants()
			if _frames == 680:
				_shot("b09_variants")
			if _frames == 700:
				_boss.set("_mode", 1)
				_boss.set("health", 5.0)
				_boss.take_damage(50.0)
			if _frames == 712:
				_shot("b10_death")
			if _frames == 800:
				_shot("b11_after")
				print("SHOTS_DONE time_scale=", Engine.time_scale)
				get_tree().quit()


func _force(action: int) -> void:
	_boss.set("_action", 0)
	_boss.call("_start_action", action, _player)


func _setup() -> void:
	_level = get_tree().get_first_node_in_group("level")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	for e in get_tree().get_nodes_in_group("Enemies"):
		if e.has_method("die") and e.is_alive():
			e.die()
	Global.max_health = 100000.0
	Global.health = 100000.0
	_player.global_position = Vector2(40, 40)
	_boss = BossScene.instantiate()
	_boss.position = Vector2(150, 40)
	_level.get_node("Enemies").add_child(_boss)


func _spawn_variants() -> void:
	var i := 0
	for v in [0, 1, 2, 3]:
		var e := EnemyScene.instantiate()
		e.set("behavior", 0)
		e.rotation = PI * 0.5
		_level.get_node("Enemies").add_child(e)
		e.global_position = Vector2(-20 + 40 * i, -10)
		e.apply_variant(v)
		i += 1
