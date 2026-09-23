extends RefCounted

## Texto flotante en el mundo ("+300" sobre un enemigo caído).
## FloatingText.spawn(escena, posición, "+300", color, tamaño)

const UIStyle := preload("res://Scripts/UI/ui_style.gd")


static func spawn(parent: Node, world_pos: Vector2, text: String, color: Color, font_size: int = 12) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 200
	label.light_mask = 0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", UIStyle.bold_font())
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)

	label.reset_size()
	label.pivot_offset = label.size * 0.5
	var start := world_pos - label.size * 0.5 + Vector2(randf_range(-6.0, 6.0), -16.0)
	label.global_position = start
	label.scale = Vector2(0.3, 0.3)

	# rebota al aparecer, sube y se desvanece
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "global_position:y", start.y - 30.0, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.7)
	tween.chain().tween_callback(label.queue_free)
