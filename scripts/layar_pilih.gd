extends Control
## Layar awal: pilih Male / Female. Kartu yang dipilih menyala & membesar, yang lain meredup.

signal confirmed(gender: String)
signal closed

var panel: TextureRect
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
	var h: float = minf(vs.y - 50.0, 640.0)
	panel = UIKit.image("res://assets/ui/pilih_karakter.png", h * 1381.0 / 1069.0, h)
	panel.position = (vs - panel.size) / 2.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var P: Dictionary = UIKit.layout["pilih"] as Dictionary
	for g: String in ["male", "female"]:
		var r: Array = P[g] as Array
		var gl: Panel = Panel.new()
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.draw_center = false
		sb.border_color = Color("#FFD65A")
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(18)
		sb.set_expand_margin_all(4)
		gl.add_theme_stylebox_override("panel", sb)
		UIKit.place(gl, panel.size, r)
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gl.visible = false
		panel.add_child(gl)
		glow[g] = gl
		var b: Button = _hit(r, func() -> void: _choose(g))
		cards[g] = b
	_hit(P["confirm"] as Array, _confirm)
	_hit(P["x"] as Array, func() -> void: closed.emit())
	hint = UIKit.pixel_label("Tap a character, then Confirm", 20, UIKit.CREAM, 5, Color("#1E3F2B"))
	hint.position = Vector2(0, panel.position.y + panel.size.y + 2)
	hint.size = Vector2(vs.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _hit(r: Array, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.flat = true
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.place(b, panel.size, r)
	b.pressed.connect(cb)
	panel.add_child(b)
	return b


func _choose(g: String) -> void:
	chosen = g
	for k: String in glow.keys():
		(glow[k] as Panel).visible = k == g
		var other: Button = cards[k] as Button
		other.modulate = Color.WHITE
		var gl: Panel = glow[k] as Panel
		gl.pivot_offset = gl.size / 2.0
		create_tween().tween_property(gl, "scale", Vector2(1.03, 1.03) if k == g else Vector2.ONE, 0.12)
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
