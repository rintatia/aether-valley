extends Node2D
## Dunia v7: peta petak 16 px dari data/maps/*.txt, ketuk-untuk-jalan, zoom bulat.

const T: int = 32
const SPEED: float = 128.0  # piksel seni per detik (4 petak/detik)
const ZOOMS: Array[int] = [2, 3, 4]
const TAP_DIST: float = 24.0
const TAP_TIME: float = 0.45

var legend: Dictionary = {}
var map_id: String = ""
var grid: PackedStringArray = PackedStringArray()
var mw: int = 0
var mh: int = 0
var astar: AStarGrid2D
var spawn: Vector2i = Vector2i.ZERO
var gates: Dictionary = {}       # Vector2i -> map tujuan
var buildings: Array[Dictionary] = []

var ground: Node2D
var ysort: Node2D
var player: Node2D
var cam: Camera2D
var path: PackedVector2Array = PackedVector2Array()
var pending: Dictionary = {}
var zoom_i: int = 0   # x2 = terjauh, detail rumput tetap terlihat
var busy: bool = false
var baked: Texture2D
var pinch_zoom0: float = 2.0
var pinching: bool = false
var snap_tw: Tween

var touches: Dictionary = {}
var pinch_ref: float = 0.0
var pinch_done: bool = false
var multi: bool = false
var pressing: bool = false
var press_pos: Vector2 = Vector2.ZERO
var press_t: float = 0.0

var hud: CanvasLayer
var lbl_map: Label
var toast: Label
var toast_tw: Tween
var fade: ColorRect


func _ready() -> void:
	legend = Art.load_json("res://data/legend.json")
	ground = Node2D.new()
	ground.draw.connect(_draw_ground)
	add_child(ground)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	player = Node2D.new()
	player.set_script(load("res://scripts/player.gd"))
	ysort.add_child(player)
	cam = Camera2D.new()
	player.add_child(cam)
	_build_hud()
	_apply_zoom()
	load_map("ladang", "")


# ---------------- peta ----------------
func load_map(id: String, from_gate: String) -> void:
	map_id = id
	var m: Dictionary = Art.load_json("res://data/maps/%s.json" % id)
	baked = null
	if m.has("baked"):
		baked = load("res://assets/lanskap/%s.png" % str(m["baked"])) as Texture2D
	grid = PackedStringArray()
	for line: Variant in m.get("rows", []) as Array:
		grid.append(str(line))
	mh = grid.size()
	mw = grid[0].length() if mh > 0 else 0
	for c: Node in ysort.get_children():
		if c != player:
			c.queue_free()
	gates.clear()
	buildings.clear()
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, mw, mh)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T / 2.0, T / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var arrive: Vector2i = Vector2i(-1, -1)
	for y: int in range(mh):
		for x: int in range(mw):
			var ch: String = grid[y][x]
			var L: Dictionary = legend.get(ch, {}) as Dictionary
			if bool(L.get("block", false)):
				astar.set_point_solid(Vector2i(x, y), true)
			if L.has("gate"):
				gates[Vector2i(x, y)] = str(L["gate"])
			if bool(L.get("spawn", false)):
				spawn = Vector2i(x, y)
			if L.has("obj"):
				_place_object(str(L["obj"]), Vector2i(x, y), str(L.get("id", "")))
	# datang dari gerbang: muncul di samping gerbang yang menuju peta asal
	if from_gate != "":
		for g: Vector2i in gates.keys():
			if str(gates[g]) == from_gate:
				arrive = g
		if arrive.x >= 0:
			var step: int = 2 if arrive.x < mw / 2 else -2
			spawn = _nearest_free(Vector2i(arrive.x + step, arrive.y))
	player.position = _center(spawn)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = mw * T
	cam.limit_bottom = mh * T
	cam.reset_smoothing()
	path = PackedVector2Array()
	pending = {}
	lbl_map.text = "Ladang" if id == "ladang" else "Kota"
	ground.queue_redraw()


func _place_object(key: String, cell: Vector2i, id: String) -> void:
	var info: Dictionary = Art.info(key)
	var foot: Array = info.get("foot", [1, 1]) as Array
	var fw: int = int(foot[0])
	var fh: int = int(foot[1])
	var kind: String = str(info.get("kind", "object"))
	var sz: Vector2i = Art.size_of(key)
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = Art.tex(key)
	spr.centered = false
	var base: Vector2
	if kind == "building":
		# jangkar = kiri atas tapak; gambar berdiri di tepi bawah tapak
		for yy: int in range(cell.y, cell.y + fh):
			for xx: int in range(cell.x, cell.x + fw):
				if astar.region.has_point(Vector2i(xx, yy)):
					astar.set_point_solid(Vector2i(xx, yy), true)
		base = Vector2((cell.x + fw / 2.0) * T, (cell.y + fh) * T)
		buildings.append({"id": id, "key": key, "rect": Rect2i(cell.x, cell.y, fw, fh),
			"door": Vector2i(cell.x + fw / 2, cell.y + fh), "label": str(info.get("label", key))})
	else:
		astar.set_point_solid(cell, true)
		base = Vector2((cell.x + 0.5) * T, (cell.y + 1) * T)
	spr.position = Vector2(-sz.x / 2.0, -sz.y)
	var holder: Node2D = Node2D.new()
	holder.position = base
	holder.add_child(spr)
	ysort.add_child(holder)


func _draw_ground() -> void:
	if baked != null:
		ground.draw_texture(baked, Vector2.ZERO)
		return
	for y: int in range(mh):
		for x: int in range(mw):
			var L: Dictionary = legend.get(grid[y][x], {}) as Dictionary
			var key: String = str(L.get("tile", "tile_rumput"))
			ground.draw_texture_rect(Art.tex(key), Rect2(x * T, y * T, T, T), false)


func _center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * T, (c.y + 0.5) * T)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(p.x / T), 0, mw - 1), clampi(floori(p.y / T), 0, mh - 1))


func _nearest_free(c: Vector2i) -> Vector2i:
	if astar.region.has_point(c) and not astar.is_point_solid(c):
		return c
	for r: int in range(1, 12):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if astar.region.has_point(n) and not astar.is_point_solid(n):
					return n
	return c


func find_path(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	return astar.get_point_path(_nearest_free(from), _nearest_free(to))


# ---------------- HUD ----------------
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var root: Control = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	lbl_map = UIKit.label("", 26)
	lbl_map.position = Vector2(16, 12)
	root.add_child(lbl_map)
	var box: HBoxContainer = HBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -160
	box.offset_right = -16
	box.offset_top = -84
	box.offset_bottom = -16
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var bm: Button = UIKit.button("-", 64, 64)
	bm.pressed.connect(func() -> void: change_zoom(-1))
	var bp: Button = UIKit.button("+", 64, 64)
	bp.pressed.connect(func() -> void: change_zoom(1))
	box.add_child(bm)
	box.add_child(bp)
	toast = UIKit.label("", 26)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_right = 1.0
	toast.offset_top = 70
	toast.offset_bottom = 110
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)
	fade = ColorRect.new()
	fade.color = Color("#2B2730")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	root.add_child(fade)


func show_toast(t: String) -> void:
	toast.text = t
	if toast_tw != null:
		toast_tw.kill()
	toast.modulate.a = 1.0
	toast_tw = create_tween()
	toast_tw.tween_interval(1.5)
	toast_tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func _apply_zoom() -> void:
	cam.zoom = Vector2(ZOOMS[zoom_i], ZOOMS[zoom_i])


## Jari dilepas: zoom menempel ke tingkat bulat terdekat agar piksel tetap tajam.
func _pinch_end() -> void:
	pinching = false
	var best: int = 0
	for i: int in range(ZOOMS.size()):
		if absf(ZOOMS[i] - cam.zoom.x) < absf(ZOOMS[best] - cam.zoom.x):
			best = i
	zoom_i = best
	snap_tw = create_tween()
	snap_tw.tween_property(cam, "zoom", Vector2(ZOOMS[best], ZOOMS[best]), 0.12)


func change_zoom(d: int) -> void:
	zoom_i = clampi(zoom_i + d, 0, ZOOMS.size() - 1)
	_apply_zoom()


# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if busy:
		return
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e as InputEventScreenTouch
		if t.pressed:
			touches[t.index] = t.position
			if touches.size() == 2:
				var v: Array = touches.values()
				pinch_ref = maxf((v[0] as Vector2).distance_to(v[1] as Vector2), 1.0)
				pinch_zoom0 = cam.zoom.x
				pinching = true
				multi = true
				if snap_tw != null:
					snap_tw.kill()
		else:
			touches.erase(t.index)
			if pinching and touches.size() < 2:
				_pinch_end()
	elif e is InputEventScreenDrag:
		var dr: InputEventScreenDrag = e as InputEventScreenDrag
		touches[dr.index] = dr.position
		if touches.size() >= 2 and pinching:
			# zoom halus mengikuti jari (seperti Stardew Valley)
			var v2: Array = touches.values()
			var z: float = clampf(pinch_zoom0 * (v2[0] as Vector2).distance_to(v2[1] as Vector2) / pinch_ref, ZOOMS[0] - 0.25, ZOOMS[ZOOMS.size() - 1] + 0.25)
			cam.zoom = Vector2(z, z)
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		var now: float = Time.get_ticks_msec() / 1000.0
		if mb.pressed:
			pressing = true
			press_pos = mb.position
			press_t = now
			multi = touches.size() >= 2
		else:
			if pressing and not multi and mb.position.distance_to(press_pos) <= TAP_DIST and now - press_t <= TAP_TIME:
				tap_world(get_canvas_transform().affine_inverse() * mb.position)
			pressing = false
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k: Key = (e as InputEventKey).keycode
		if k == KEY_EQUAL or k == KEY_KP_ADD:
			change_zoom(1)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			change_zoom(-1)


func tap_world(wp: Vector2) -> void:
	var c: Vector2i = _cell(wp)
	for b: Dictionary in buildings:
		var r: Rect2i = b["rect"] as Rect2i
		var hit: Rect2i = Rect2i(r.position.x, r.position.y - 1, r.size.x, r.size.y + 2)
		if hit.has_point(c):
			walk_to(b["door"] as Vector2i, {"type": "door", "b": b})
			return
	if gates.has(c):
		walk_to(c, {"type": "gate"})
		return
	walk_to(c, {})


func walk_to(c: Vector2i, act: Dictionary) -> void:
	pending = act
	path = find_path(_cell(player.position), c)
	if path.size() > 0 and path[0].distance_to(player.position) < 2.0:
		path.remove_at(0)
	if path.is_empty():
		_arrived()


func _arrived() -> void:
	player.set("walking", false)
	var a: Dictionary = pending
	pending = {}
	if a.is_empty():
		return
	if str(a["type"]) == "door":
		var b: Dictionary = a["b"] as Dictionary
		show_toast("%s - segera dibuka" % str(b["label"]))
	elif str(a["type"]) == "gate":
		var to: String = str(gates.get(_cell(player.position), ""))
		if to != "":
			_go(to)


func _go(to: String) -> void:
	busy = true
	var tw: Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.25)
	await tw.finished
	var from: String = map_id
	load_map(to, from)
	var tw2: Tween = create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, 0.3)
	await tw2.finished
	busy = false


# ---------------- gerak ----------------
func _process(delta: float) -> void:
	if busy:
		return
	var d: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	var step: float = SPEED * delta
	if d != Vector2.ZERO:
		path = PackedVector2Array()
		pending = {}
		var np: Vector2 = player.position + d.normalized() * step
		if not astar.is_point_solid(_cell(np)):
			player.position = np
		player.call("face", d)
		player.set("walking", true)
		_check_gate()
		return
	if path.is_empty():
		player.set("walking", false)
		return
	var tgt: Vector2 = path[0]
	var to: Vector2 = tgt - player.position
	player.call("face", to)
	player.set("walking", true)
	if to.length() <= step:
		player.position = tgt
		path.remove_at(0)
		if path.is_empty():
			_arrived()
	else:
		player.position += to.normalized() * step


func _check_gate() -> void:
	var c: Vector2i = _cell(player.position)
	if gates.has(c):
		_go(str(gates[c]))
