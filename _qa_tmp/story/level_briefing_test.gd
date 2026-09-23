extends Node

var _shots := false
var _fails := 0


func _ready() -> void:
	_shots = "--shots" in OS.get_cmdline_user_args()
	if get_parent() != get_tree().root or get_tree().current_scene == self:
		call_deferred("_detach")


func _detach() -> void:
	var r := get_tree().root
	get_parent().remove_child(self)
	r.add_child(self)
	get_tree().current_scene = null
	_run()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	get_viewport().push_input(e)


func _tap(code: Key = KEY_SPACE) -> void:
	_key(code, true)
	await _wait(0.05)
	_key(code, false)
	await _wait(0.05)


func _check(cond: bool, what: String) -> void:
	if cond:
		print("OK ", what)
	else:
		print("FAIL ", what)
		_fails += 1


func _shot(file_name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://_qa_tmp/story/" + file_name)
	img.save_png(path)
	print("SHOT ", path)


func _find_by_script(root: Node, path: String) -> Node:
	if root == null:
		return null
	var s: Script = root.get_script()
	if s != null and s.resource_path == path:
		return root
	for c in root.get_children():
		var found := _find_by_script(c, path)
		if found != null:
			return found
	return null


func _run() -> void:
	for idx in [0, 1, 2]:
		if not GameManager.is_playable(idx):
			continue
		GameManager.start_level(idx)
		await _wait(1.2)
		var scene := get_tree().current_scene
		_check(scene != null, "level %d loaded" % idx)
		var b := _find_by_script(scene, "res://Scripts/UI/briefing.gd")
		_check(b != null, "level %d shows the briefing" % idx)
		_check(get_tree().paused, "level %d paused during briefing" % idx)
		_check(not Global.level_active, "level %d not active during briefing" % idx)
		print("  briefing age at first key: ", b.get("_age") if b != null else -1.0)
		while b != null and is_instance_valid(b) and float(b.get("_age")) < 0.5:
			await _wait(0.1)
		await _tap(KEY_ESCAPE)
		await _wait(0.2)
		var pause := _find_by_script(scene, "res://Scripts/UI/pause_menu.gd")
		var pause_root = pause.get("_root") if pause != null else null
		_check(pause_root == null or not (pause_root as Control).visible, "level %d esc does not open the pause menu under the briefing" % idx)
		await _wait(0.8)
		if idx == 1:
			await _shot("final_briefing_level2.png")
		await _tap()
		await _wait(0.2)
		_check(Global.level_active, "level %d active after closing the briefing" % idx)
		_check(not get_tree().paused, "level %d unpaused after the briefing" % idx)
		await _wait(0.8)
		_check(not is_instance_valid(b), "level %d briefing freed" % idx)
		if idx == 1:
			await _wait(1.0)
			await _shot("final_level2_after_briefing.png")
		GameManager.restart_level()
		await _wait(1.0)
		var b2 := _find_by_script(get_tree().current_scene, "res://Scripts/UI/briefing.gd")
		_check(b2 == null and Global.level_active, "level %d retry skips the briefing" % idx)
	GameManager.go_to_menu()
	await _wait(0.5)
	print("LEVEL_BRIEFING_TEST_DONE fails=", _fails)
	get_tree().quit()
