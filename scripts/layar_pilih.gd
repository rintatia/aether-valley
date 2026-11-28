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
var base_pos: Dictionary = {}
var shadows: Dictionary = {}
var tweens: Dictionary = {}


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
	var top: float = 74.0
	var card_h: float = inner.size.y - top - ok_h - 30.0
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
		b.pressed.connect(func() -> void:
			UIKit.sfx("klik")
			_choose(g))
		# bayangan di bawah kartu: makin jelas saat kartu terangkat
		var sh: Panel = Panel.new()
		var ssb: StyleBoxFlat = StyleBoxFlat.new()
		ssb.bg_color = Color(0.10, 0.06, 0.04, 0.38)
		ssb.set_corner_radius_all(18)
		sh.add_theme_stylebox_override("panel", ssb)
		sh.position = b.position + Vector2(card_w * 0.06, card_h * 0.05)
		sh.size = Vector2(card_w * 0.88, card_h * 0.95)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.modulate.a = 0.0
		inner.add_child(sh)
		shadows[g] = sh
		base_pos[g] = b.position
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


## Kartu terpilih sedikit terangkat (halus) + garis kuning; kartu lain sedikit meredup.
func _choose(g: String) -> void:
	chosen = g
	for k: String in cards.keys():
		var c: TextureButton = cards[k] as TextureButton
		var sh: Panel = shadows[k] as Panel
		var bp: Vector2 = base_pos[k] as Vector2
		(glow[k] as Panel).visible = k == g
		if tweens.has(k) and (tweens[k] as Tween).is_valid():
			(tweens[k] as Tween).kill()
		var tw: Tween = create_tween().set_parallel(true)
		tweens[k] = tw
		if k == g:
			c.modulate = Color.WHITE
			inner.move_child(c, inner.get_child_count() - 1)
			tw.tween_property(c, "position:y", bp.y - 4.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", Vector2(1.02, 1.02), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(sh, "modulate:a", 0.45, 0.15)
		else:
			tw.tween_property(c, "position:y", bp.y, 0.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(c, "scale", Vector2.ONE, 0.2)
			tw.tween_property(c, "modulate", Color(0.9, 0.9, 0.9), 0.2)
			tw.tween_property(sh, "modulate:a", 0.0, 0.2)
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
