extends Node
## Autoload "UIKit": tema, font pixel (Jersey 15, OFL — tebal & jelas), kotak/tombol bergaya piksel, tata letak aset UI.
## Semua gambar UI = pixel art asli (grid kecil) yang ditampilkan NEAREST -> tajam.

var font: FontFile
var layout: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cache: Dictionary = {}
var sfx_next: int = 0
var box_cache: Dictionary = {}
const PX: int = 3   # satu "piksel" kotak UI = 3 piksel layar
const BROWN: Color = Color("#43251D")
const CREAM: Color = Color("#F8F1EA")


func _ready() -> void:
	font = load("res://assets/font/Jersey15.ttf") as FontFile
	# font pixel: tanpa penghalusan -> tepi huruf tegas & mudah dibaca
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var j: JSON = load("res://assets/ui/tata_letak.json") as JSON
	if j != null:
		layout = j.data as Dictionary
	for i: int in range(6):
		var ap: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(ap)
		sfx_players.append(ap)


## Bunyi pendek: klik, ayun, tok, air, gali, tangkap (assets/suara/*.wav). Volume ikut pengaturan (bus Master).
func sfx(name: String, pitch: float = 1.0) -> void:
	if not sfx_cache.has(name):
		var path: String = "res://assets/suara/%s.wav" % name
		sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var st: AudioStream = sfx_cache[name] as AudioStream
	if st == null or sfx_players.is_empty():
		return
	var ap: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	ap.stream = st
	ap.pitch_scale = pitch * randf_range(0.95, 1.05)
	ap.play()


## Material tema untuk bingkai/panel: isi krem diganti warna tema pilihan.
func theme_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://scripts/tema.gdshader") as Shader
	m.set_shader_parameter("target_color", Game.theme_color())
	return m


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
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if h < 0.0:
		var ts: Vector2 = tr.texture.get_size()
		h = w * ts.y / ts.x
	tr.size = Vector2(w, h)
	tr.custom_minimum_size = Vector2(w, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Bingkai kosong (bingkai_15 = 1.5:1, bingkai_11 = 1:1, bingkai_21 = 2:1) setinggi h (dibatasi lebar w_max).
## Hasil: [panel TextureRect, area isi Control]. Isi = bagian krem di dalam garis bingkai.
func frame(name: String, h: float, w_max: float = 99999.0) -> Array:
	var tex: Texture2D = load("res://assets/ui/%s.png" % name) as Texture2D
	var ratio: float = tex.get_size().x / tex.get_size().y
	if h * ratio > w_max:
		h = w_max / ratio
	var p: TextureRect = image("res://assets/ui/%s.png" % name, h * ratio, h)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.material = theme_material()
	var inner: Control = Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(inner, p.size, (layout["bingkai"] as Dictionary)[name] as Array)
	p.add_child(inner)
	return [p, inner]


## Judul bingkai, rata tengah di atas area isi.
func frame_title(inner: Control, text: String, fs: int = 32) -> Label:
	var t: Label = pixel_label(text, fs, BROWN)
	t.position = Vector2(0, 6)
	t.size = Vector2(inner.size.x, fs + 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t)
	return t


## Tombol tutup (X) pixel art di pojok kanan atas area isi bingkai (agak ke dalam, tidak menutupi hiasan bingkai).
func close_button(panel: Control, inner: Control, d: float = 46.0) -> TextureButton:
	var b: TextureButton = round_button("tombol_x", d)
	b.position = Vector2(inner.position.x + inner.size.x - d - corner_inset(panel), inner.position.y + 10.0)
	panel.add_child(b)
	return b


## Jarak tombol pojok dari tepi area isi, agar tidak menutupi hiasan bunga/daun di pojok bingkai.
func corner_inset(panel: Control) -> float:
	return maxf(14.0, panel.size.x * 0.075)


## Tombol bulat pixel art (gambar <nama>.png & <nama>_tekan.png).
func round_button(name: String, d: float) -> TextureButton:
	var b: TextureButton = TextureButton.new()
	b.texture_normal = load("res://assets/ui/%s.png" % name) as Texture2D
	b.texture_pressed = load("res://assets/ui/%s_tekan.png" % name) as Texture2D
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.size = Vector2(d, d)
	b.custom_minimum_size = b.size
	b.button_down.connect(func() -> void: sfx("klik"))
	return b


## Tombol bergambar yang membal sedikit saat ditekan.
func icon_button(path: String, w: float) -> TextureButton:
	var b: TextureButton = TextureButton.new()
	b.texture_normal = load(path) as Texture2D
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ts: Vector2 = b.texture_normal.get_size()
	b.size = Vector2(w, w * ts.y / ts.x)
	b.custom_minimum_size = b.size
	b.pivot_offset = b.size / 2.0
	b.button_down.connect(func() -> void:
		b.scale = Vector2(0.92, 0.92)
		sfx("klik"))
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


## Kotak/tombol bergaya piksel: garis tepi 1 piksel, sudut terpotong, sorot atas-kiri & bayang bawah-kanan.
## (r diabaikan; tetap ada agar pemanggil lama cocok). Dibuat sekali per warna lalu disimpan.
func box(bg: Color, border: Color, bw: int = 2, r: int = 8) -> StyleBox:
	var key: String = "%s|%s" % [bg.to_html(), border.to_html()]
	if box_cache.has(key):
		return box_cache[key] as StyleBox
	var n: int = 8
	var img: Image = Image.create(n * PX, n * PX, false, Image.FORMAT_RGBA8)
	for y: int in range(n):
		for x: int in range(n):
			var c: Color = bg
			var edge: bool = x == 0 or y == 0 or x == n - 1 or y == n - 1
			if (x == 0 or x == n - 1) and (y == 0 or y == n - 1):
				c = Color(0, 0, 0, 0)
			elif edge:
				c = border
			elif x == 1 and y == 1 or x == n - 2 and y == n - 2 or x == 1 and y == n - 2 or x == n - 2 and y == 1:
				c = border if bw > 2 else bg
			elif y == 1 or x == 1:
				c = Color(bg.lightened(0.22), bg.a)
			elif y == n - 2 or x == n - 2:
				c = Color(bg.darkened(0.14), bg.a)
			img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), c)
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.set_texture_margin_all(3 * PX)
	sb.set_content_margin_all(10)
	box_cache[key] = sb
	return sb


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
