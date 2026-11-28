extends Node
## Autoload "UIKit": tema tombol & teks sementara (polos, akan diganti aset HUD).


func box(bg: Color, border: Color, bw: int = 2, r: int = 8) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(r)
	b.set_content_margin_all(10)
	return b


func theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 26
	t.set_stylebox("normal", "Button", box(Color("#4A4650"), Color("#B5B0A6")))
	t.set_stylebox("hover", "Button", box(Color("#6B6670"), Color("#D8D3C4")))
	t.set_stylebox("pressed", "Button", box(Color("#2B2730"), Color("#D8D3C4")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color("#F8F1EA"))
	t.set_color("font_color", "Label", Color("#F8F1EA"))
	t.set_color("font_outline_color", "Label", Color("#2B2730"))
	t.set_constant("outline_size", "Label", 6)
	return t


func label(text: String, size: int = 24) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func button(text: String, w: float = 0.0, h: float = 60.0) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	return b


## Nama versi build, mis. "7.0.0.build.26" (diisi otomatis oleh GitHub Actions).
func version() -> String:
	var j: JSON = load("res://data/version.json") as JSON
	if j != null and j.data is Dictionary:
		return "Versi " + str((j.data as Dictionary).get("versi", "?"))
	return "Versi ?"


func version_label() -> Label:
	var l: Label = label(version(), 18)
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.offset_left = -360
	l.offset_right = -14
	l.offset_top = 10
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.8
	return l
