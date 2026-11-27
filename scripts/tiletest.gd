extends Node2D
## Layar uji tileset SpriteCook. Geser = seret satu jari, zoom = tombol/cubit.

const DualGrid = preload("res://scripts/dualgrid.gd")
const T: int = 32
const ZOOMS: Array[int] = [1, 2, 3, 4]

var cam: Camera2D
var zoom_i: int = 0
var map_w: int = 0
var map_h: int = 0
var dragging: bool = false
var touches: Dictionary = {}
var pinch_ref: float = 0.0
var pinch_done: bool = false


func _ready() -> void:
	var m: Dictionary = Art.load_json("res://data/uji_tileset.json")
	map_w = int(m["cols"])
	map_h = int(m["rows"])
	for L: Variant in m["layers"] as Array:
		var ld: Dictionary = L as Dictionary
		var arr: PackedByteArray = PackedByteArray()
		for v: Variant in ld["cells"] as Array:
			arr.append(int(v))
		var layer: Node2D = DualGrid.new()
		add_child(layer)
		var clean: Texture2D = null
		if ld.has("clean"):
			clean = load("res://assets/uji_spritecook/%s.png" % str(ld["clean"])) as Texture2D
		layer.call("setup", load("res://assets/uji_spritecook/%s.png" % str(ld["tex"])) as Texture2D, arr, map_w, map_h, T, clean)
	cam = Camera2D.new()
	cam.position = Vector2(map_w * T / 2.0, map_h * T / 2.0)
	add_child(cam)
	cam.make_current()
	_apply_zoom()
	_hud()


func set_zoom(i: int, focus: Vector2) -> void:
	zoom_i = clampi(i, 0, ZOOMS.size() - 1)
	cam.position = focus
	_apply_zoom()


func _apply_zoom() -> void:
	cam.zoom = Vector2(ZOOMS[zoom_i], ZOOMS[zoom_i])


func _hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var l: Label = UIKit.label("Uji tileset SpriteCook (32 px)  -  seret untuk geser", 22)
	l.position = Vector2(16, 12)
	root.add_child(l)
	var box: HBoxContainer = HBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -330
	box.offset_right = -16
	box.offset_top = -84
	box.offset_bottom = -16
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var back: Button = UIKit.button("Kembali", 140, 64)
	back.pressed.connect(func() -> void: get_tree().reload_current_scene())
	var bm: Button = UIKit.button("-", 64, 64)
	bm.pressed.connect(func() -> void:
		zoom_i = clampi(zoom_i - 1, 0, ZOOMS.size() - 1)
		_apply_zoom())
	var bp: Button = UIKit.button("+", 64, 64)
	bp.pressed.connect(func() -> void:
		zoom_i = clampi(zoom_i + 1, 0, ZOOMS.size() - 1)
		_apply_zoom())
	box.add_child(back)
	box.add_child(bm)
	box.add_child(bp)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e as InputEventScreenTouch
		if t.pressed:
			touches[t.index] = t.position
			if touches.size() == 2:
				var v: Array = touches.values()
				pinch_ref = (v[0] as Vector2).distance_to(v[1] as Vector2)
				pinch_done = false
		else:
			touches.erase(t.index)
	elif e is InputEventScreenDrag:
		var dr: InputEventScreenDrag = e as InputEventScreenDrag
		touches[dr.index] = dr.position
		if touches.size() == 2 and not pinch_done and pinch_ref > 1.0:
			var v2: Array = touches.values()
			var r: float = (v2[0] as Vector2).distance_to(v2[1] as Vector2) / pinch_ref
			if r >= 1.25 or r <= 0.8:
				zoom_i = clampi(zoom_i + (1 if r >= 1.25 else -1), 0, ZOOMS.size() - 1)
				_apply_zoom()
				pinch_done = true
		elif touches.size() == 1:
			cam.position -= dr.relative / cam.zoom.x
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and touches.is_empty():
		cam.position -= (e as InputEventMouseMotion).relative / cam.zoom.x
