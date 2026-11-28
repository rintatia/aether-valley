extends Node2D
## Layar uji tileset SpriteCook. Geser = seret satu jari, zoom = tombol/cubit.

const DualGrid = preload("res://scripts/dualgrid.gd")
const T: int = 32
const ZOOMS: Array[int] = [2, 3, 4]   # x2 = terjauh: detail rumput tetap terlihat, peta selalu memenuhi layar

var cam: Camera2D
var zoom_i: int = 0
var map_w: int = 0
var map_h: int = 0
var dragging: bool = false
var touches: Dictionary = {}
var pinch_ref: float = 0.0
var pinch_zoom0: float = 2.0
var pinch_world: Vector2 = Vector2.ZERO
var pinching: bool = false
var snap_tw: Tween


func _ready() -> void:
	var m: Dictionary = Art.load_json("res://data/uji_tileset.json")
	map_w = int(m["cols"])
	map_h = int(m["rows"])
	if m.has("bg"):
		var bg: Polygon2D = Polygon2D.new()
		bg.color = Color(str(m["bg"]))
		bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(map_w * T, 0), Vector2(map_w * T, map_h * T), Vector2(0, map_h * T)])
		add_child(bg)
	if m.has("baked"):
		# peta rumput organik yang sudah dipanggang (tepi alami per piksel, bukan per petak)
		var sp: Sprite2D = Sprite2D.new()
		sp.texture = load("res://assets/lanskap/%s.png" % str(m["baked"])) as Texture2D
		sp.centered = false
		add_child(sp)
	for L: Variant in ([] if m.has("baked") else m["layers"]) as Array:
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
		if ld.has("scatter"):
			var sd: Dictionary = Art.load_json("res://data/%s.json" % str(ld["scatter"]))
			layer.call("set_scatter", load("res://assets/uji_spritecook/%s.png" % str(ld["scatter"])) as Texture2D, sd["rects"] as Array, sd.get("weights", []) as Array, float(sd["per_tile"]), load("res://assets/uji_spritecook/%s.png" % str(ld["allowed"])) as Texture2D)
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
	_clamp_cam()


## Kamera tidak boleh memperlihatkan area di luar peta (layar selalu penuh rumput).
func _clamp_cam() -> void:
	var half: Vector2 = get_viewport_rect().size / cam.zoom / 2.0
	var mw: float = map_w * T
	var mh: float = map_h * T
	cam.position.x = mw / 2.0 if half.x * 2.0 >= mw else clampf(cam.position.x, half.x, mw - half.x)
	cam.position.y = mh / 2.0 if half.y * 2.0 >= mh else clampf(cam.position.y, half.y, mh - half.y)


func _hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var root: Control = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var l: Label = UIKit.label("Lanskap starter Aether Valley  -  seret untuk geser", 22)
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


func _two() -> Array:
	var v: Array = touches.values()
	return [v[0] as Vector2, v[1] as Vector2]


## Cubit seperti Stardew Valley: zoom halus mengikuti jari, berpusat di titik tengah kedua jari.
## Saat jari dilepas, zoom menempel ke tingkat bulat terdekat (x2/x3/x4) agar piksel tetap tajam.
func _pinch_begin() -> void:
	var p: Array = _two()
	pinch_ref = maxf((p[0] as Vector2).distance_to(p[1] as Vector2), 1.0)
	pinch_zoom0 = cam.zoom.x
	var mid: Vector2 = ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0
	pinch_world = cam.position + (mid - get_viewport_rect().size / 2.0) / cam.zoom.x
	pinching = true
	if snap_tw != null:
		snap_tw.kill()


func _pinch_move() -> void:
	var p: Array = _two()
	var d: float = (p[0] as Vector2).distance_to(p[1] as Vector2)
	var z: float = clampf(pinch_zoom0 * d / pinch_ref, float(ZOOMS[0]) - 0.25, float(ZOOMS[ZOOMS.size() - 1]) + 0.25)
	var mid: Vector2 = ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0
	cam.zoom = Vector2(z, z)
	cam.position = pinch_world - (mid - get_viewport_rect().size / 2.0) / z
	_clamp_cam()


func _pinch_end() -> void:
	pinching = false
	var best: int = 0
	for i: int in range(ZOOMS.size()):
		if absf(ZOOMS[i] - cam.zoom.x) < absf(ZOOMS[best] - cam.zoom.x):
			best = i
	zoom_i = best
	var target: float = float(ZOOMS[best])
	snap_tw = create_tween()
	snap_tw.tween_method(func(z: float) -> void:
		cam.zoom = Vector2(z, z)
		_clamp_cam(), cam.zoom.x, target, 0.12)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e as InputEventScreenTouch
		if t.pressed:
			touches[t.index] = t.position
			if touches.size() == 2:
				_pinch_begin()
		else:
			touches.erase(t.index)
			if pinching and touches.size() < 2:
				_pinch_end()
	elif e is InputEventScreenDrag:
		var dr: InputEventScreenDrag = e as InputEventScreenDrag
		touches[dr.index] = dr.position
		if touches.size() >= 2 and pinching:
			_pinch_move()
		elif touches.size() == 1 and not pinching:
			cam.position -= dr.relative / cam.zoom.x
			_clamp_cam()
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and touches.is_empty():
		cam.position -= (e as InputEventMouseMotion).relative / cam.zoom.x
		_clamp_cam()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_i = clampi(zoom_i + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 0, ZOOMS.size() - 1)
			_apply_zoom()
