extends RefCounted

## Estilo compartido: paleta y helpers. Menús y HUD sacan los colores de aquí.
## Uso: const UIStyle = preload("res://Scripts/UI/ui_style.gd")

const BG := Color("#161923")          # panel lateral / fondo de menús
const PANEL := Color("#252833")       # contenedores, tarjetas, inventario
const TEXT := Color("#E9E5D8")        # texto principal
const TEXT_DIM := Color("#A5A3A0")    # texto secundario
const LIFE := Color("#EF3E4A")        # vidas / salud
const AMMO := Color("#22D3EE")        # munición
const OBJECTIVE := Color("#FFB000")   # objetivo de misión, acentos
const BAR_EMPTY := Color("#45404A")   # barra vacía
const BAR_FILL := Color("#39E58C")    # barra de progreso / éxito

static var _bold: FontVariation = null
static var _theme: Theme = null


## negrita derivada de la fuente por defecto
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.9
	return _bold


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 4, pad_x: int = 12, pad_y: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func label(text: String, size: int = 18, color: Color = TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	return l


static func button(text: String, min_size: Vector2 = Vector2(260, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	return b


## barra tipo ProgressBar con la paleta
static func bar(fill: Color, min_size: Vector2, empty: Color = BAR_EMPTY) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = min_size
	p.show_percentage = false
	p.min_value = 0.0
	p.max_value = 100.0
	p.value = 100.0
	p.add_theme_stylebox_override("background", box(empty, BG, 2, 2, 0, 0))
	p.add_theme_stylebox_override("fill", box(fill, Color.TRANSPARENT, 0, 2, 0, 0))
	return p


## theme global de menús: se asigna al Control raíz y los hijos lo heredan
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18

	for type_name in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type_name, box(PANEL, BAR_EMPTY, 2))
		t.set_stylebox("hover", type_name, box(PANEL.lightened(0.1), OBJECTIVE, 2))
		t.set_stylebox("pressed", type_name, box(OBJECTIVE, OBJECTIVE, 2))
		t.set_stylebox("focus", type_name, box(Color.TRANSPARENT, OBJECTIVE, 2))
		t.set_stylebox("disabled", type_name, box(PANEL.darkened(0.35), BAR_EMPTY.darkened(0.3), 2))
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, OBJECTIVE)
		t.set_color("font_focus_color", type_name, TEXT)
		t.set_color("font_pressed_color", type_name, BG)
		t.set_color("font_disabled_color", type_name, BAR_EMPTY)

	for type_name in ["CheckButton", "CheckBox"]:
		# sin esto heredan el estilo de Button
		var empty := StyleBoxEmpty.new()
		for style_name in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
			t.set_stylebox(style_name, type_name, empty)
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, OBJECTIVE)
		t.set_color("font_pressed_color", type_name, TEXT)
		t.set_color("font_hover_pressed_color", type_name, OBJECTIVE)
		t.set_color("font_focus_color", type_name, TEXT)
		t.set_stylebox("focus", type_name, box(Color.TRANSPARENT, OBJECTIVE, 1, 2, 4, 2))

	t.set_color("font_color", "Label", TEXT)

	# desplegable del OptionButton
	t.set_stylebox("panel", "PopupMenu", box(PANEL, OBJECTIVE, 2, 4, 6, 6))
	t.set_stylebox("hover", "PopupMenu", box(BAR_EMPTY, Color.TRANSPARENT, 0, 2, 6, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", OBJECTIVE)

	# el track necesita márgenes de contenido, sin ellos mide 0 px
	var track := box(BAR_EMPTY, Color.TRANSPARENT, 0, 3, 0, 3)
	var filled := box(OBJECTIVE, Color.TRANSPARENT, 0, 3, 0, 3)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grabber := _dot_icon(16, OBJECTIVE)
	t.set_icon("grabber", "HSlider", grabber)
	t.set_icon("grabber_highlight", "HSlider", _dot_icon(16, TEXT))
	t.set_icon("grabber_disabled", "HSlider", _dot_icon(16, BAR_EMPTY))

	t.set_stylebox("panel", "PanelContainer", box(PANEL, BAR_EMPTY, 2, 6, 14, 12))

	_theme = t
	return t


static func _dot_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5 - 0.5, size * 0.5 - 0.5)
	var radius := size * 0.5
	for y in range(size):
		for x in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
