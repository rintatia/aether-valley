extends Node
## Autoload "UIKit": tema, font pixel (Pixelify Sans, OFL), tombol bergambar, tata letak aset UI.

var font: FontFile
var layout: Dictionary = {}
const BROWN: Color = Color("#43251D")
const CREAM: Color = Color("#F8F1EA")


func _ready() -> void:
	font = load("res://assets/font/PixelifySans.ttf") as FontFile
	var j: JSON = load("res://assets/ui/tata_letak.json") as JSON
	if j != null:
		layout = j.data as Dictionary


## Jarak aman dari tepi layar (poni/kamera & lengkung bingkai HP), dalam koordinat viewport.
func safe_margin(root: Control) -> Vector4:
	var vs: Vector2 = root.get_viewport_rect().size
	var ss: Vector2 = Vector2(DisplayServer.screen_get_size())
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var l: float = 44.0
	var r: float = 44.0
	var t: float = 14.0
	var b: float = 12.0
	if ss.x > 0 and sa.size.x > 0:
		var k: float = vs.x / ss.x
		l = maxf(l, sa.position.x * k + 18.0)
		r = maxf(r, (ss.x - sa.end.x) * k + 18.0)
		t = maxf(t, sa.position.y * k + 8.0)
		b = maxf(b, (ss.y - sa.end.y) * k + 8.0)
	return Vector4(l, t, r, b)


## TextureRect gambar UI (halus saat diperkecil)
func image(path: String, w: float, h: float = -1.0) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.texture = load(path) as Texture2D
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if h < 0.0:
		var ts: Vector2 = tr.texture.get_size()
		h = w * ts.y / ts.x
	tr.size = Vector2(w, h)
	tr.custom_minimum_size = Vector2(w, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Tombol bergambar yang membal sedikit saat ditekan.
func icon_button(path: String, w: float) -> TextureButton:
	var b: TextureButton = TextureButton.new()
	b.texture_normal = load(path) as Texture2D
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ts: Vector2 = b.texture_normal.get_size()
	b.size = Vector2(w, w * ts.y / ts.x)
	b.custom_minimum_size = b.size
	b.pivot_offset = b.size / 2.0
	b.button_down.connect(func() -> void: b.scale = Vector2(0.92, 0.92))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	return b


## Tombol pil oranye dengan teks pixel.
func pill_button(text: String, w: float = 240.0) -> TextureButton:
	var b: TextureButton = icon_button("res://assets/ui/tombol_kosong.png", w)
	var l: Label = pixel_label(text, int(b.size.y * 0.42), BROWN)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.offset_top = -3
	b.add_child(l)
	return b


func pixel_label(text: String, size: int, color: Color = BROWN, outline: int = 0, outline_color: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", outline_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Kotak relatif (pecahan 0..1 dari ukuran induk) -> posisi & ukuran
func place(c: Control, parent_size: Vector2, r: Array) -> void:
	c.position = Vector2(float(r[0]) * parent_size.x, float(r[1]) * parent_size.y)
	c.size = Vector2((float(r[2]) - float(r[0])) * parent_size.x, (float(r[3]) - float(r[1])) * parent_size.y)


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
	t.default_font = font
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
