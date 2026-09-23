extends Control

const UIStyle := preload("res://Scripts/UI/ui_style.gd")
const Story := preload("res://Scripts/story.gd")
const StoryScreen := preload("res://Scripts/UI/story_screen.gd")
const VictoryScreen := preload("res://Scripts/UI/victory_screen.gd")

var _buttons: Array[Button] = []
var _preview: TextureRect
var _preview_fallback: Label
var _name_label: Label
var _chapter_label: Label
var _desc_label: Label
var _story_panel: PanelContainer
var _story_label: Label
var _twist_row: HBoxContainer
var _twist_name: Label
var _twist_desc: Label
var _info_label: Label
var _status_label: Label
var _boss_badge: PanelContainer
var _rank_badge: PanelContainer
var _rank_badge_label: Label
var _selected: int = 0
var _diff_buttons: Array[Button] = []
var _diff_desc: Label
var _story: CanvasLayer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build()
	var start := 0
	for i in range(GameManager.level_count()):
		if GameManager.is_unlocked(i):
			start = i
	_select(start)
	_refresh_difficulty()
	_buttons[_selected].grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UIStyle.BG
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var title_panel := PanelContainer.new()
	root.add_child(title_panel)
	var title := UIStyle.label("SECCIÓN DE NIVELES", 32, UIStyle.OBJECTIVE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_panel.add_child(title)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)

	for i in range(GameManager.level_count()):
		var b := UIStyle.button("", Vector2(300, 48))
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_level_pressed.bind(i))
		b.mouse_entered.connect(_select.bind(i))
		b.focus_entered.connect(_select.bind(i))
		left.add_child(b)
		_buttons.append(b)
	_refresh_button_texts()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	var diff_title := UIStyle.label("DIFICULTAD", 15, UIStyle.TEXT_DIM, true)
	left.add_child(diff_title)
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	left.add_child(diff_row)
	for i in range(Settings.DIFFICULTIES.size()):
		var db := UIStyle.button(Settings.DIFFICULTIES[i], Vector2(96, 40))
		db.add_theme_font_size_override("font_size", 15)
		db.pressed.connect(_on_difficulty_pressed.bind(i))
		diff_row.add_child(db)
		_diff_buttons.append(db)
	_diff_desc = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc.custom_minimum_size = Vector2(300, 56)
	left.add_child(_diff_desc)

	var back := UIStyle.button("REGRESAR", Vector2(300, 52))
	back.pressed.connect(GameManager.go_to_menu)
	left.add_child(back)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right.add_child(right_box)

	var preview_holder := PanelContainer.new()
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BAR_EMPTY, 2, 4, 6, 6))
	right_box.add_child(preview_holder)

	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(300, 140)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_holder.add_child(_preview)

	_preview_fallback = UIStyle.label("SIN VISTA PREVIA", 22, UIStyle.BAR_EMPTY, true)
	_preview_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_fallback.visible = false
	preview_holder.add_child(_preview_fallback)

	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(overlay)

	_boss_badge = _badge("JEFE FINAL", UIStyle.LIFE, Color(0.12, 0.02, 0.04, 0.9))
	_boss_badge.position = Vector2(10, 10)
	overlay.add_child(_boss_badge)

	_rank_badge = _badge("RANGO S", UIStyle.OBJECTIVE, Color(UIStyle.BG, 0.9))
	_rank_badge_label = _rank_badge.get_child(0) as Label
	_rank_badge.anchor_left = 1.0
	_rank_badge.anchor_right = 1.0
	_rank_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_rank_badge.offset_left = -10.0
	_rank_badge.offset_right = -10.0
	_rank_badge.offset_top = 10.0
	overlay.add_child(_rank_badge)

	_name_label = UIStyle.label("", 28, UIStyle.TEXT, true)
	right_box.add_child(_name_label)

	_chapter_label = StoryScreen.spaced_label("", 16, UIStyle.OBJECTIVE, 4, true)
	right_box.add_child(_chapter_label)

	_desc_label = UIStyle.label("", 17, UIStyle.TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_box.add_child(_desc_label)

	_story_panel = PanelContainer.new()
	var quote := UIStyle.box(Color(UIStyle.BG, 0.55), Color(UIStyle.OBJECTIVE, 0.7), 0, 2, 14, 6)
	quote.border_width_left = 3
	_story_panel.add_theme_stylebox_override("panel", quote)
	right_box.add_child(_story_panel)
	_story_label = UIStyle.label("", 16, UIStyle.TEXT)
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_panel.add_child(_story_label)

	_twist_row = HBoxContainer.new()
	_twist_row.add_theme_constant_override("separation", 12)
	right_box.add_child(_twist_row)
	var twist_badge := PanelContainer.new()
	twist_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	twist_badge.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.AMMO, 0.12), UIStyle.AMMO, 1, 3, 8, 2))
	_twist_row.add_child(twist_badge)
	_twist_name = StoryScreen.spaced_label("", 14, UIStyle.AMMO, 2, true)
	twist_badge.add_child(_twist_name)
	_twist_desc = UIStyle.label("", 15, UIStyle.TEXT_DIM)
	_twist_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_twist_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_twist_row.add_child(_twist_desc)

	_info_label = UIStyle.label("", 17, UIStyle.AMMO)
	right_box.add_child(_info_label)

	_status_label = UIStyle.label("", 18, UIStyle.BAR_FILL, true)
	right_box.add_child(_status_label)


func _badge(text: String, color: Color, bg: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UIStyle.box(bg, color, 2, 3, 10, 4))
	var l := StoryScreen.spaced_label(text, 15, color, 3, true)
	badge.add_child(l)
	return badge


func _refresh_button_texts() -> void:
	for i in range(_buttons.size()):
		var text := "LEVEL %d" % (i + 1)
		if not GameManager.is_playable(i):
			text += "  ···"
		elif not GameManager.is_unlocked(i):
			text += "  [BLOQUEADO]"
		elif GameManager.best_rank(i) != "":
			text += "   [%s]" % GameManager.best_rank(i)
		_buttons[i].text = text
		var dim := not GameManager.is_unlocked(i)
		_buttons[i].modulate = Color(1, 1, 1, 0.55) if dim else Color.WHITE


func _select(index: int) -> void:
	_selected = index
	var data := GameManager.level_data(index)
	if data.is_empty():
		return
	var unlocked := GameManager.is_unlocked(index)
	var playable := GameManager.is_playable(index)
	var chapter := Story.chapter(index)

	_name_label.text = "LEVEL %d · %s" % [index + 1, String(data["name"])]
	_chapter_label.text = String(chapter.get("title", ""))
	_chapter_label.visible = _chapter_label.text != ""
	_desc_label.text = String(data["desc"])

	var story_text := String(chapter.get("briefing", "")).replace("\n\n", " ").replace("\n", " ")
	_story_label.text = story_text
	_story_panel.visible = playable and unlocked and story_text != ""

	var twist := GameManager.twist_info(index)
	_twist_name.text = String(twist.get("name", ""))
	_twist_desc.text = String(twist.get("desc", ""))
	_twist_row.visible = playable

	var path := String(data["preview"])
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_preview.texture = tex
	_preview.modulate = Color.WHITE if unlocked else Color(0.35, 0.35, 0.4, 1.0)
	_preview_fallback.visible = tex == null
	_preview_fallback.text = "PRÓXIMAMENTE" if not playable else "SIN VISTA PREVIA"

	_boss_badge.visible = GameManager.is_boss_level(index)
	var rank := GameManager.best_rank(index)
	_rank_badge.visible = playable and rank != ""
	if rank != "":
		var rank_color := VictoryScreen.rank_color(rank)
		_rank_badge_label.text = "RANGO %s" % rank
		_rank_badge_label.add_theme_color_override("font_color", rank_color)
		_rank_badge.add_theme_stylebox_override("panel", UIStyle.box(Color(UIStyle.BG, 0.9), rank_color, 2, 3, 10, 4))

	if playable:
		var enemies: Array = data.get("enemies", [0])
		var count := int(enemies[clampi(Settings.difficulty, 0, enemies.size() - 1)]) if not enemies.is_empty() else 0
		_info_label.text = "ENEMIGOS: %d    MEJOR PUNTAJE: %d    MEJOR RANGO: %s" % [count, GameManager.best_score(index), rank if rank != "" else "-"]
	else:
		_info_label.text = ""
	_info_label.visible = playable

	if not playable:
		_status_label.text = "PRÓXIMAMENTE"
		_status_label.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	elif not unlocked:
		_status_label.text = "BLOQUEADO · COMPLETA EL NIVEL %d PARA ENTRAR" % index
		_status_label.add_theme_color_override("font_color", UIStyle.LIFE)
	elif index == 0 and not GameManager.prologue_seen:
		_status_label.text = "PRESIONA PARA JUGAR · EMPIEZA CON EL PRÓLOGO"
		_status_label.add_theme_color_override("font_color", UIStyle.BAR_FILL)
	else:
		_status_label.text = "PRESIONA PARA JUGAR"
		_status_label.add_theme_color_override("font_color", UIStyle.BAR_FILL)


func _on_difficulty_pressed(index: int) -> void:
	Settings.set_difficulty(index)
	_refresh_difficulty()
	_select(_selected)


func _refresh_difficulty() -> void:
	for i in range(_diff_buttons.size()):
		if i == Settings.difficulty:
			_diff_buttons[i].add_theme_stylebox_override("normal", UIStyle.box(UIStyle.BAR_EMPTY, UIStyle.OBJECTIVE, 2))
			_diff_buttons[i].add_theme_color_override("font_color", UIStyle.OBJECTIVE)
		else:
			_diff_buttons[i].remove_theme_stylebox_override("normal")
			_diff_buttons[i].remove_theme_color_override("font_color")
	_diff_desc.text = Settings.DIFFICULTY_DESCRIPTIONS[Settings.difficulty]


func _on_level_pressed(index: int) -> void:
	if _story != null and is_instance_valid(_story):
		return
	if not GameManager.is_unlocked(index):
		_select(index)
		return
	if index == 0 and not GameManager.prologue_seen:
		_play_prologue()
	else:
		GameManager.start_level(index)


func _play_prologue() -> void:
	var s := StoryScreen.new()
	s.pages = Story.PROLOGUE
	s.heading = "PRÓLOGO"
	s.finished.connect(_on_prologue_finished)
	_story = s
	add_child(s)


func _on_prologue_finished() -> void:
	GameManager.mark_prologue_seen()
	GameManager.start_level(0)


func _unhandled_input(event: InputEvent) -> void:
	if _story != null and is_instance_valid(_story):
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_menu()
