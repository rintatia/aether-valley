extends Control
## Kustom karakter: pratinjau besar (bisa diputar kiri/kanan) + pilihan warna rambut, kulit, baju, celana, sepatu + nama.

signal done
signal back

const OPTIONS: Dictionary = {
	"hair": ["asli", "#43251D", "#241912", "#E0B83C", "#A43F46", "#F37CAB", "#6B5BA8", "#B5B0A6"],
	"skin": ["asli", "#F5D0B0", "#E8B28A", "#C68672", "#8A5A3C"],
	"shirt": ["asli", "#D8574F", "#2480BE", "#4E912F", "#E0B83C", "#9C8CF0", "#F8F1EA"],
	"pants": ["asli", "#43251D", "#1F4E8C", "#4A4650", "#2F6A32", "#B58A2A"],
	"boots": ["asli", "#241912", "#7F442C", "#4A4650", "#1F5F5A"],
}
const LABELS: Dictionary = {"hair": "Hair", "skin": "Skin", "shirt": "Shirt", "pants": "Pants", "boots": "Boots"}

var panel: TextureRect
var preview: TextureRect
var mat: ShaderMaterial
var swatches: Dictionary = {}
var name_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#1E3F2B")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vs: Vector2 = get_viewport_rect().size
	var h: float = minf(vs.y - 30.0, 660.0)
	panel = UIKit.image("res://assets/ui/panel_kosong.png", h * 1640.0 / 1269.0, h)
	panel.position = (vs - panel.size) / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var P: Dictionary = UIKit.layout["pilih"] as Dictionary
	var xb: Button = Button.new()
	xb.flat = true
	for st: String in ["normal", "hover", "pressed", "focus"]:
		xb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.place(xb, panel.size, P["x"] as Array)
	xb.pressed.connect(func() -> void: back.emit())
	panel.add_child(xb)
	var inner: Control = Control.new()
	UIKit.place(inner, panel.size, P["isi"] as Array)
	panel.add_child(inner)
	var t: Label = UIKit.pixel_label("—  Customize Your Character  —", 28, UIKit.BROWN)
	t.position = Vector2(0, 12)
	t.size = Vector2(inner.size.x, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t)
	# pratinjau
	var card: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#F9E2C8")
	sb.border_color = Color("#B58A2A")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(26, 62)
	card.size = Vector2(inner.size.x * 0.36, inner.size.y - 80)
	inner.add_child(card)
	preview = TextureRect.new()
	preview.texture = Game.char_texture("besar")
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mat = Game.char_material("besar")
	preview.material = mat
	preview.position = Vector2(16, 16)
	preview.size = card.size - Vector2(32, 72)
	preview.pivot_offset = preview.size / 2.0
	card.add_child(preview)
	var turn: HBoxContainer = HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	turn.add_theme_constant_override("separation", 16)
	turn.position = Vector2(0, card.size.y - 54)
	turn.size = Vector2(card.size.x, 44)
	card.add_child(turn)
	for d: int in [-1, 1]:
		var tb: Button = _small_button("<" if d < 0 else ">")
		tb.pressed.connect(func() -> void: preview.flip_h = d < 0)
		turn.add_child(tb)
	# pilihan warna
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.position = Vector2(card.position.x + card.size.x + 26, 64)
	col.size = Vector2(inner.size.x - col.position.x - 24, inner.size.y - 80)
	inner.add_child(col)
	var nrow: HBoxContainer = HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 12)
	var nl: Label = UIKit.pixel_label("Name", 22, UIKit.BROWN)
	nl.custom_minimum_size = Vector2(80, 40)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nrow.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.text = Game.player_name
	name_edit.max_length = 12
	name_edit.custom_minimum_size = Vector2(260, 40)
	name_edit.add_theme_font_override("font", UIKit.font)
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", UIKit.BROWN)
	var le: StyleBoxFlat = StyleBoxFlat.new()
	le.bg_color = Color("#FFF4E6")
	le.border_color = Color("#B58A2A")
	le.set_border_width_all(3)
	le.set_corner_radius_all(8)
	le.content_margin_left = 10
	name_edit.add_theme_stylebox_override("normal", le)
	name_edit.add_theme_stylebox_override("focus", le)
	nrow.add_child(name_edit)
	col.add_child(nrow)
	var meta: Dictionary = Game.char_meta()
	for part: String in ["hair", "skin", "shirt", "pants", "boots"]:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l: Label = UIKit.pixel_label(str(LABELS[part]), 22, UIKit.BROWN)
		l.custom_minimum_size = Vector2(80, 40)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		swatches[part] = []
		for opt: String in OPTIONS[part] as Array:
			var c: Color = Color(str((meta["warna_asli"] as Dictionary)[part])) if opt == "asli" else Color(opt)
			var sw: Button = _swatch(c)
			sw.pressed.connect(func() -> void: _pick(part, c, sw))
			row.add_child(sw)
			(swatches[part] as Array).append(sw)
		col.add_child(row)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	col.add_child(spacer)
	var ok: TextureButton = UIKit.pill_button("Confirm", 250.0)
	ok.pressed.connect(_finish)
	var wrap: CenterContainer = CenterContainer.new()
	wrap.custom_minimum_size = Vector2(col.size.x, ok.size.y)
	wrap.add_child(ok)
	col.add_child(wrap)
	for part: String in swatches.keys():
		_mark(part, (swatches[part] as Array)[0] as Button)


func _small_button(txt: String) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(56, 40)
	b.add_theme_font_override("font", UIKit.font)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", UIKit.box(Color("#FEC473"), Color("#7F442C"), 3, 8))
	b.add_theme_stylebox_override("hover", UIKit.box(Color("#FFD65A"), Color("#7F442C"), 3, 8))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color("#DE9A4C"), Color("#7F442C"), 3, 8))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, UIKit.BROWN)
	return b


func _swatch(c: Color) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = c
	n.border_color = Color("#43251D")
	n.set_border_width_all(3)
	n.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _mark(part: String, chosen: Button) -> void:
	for b: Variant in swatches[part] as Array:
		var sw: Button = b as Button
		var sb: StyleBoxFlat = (sw.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.border_color = Color("#FFD65A") if sw == chosen else Color("#43251D")
		sb.set_border_width_all(5 if sw == chosen else 3)
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)


func _pick(part: String, c: Color, sw: Button) -> void:
	Game.colors[part] = c
	Game.apply_colors(mat, "besar")
	_mark(part, sw)
	var tw: Tween = create_tween()
	tw.tween_property(preview, "scale", Vector2(1.04, 1.04), 0.08)
	tw.tween_property(preview, "scale", Vector2.ONE, 0.10)


func _finish() -> void:
	var nm: String = name_edit.text.strip_edges()
	Game.player_name = nm if nm != "" else "Farmer"
	done.emit()
