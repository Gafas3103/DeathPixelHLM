extends Node

const Briefing := preload("res://Scripts/UI/briefing.gd")
const StoryScreen := preload("res://Scripts/UI/story_screen.gd")
const VictoryScreen := preload("res://Scripts/UI/victory_screen.gd")
const Story := preload("res://Scripts/story.gd")

var _shots := false
var _closed := 0
var _finished := 0
var _fails := 0
var _saved := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shots = "--shots" in OS.get_cmdline_user_args()
	_saved = {
		"prologue_seen": GameManager.prologue_seen,
		"game_completed": GameManager.game_completed,
		"current_index": GameManager.current_index,
		"best_ranks": GameManager.best_ranks.duplicate(),
		"best_scores": GameManager.best_scores.duplicate(),
	}
	call_deferred("_run")


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


func _click() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = Vector2(640, 360)
	e.global_position = Vector2(640, 360)
	e.pressed = true
	get_viewport().push_input(e)
	await _wait(0.05)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.position = Vector2(640, 360)
	r.global_position = Vector2(640, 360)
	r.pressed = false
	get_viewport().push_input(r)
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
	print("SHOT ", path, " ", img.get_size())


func _backdrop() -> Control:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tex := TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://Assest/UI/preview_nivel3.png"):
		tex.texture = load("res://Assest/UI/preview_nivel3.png")
	holder.add_child(tex)
	add_child(holder)
	return holder


func _run() -> void:
	await _wait(0.2)
	await _test_briefings()
	await _test_story()
	await _test_story_skip_end_card()
	await _test_level_select()
	await _test_main_menu()
	await _test_victory()
	await _test_notes()
	GameManager.prologue_seen = _saved["prologue_seen"]
	GameManager.game_completed = _saved["game_completed"]
	GameManager.current_index = _saved["current_index"]
	GameManager.best_ranks = _saved["best_ranks"]
	GameManager.best_scores = _saved["best_scores"]
	get_tree().paused = false
	print("STORY_TEST_DONE fails=", _fails)
	get_tree().quit()


func _test_briefings() -> void:
	var backdrop := _backdrop()
	for i in [0, 1, 2]:
		Global.objective = ""
		var before := _closed
		var b := Briefing.new()
		b.level_index = i
		b.closed.connect(func() -> void: _closed += 1)
		add_child(b)
		await _wait(0.1)
		_check(get_tree().paused, "briefing %d pauses the tree" % i)
		if i == 0:
			var waited := 0.0
			while not bool(b.get("_revealed")) and waited < 12.0:
				await _wait(0.2)
				waited += 0.2
			_check(bool(b.get("_revealed")), "briefing 0 reveals by itself (%.1fs)" % waited)
			Global.set_objective("RECOGE LA LLAVE")
			await _wait(0.05)
			var obj_label := b.get("_objective_label") as Label
			_check(obj_label != null and obj_label.text == "RECOGE LA LLAVE", "briefing follows objective_changed")
		else:
			await _wait(0.4)
			await _tap(KEY_ESCAPE)
			_check(bool(b.get("_revealed")), "briefing %d first key completes reveal" % i)
			_check(_closed == before, "briefing %d not closed by the first key" % i)
		await _wait(0.8)
		if i == 2:
			await _shot("final_briefing.png")
		if i == 1:
			await _click()
		else:
			await _tap()
		await _wait(0.1)
		_check(_closed == before + 1, "briefing %d emits closed" % i)
		_check(not get_tree().paused, "briefing %d unpauses" % i)
		await _wait(0.7)
		_check(not is_instance_valid(b), "briefing %d frees itself" % i)
	backdrop.queue_free()
	Global.objective = ""


func _test_story() -> void:
	var s := StoryScreen.new()
	s.pages = Story.PROLOGUE
	s.heading = "PRÓLOGO"
	var before := _finished
	s.finished.connect(func() -> void: _finished += 1)
	add_child(s)
	await _wait(1.0)
	await _tap()
	await _wait(0.2)
	await _shot("final_story.png")
	var taps := 0
	while _finished == before and taps < 60:
		await _tap()
		await _wait(0.4)
		taps += 1
	_check(_finished == before + 1, "story prologue finishes after %d taps" % taps)
	await _wait(0.5)
	_check(not is_instance_valid(s), "story frees itself")


func _test_story_skip_end_card() -> void:
	var s := StoryScreen.new()
	s.pages = Story.EPILOGUE
	s.heading = "EPÍLOGO"
	s.end_title = "FIN"
	s.end_subtitle = "GRACIAS POR JUGAR"
	var before := _finished
	s.finished.connect(func() -> void: _finished += 1)
	add_child(s)
	await _wait(1.0)
	await _tap(KEY_ESCAPE)
	await _wait(2.2)
	_check(bool(s.get("_on_end_card")), "esc jumps to end card")
	await _shot("final_story_end.png")
	await _click()
	await _wait(0.2)
	_check(_finished == before + 1, "end card finishes on click")
	await _wait(0.6)
	_check(not is_instance_valid(s), "end card story frees itself")


func _test_level_select() -> void:
	GameManager.best_ranks = {"0": "S", "1": "B"}
	GameManager.best_scores = {"0": 5400, "1": 3100}
	var ls: Node = load("res://Scenes/UI/LevelSelect.tscn").instantiate()
	add_child(ls)
	await _wait(0.2)
	for i in range(GameManager.level_count()):
		ls.call("_select", i)
		await _wait(0.05)
	ls.call("_select", 2)
	await _wait(0.2)
	await _shot("final_level_select.png")
	ls.call("_select", 0)
	await _wait(0.2)
	await _shot("final_level_select_l1.png")
	ls.call("_select", 3)
	await _wait(0.2)
	await _shot("final_level_select_l4.png")
	GameManager.prologue_seen = false
	ls.call("_on_level_pressed", 0)
	await _wait(0.3)
	var st: Node = ls.get("_story")
	_check(st != null and is_instance_valid(st), "level select shows prologue before level 1")
	if st != null and is_instance_valid(st):
		st.disconnect("finished", Callable(ls, "_on_prologue_finished"))
		var before := _finished
		st.connect("finished", func() -> void: _finished += 1)
		await _wait(0.4)
		await _tap(KEY_ESCAPE)
		await _wait(0.8)
		_check(_finished == before + 1, "prologue skip with esc emits finished")
		_check(is_instance_valid(ls) and ls.is_inside_tree(), "level select ignored esc while prologue open")
	GameManager.prologue_seen = _saved["prologue_seen"]
	ls.queue_free()
	await _wait(0.1)


func _test_main_menu() -> void:
	var mm: Node = load("res://Scenes/UI/MainMenu.tscn").instantiate()
	add_child(mm)
	await _wait(0.3)
	await _shot("final_main_menu.png")
	var box := mm.get("_menu_box") as VBoxContainer
	_check(box != null and (box.get_child(2) as Button).text == "HISTORIA", "HISTORIA button before AJUSTES")
	_check(box != null and (box.get_child(3) as Button).text == "AJUSTES", "AJUSTES after HISTORIA")
	mm.call("_on_credits")
	await _wait(0.1)
	mm.call("_close_credits")
	await _wait(0.1)
	var credits_btn := mm.get("_credits_btn") as Button
	_check(credits_btn != null and credits_btn.has_focus(), "credits close restores focus to CRÉDITOS")
	GameManager.prologue_seen = true
	GameManager.game_completed = true
	mm.call("_on_history")
	await _wait(0.8)
	var first: Node = mm.get("_story")
	_check(first != null, "HISTORIA opens the prologue")
	await _tap(KEY_ESCAPE)
	await _wait(1.2)
	var second: Node = mm.get("_story")
	_check(second != null and second != first, "HISTORIA chains the epilogue when the game is completed")
	await _tap(KEY_ESCAPE)
	await _wait(2.2)
	await _tap()
	await _wait(0.8)
	_check(mm.get("_story") == null, "HISTORIA returns to the menu")
	var hist := mm.get("_history_btn") as Button
	_check(hist != null and hist.has_focus(), "HISTORIA button regains focus")
	GameManager.game_completed = _saved["game_completed"]
	GameManager.prologue_seen = _saved["prologue_seen"]
	mm.queue_free()
	await _wait(0.1)


func _test_victory() -> void:
	var backdrop := _backdrop()
	Global.score = 4280
	Global.kills = 9
	Global.level_time = 134.4
	Global.times_detected = 1
	Global.deaths_this_level = 0
	Global.stealth_kills = 3
	GameManager.current_index = 0
	GameManager.last_rank = "A"
	GameManager.last_rank_new_best = true
	var v := VictoryScreen.new()
	add_child(v)
	await _wait(2.2)
	_check(get_tree().paused, "victory pauses the tree")
	await _shot("final_victory.png")
	v.queue_free()
	get_tree().paused = false
	await _wait(0.1)

	GameManager.current_index = 2
	GameManager.last_rank = "S"
	GameManager.last_rank_new_best = false
	Global.level_time = 402.0
	Global.deaths_this_level = 2
	var v2 := VictoryScreen.new()
	add_child(v2)
	await _wait(2.2)
	await _shot("final_victory_final.png")
	var buttons_ok := false
	for n in v2.find_children("*", "Button", true, false):
		if (n as Button).text == "VER EL FINAL":
			buttons_ok = true
	_check(buttons_ok, "final level shows VER EL FINAL")
	var titles_ok := false
	for n in v2.find_children("*", "Label", true, false):
		if (n as Label).text == "EL CONTRATISTA HA CAÍDO":
			titles_ok = true
	_check(titles_ok, "final level title")
	v2.call("_on_show_ending")
	await _wait(0.3)
	var st: Node = v2.get("_story")
	_check(st != null and is_instance_valid(st), "VER EL FINAL opens the epilogue")
	if st != null and is_instance_valid(st):
		st.disconnect("finished", Callable(v2, "_on_ending_finished"))
		var before := _finished
		st.connect("finished", func() -> void: _finished += 1)
		await _wait(0.8)
		var taps := 0
		while _finished == before and taps < 60:
			await _tap()
			await _wait(0.4)
			taps += 1
		_check(_finished == before + 1, "epilogue + FIN card finish after %d taps" % taps)
	v2.queue_free()
	get_tree().paused = false
	backdrop.queue_free()
	await _wait(0.2)


func _test_notes() -> void:
	var backdrop := _backdrop()
	var scene: PackedScene = load("res://Scenes/NoteUI.tscn")
	for i in range(Story.CHAPTERS.size()):
		if not Story.has_note(i):
			continue
		var ch := Story.chapter(i)
		var ui := scene.instantiate()
		ui.set("title_text", ch["note_title"])
		ui.set("body_text", ch["note_text"])
		ui.set("signature_text", ch["note_signature"])
		add_child(ui)
		get_tree().paused = true
		await _wait(0.6)
		await _shot("final_note_%d.png" % (i + 1))
		_key(KEY_E, true)
		await _wait(0.05)
		var open_after_press := is_instance_valid(ui) and get_tree().paused
		_key(KEY_E, false)
		await _wait(0.4)
		_check(open_after_press, "note %d stays open until the key is released" % (i + 1))
		_check(not is_instance_valid(ui), "note %d closes on release" % (i + 1))
		_check(not get_tree().paused, "note %d unpauses" % (i + 1))
	backdrop.queue_free()
	get_tree().paused = false
