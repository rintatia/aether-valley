extends RefCounted
## Helper tampilan: tema, tombol, panel. Semua dibuat lewat kode.


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, r: int = 10) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(r)
	b.set_content_margin_all(12)
	return b


static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 24
	t.set_stylebox("normal", "Button", box(Color("#7F442C"), Color("#E0B83C"), 2))
	t.set_stylebox("hover", "Button", box(Color("#A55E36"), Color("#FFD65A"), 2))
	t.set_stylebox("pressed", "Button", box(Color("#43251D"), Color("#FFD65A"), 2))
	t.set_stylebox("disabled", "Button", box(Color("#4A4650"), Color("#6B6670"), 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color("#F8F1EA"))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.17, 0.15, 0.19, 0.94), Color("#FFD65A"), 3, 14))
	t.set_color("font_color", "Label", Color("#F8F1EA"))
	t.set_stylebox("normal", "LineEdit", box(Color("#F8F1EA"), Color("#B58A2A"), 2))
	t.set_stylebox("focus", "LineEdit", box(Color("#FFFFFF"), Color("#FFD65A"), 3))
	t.set_color("font_color", "LineEdit", Color("#241912"))
	t.set_color("font_placeholder_color", "LineEdit", Color("#6B6670"))
	t.set_color("caret_color", "LineEdit", Color("#241912"))
	t.set_stylebox("background", "ProgressBar", box(Color("#2B2730"), Color("#6B6670"), 2, 8))
	t.set_stylebox("fill", "ProgressBar", box(Color("#94BD1B"), Color(0, 0, 0, 0), 0, 8))
	return t


static func label(text: String, size: int = 24, color: Color = Color("#F8F1EA")) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, w: float = 0.0, h: float = 56.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	return b


static func center(c: Control, w: float, h: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = -w / 2.0
	c.offset_right = w / 2.0
	c.offset_top = -h / 2.0
	c.offset_bottom = h / 2.0
