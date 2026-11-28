extends Control
## Layar awal: pilih Male / Female di bingkai 1.5:1. Kartu yang dipilih menyala & membesar sedikit.

signal confirmed(gender: String)
signal closed

var panel: TextureRect
var inner: Control
var cards: Dictionary = {}
var glow: Dictionary = {}
var chosen: String = ""
var hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#1E3F2B")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vs: Vector2 = get_viewport_rect().size
	var fr: Array = UIKit.frame("bingkai_15", minf(vs.y - 60.0, 640.0), vs.x - 40.0)
	panel = fr[0] as TextureRect
	inner = fr[1] as Control
	panel.position = ((vs - panel.size) / 2.0 - Vector2(0, 14)).round()
	add_child(panel)
	UIKit.frame_title(inner, "Choose Your Character", 34)
	UIKit.close_button(panel, inner).pressed.connect(func() -> void: closed.emit())
	# dua kartu berdampingan
	var ok_h: float = inner.size.y * 0.15
	var top: float = 58.0
	var card_h: float = inner.size.y - top - ok_h - 24.0
	var card_w: float = card_h * 539.0 / 679.0
	var gap: float = card_w * 0.16
	var x0: float = (inner.size.x - card_w * 2.0 - gap) / 2.0
	var i: int = 0
	for g: String in ["male", "female"]:
		var b: TextureButton = TextureButton.new()
		b.texture_normal = load("res://assets/ui/kartu_%s.png" % g) as Texture2D
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.position = Vector2(x0 + i * (card_w + gap), top)
		b.size = Vector2(card_w, card_h)
		b.pivot_offset = b.size / 2.0
		b.pressed.connect(func() -> void: _choose(g))
		var gl: Panel = Panel.new()
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color("#FFD65A")
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(14)
		sb.set_expand_margin_all(6)
		gl.add_theme_stylebox_override("panel", sb)
		gl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gl.visible = false
		b.add_child(gl)
		inner.add_child(b)
		cards[g] = b
		glow[g] = gl
		i += 1
	var ok: TextureButton = UIKit.icon_button("res://assets/ui/tombol_confirm.png", ok_h * 3.2)
	ok.position = Vector2((inner.size.x - ok.size.x) / 2.0, inner.size.y - ok.size.y - 4.0)
	ok.pressed.connect(_confirm)
	inner.add_child(ok)
	hint = UIKit.pixel_label("Tap a character, then Confirm", 22, UIKit.CREAM, 5, Color("#1E3F2B"))
	hint.position = Vector2(0, panel.position.y + panel.size.y + 4)
	hint.size = Vector2(vs.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _choose(g: String) -> void:
	chosen = g
	for k: String in cards.keys():
		(glow[k] as Panel).visible = k == g
		var c: TextureButton = cards[k] as TextureButton
		c.modulate = Color.WHITE if k == g else Color(0.82, 0.82, 0.82)
		create_tween().tween_property(c, "scale", Vector2(1.04, 1.04) if k == g else Vector2.ONE, 0.12)
	hint.text = "%s selected - tap Confirm" % ("Male" if g == "male" else "Female")


func _confirm() -> void:
	if chosen == "":
		hint.text = "Choose Male or Female first"
		var tw: Tween = create_tween()
		tw.tween_property(hint, "position:x", 8.0, 0.05)
		tw.tween_property(hint, "position:x", -8.0, 0.08)
		tw.tween_property(hint, "position:x", 0.0, 0.05)
		return
	confirmed.emit("cowok" if chosen == "male" else "cewek")
