extends Node

const EnemyScene := preload("res://Scenes/Enemy.tscn")
const BossScene := preload("res://Scenes/Boss.tscn")

var _step: int = 0
var _frames: int = 0
var _out: String = ""
var _level: Node = null
var _player: Node2D = null
var _holder: Node2D = null
var _lineup: Array = []
var _tir: Node = null
var _boss: Node = null
var _flags: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	Settings.difficulty = 1
	_out = ProjectSettings.globalize_path("res://_qa_tmp/enemies/")
	GameManager.start_level(2, Global.START_RETRY)
	_step = 1


func _shot(name: String, center: Vector2 = Vector2.INF, half: Vector2 = Vector2(110, 60), zoom: int = 3) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if center.is_finite():
		var ct := get_viewport().get_canvas_transform()
		var vs := get_viewport().get_visible_rect().size
		var k := Vector2(img.get_width(), img.get_height()) / vs
		var a := (ct * (center - half)) * k
		var b := (ct * (center + half)) * k
		var rect := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		if rect.size.x > 4 and rect.size.y > 4:
			img = img.get_region(rect)
			var f := float(zoom) * vs.x / float(get_viewport().get_texture().get_width())
			img.resize(int(img.get_width() * f), int(img.get_height() * f), Image.INTERPOLATE_NEAREST)
	img.save_png(_out + name + ".png")
	print("SHOT ", name, " ", img.get_size())


func _physics_process(_d: float) -> void:
	_frames += 1
	Global.health = maxf(Global.health, 5000.0)
	Global.max_health = 5000.0
	match _step:
		1:
			var cs := get_tree().current_scene
			if _frames > 30 and cs != null and cs.name == "Level3":
				_level = cs
				_player = get_tree().get_first_node_in_group("player") as Node2D
				_holder = _level.get_node("Enemies") as Node2D
				for e in get_tree().get_nodes_in_group("Enemies"):
					e.remove_from_group("Enemies")
					e.queue_free()
				_player.global_position = Vector2(110, -24)
				_player.set("start_position", _player.global_position)
				Global.grace_time = 1000.0
				_step = 2
				_frames = 0
		2:
			if _frames == 5:
				_make_lineup()
			if _frames == 70:
				_shot("final_variants_calm", Vector2(215, -24), Vector2(80, 36), 4)
			if _frames == 80:
				_tir.set("_target", _player)
				_tir._enter_attack()
			if _frames > 80 and _frames < 400:
				_watch_tirador()
			if _frames == 400:
				for e in _lineup:
					e.queue_free()
				_boss = BossScene.instantiate()
				_holder.add_child(_boss)
				_boss.global_position = Vector2(250, -24)
				_step = 3
				_frames = 0
		3:
			_boss_sequence()


func _make_lineup() -> void:
	var xs := [170.0, 200.0, 230.0, 260.0]
	for i in range(4):
		var e := EnemyScene.instantiate()
		e.set("behavior", 0)
		e.set("turret_sweep_degrees", 0.0)
		_holder.add_child(e)
		e.global_position = Vector2(xs[i], -24.0)
		e.global_rotation = PI
		e.set("_base_rotation", PI)
		e.set("_home_position", e.global_position)
		e.apply_variant(i)
		_lineup.append(e)
	_tir = _lineup[2]


func _watch_tirador() -> void:
	if _tir == null or not is_instance_valid(_tir):
		return
	var t := float(_tir.get("_shoot_timer"))
	var center: Vector2 = (_tir.global_position + _player.global_position) * 0.5
	if t <= 0.45 and t > 0.3 and not _flags.has("charge"):
		_flags["charge"] = true
		_shot("final_tirador_charge", center, Vector2(95, 40), 4)
	if t <= 0.15 and t > 0.0 and not _flags.has("lock"):
		_flags["lock"] = true
		_shot("final_tirador_lock", center, Vector2(95, 40), 4)
	if float(_tir.get("_laser_flash")) > 0.09 and not _flags.has("fire"):
		_flags["fire"] = true
		_shot("final_tirador_fire", center, Vector2(95, 40), 4)


func _force(action: int) -> void:
	_boss.set("_action", 0)
	_boss.call("_start_action", action, _player)


func _boss_sequence() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var at: Vector2 = (_boss.global_position + _player.global_position) * 0.5
	if int(_boss.get("_mode")) == 1 and int(_boss.get("_action")) == 0:
		_boss.set("_action_cd", 99.0)
	if _frames == 30:
		_shot("final_boss_intro", at, Vector2(120, 60), 3)
	if _frames == 200:
		_force(1)
	if _frames == 200 + 17:
		_shot("final_boss_burst_lock", at, Vector2(120, 60), 3)
	if _frames == 260:
		_boss.set("phase", 1)
		_force(2)
	if _frames == 260 + 24:
		_shot("final_boss_fan", at, Vector2(120, 60), 3)
	if _frames == 330:
		_force(4)
	if _frames == 330 + 25:
		_shot("final_boss_dash_aim", at, Vector2(120, 60), 3)
	if _frames == 420:
		_boss.set("phase", 2)
		_force(3)
	if _frames == 420 + 28:
		_shot("final_boss_ring_charge", at, Vector2(120, 60), 3)
	if _frames == 420 + 50:
		_shot("final_boss_ring_fire", at, Vector2(120, 60), 3)
	if _frames == 540:
		_player.global_position = _boss.global_position + Vector2(-50, 0)
	if _frames == 600:
		_force(7)
	if _frames == 600 + 22:
		_shot("final_boss_stomp", _boss.global_position, Vector2(110, 60), 3)
	if _frames == 700:
		_boss.set("_mode", 1)
		_boss.set("health", 3.0)
		_boss.set("phase", 2)
		_boss.take_damage(30.0)
	if _frames == 706:
		_shot("final_boss_death", at, Vector2(150, 80), 2)
	if _frames == 900:
		_shot("final_boss_after")
		print("VISUAL_DONE time_scale=", Engine.time_scale)
		get_tree().quit()
