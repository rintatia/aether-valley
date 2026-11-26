extends Node2D
## Dunia: peta ladang & kota, ketuk-untuk-jalan, bertani, dagang, HUD.

const UI = preload("res://scripts/ui.gd")
const PlayerScript = preload("res://scripts/player.gd")
const CELL: int = 8
const SPEED: float = 95.0
const ZOOMS: Array[float] = [1.0, 2.0, 3.0]
const TAP_MAX_DIST: float = 24.0
const TAP_MAX_TIME: float = 0.45
const PINCH_IN: float = 1.25
const PINCH_OUT: float = 0.8

var meta: Dictionary = {}
var map_name: String = "farm"
var tex: Texture2D
var solid: PackedByteArray = PackedByteArray()
var mw: int = 0
var mh: int = 0
var astar: AStarGrid2D
var player: Node2D
var cam: Camera2D
var tint: CanvasModulate
var path: PackedVector2Array = PackedVector2Array()
var pending: Dictionary = {}
var zoom_i: int = 1
var ui_open: bool = false
var sel_seed: String = ""
var npcs: Array[Dictionary] = []
var gate_cd: float = 0.0
var transitioning: bool = false

# input
var touches: Dictionary = {}
var pinch_ref: float = 0.0
var pinch_done: bool = false
var was_multi: bool = false
var pressing: bool = false
var press_pos: Vector2 = Vector2.ZERO
var press_t: float = 0.0
var fx_pos: Vector2 = Vector2.ZERO
var fx_t: float = 0.0

# HUD
var hud: CanvasLayer
var hud_root: Control
var lbl_day: Label
var lbl_gold: Label
var bar_stam: ProgressBar
var seed_box: HBoxContainer
var toast: Label
var toast_tw: Tween
var dlg: Control
var shop_vbox: VBoxContainer
var shop_gold: Label
var fade: ColorRect


func _ready() -> void:
	meta = Game.load_json("res://assets/maps_meta.json")
	tint = CanvasModulate.new()
	add_child(tint)
	player = Node2D.new()
	player.set_script(PlayerScript)
	player.set("color", Color(Game.OUTFITS[int(Game.s["color"]) % Game.OUTFITS.size()]))
	add_child(player)
	cam = Camera2D.new()
	player.add_child(cam)
	_build_hud()
	_apply_zoom()
	var spawn: Vector2 = Vector2(-1, -1)
	if float(Game.s["px"]) >= 0.0:
		spawn = Vector2(float(Game.s["px"]), float(Game.s["py"]))
	load_map(str(Game.s["loc"]), spawn)
	_refresh_hud()


# ---------------- peta ----------------
func load_map(mname: String, spawn: Vector2) -> void:
	map_name = mname
	var m: Dictionary = meta[mname] as Dictionary
	tex = load("res://assets/%s_map.png" % mname) as Texture2D
	var img: Image = (load("res://assets/%s_blocked.png" % mname) as Texture2D).get_image()
	img.convert(Image.FORMAT_L8)
	solid = img.get_data()
	mw = img.get_width()
	mh = img.get_height()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = mw
	cam.limit_bottom = mh
	_build_nav()
	npcs.clear()
	if mname == "city":
		var doors: Dictionary = m["doors"] as Dictionary
		var cols: Dictionary = {"brann": "#6B6670", "marlo": "#2480BE", "una": "#D8574F", "tetua": "#9C8CF0"}
		var names: Dictionary = {"brann": "Brann", "marlo": "Marlo", "una": "Una", "tetua": "Tetua"}
		for id: String in doors.keys():
			var d: Array = doors[id] as Array
			npcs.append({"id": id, "name": names[id], "pos": Vector2(float(d[0]), float(d[1]) + 18.0), "color": Color(cols[id])})
		var t: Array = (m["npc"] as Dictionary)["tomas"] as Array
		npcs.append({"id": "tomas", "name": "Tomas", "pos": Vector2(float(t[0]), float(t[1])), "color": Color("#4E912F")})
	var start: Vector2 = spawn
	if start.x < 0.0:
		if mname == "farm":
			var sp: Array = m["spawn"] as Array
			start = Vector2(float(sp[0]), float(sp[1]))
		else:
			var sw: Array = m["spawn_west"] as Array
			start = Vector2(float(sw[0]) + 24.0, float(sw[1]))
	player.position = _cell_center(_nearest_free(_to_cell(start)))
	path = PackedVector2Array()
	pending = {}
	Game.s["loc"] = mname
	gate_cd = 1.0
	queue_redraw()


func _build_nav() -> void:
	var cw: int = mw / CELL
	var ch: int = mh / CELL
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, cw, ch)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL / 2.0, CELL / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for cy: int in range(ch):
		for cx: int in range(cw):
			if _cell_solid(cx, cy):
				astar.set_point_solid(Vector2i(cx, cy), true)


func _cell_solid(cx: int, cy: int) -> bool:
	for oy: int in range(0, CELL, 2):
		for ox: int in range(0, CELL, 2):
			if is_solid(Vector2(cx * CELL + ox, cy * CELL + oy)):
				return true
	return false


func is_solid(p: Vector2) -> bool:
	var x: int = int(p.x)
	var y: int = int(p.y)
	if x < 0 or y < 0 or x >= mw or y >= mh:
		return true
	return solid[y * mw + x] > 127


func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x) / CELL, 0, mw / CELL - 1), clampi(int(p.y) / CELL, 0, mh / CELL - 1))


func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * CELL + CELL / 2.0, c.y * CELL + CELL / 2.0)


func _nearest_free(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r: int in range(1, 30):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if astar.region.has_point(n) and not astar.is_point_solid(n):
					return n
	return c


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a: Vector2i = _nearest_free(_to_cell(from))
	var b: Vector2i = _nearest_free(_to_cell(to))
	return astar.get_point_path(a, b)


# ---------------- gambar ----------------
func _draw() -> void:
	if tex == null:
		return
	draw_texture(tex, Vector2.ZERO)
	if map_name == "farm":
		_draw_plots()
	var font: Font = ThemeDB.fallback_font
	for n: Dictionary in npcs:
		var p: Vector2 = n["pos"] as Vector2
		draw_set_transform(p, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(p.x - 5, p.y - 15, 10, 11), n["color"] as Color)
		draw_circle(p + Vector2(0, -19), 5.0, Color("#F5D0B0"))
		draw_rect(Rect2(p.x - 5, p.y - 25, 10, 4), Color("#7F442C"))
		draw_string(font, p + Vector2(-20, -30), str(n["name"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 9, Color("#FFEE9A"))
	if fx_t > 0.0:
		var k: float = 1.0 - fx_t / 0.4
		draw_arc(fx_pos, 4.0 + 10.0 * k, 0.0, TAU, 24, Color(1, 1, 1, 1.0 - k), 1.5)


func _plot_geo() -> Array:
	var m: Dictionary = meta["farm"] as Dictionary
	var o: Array = m["plot_origin"] as Array
	return [Vector2(float(o[0]), float(o[1])), int(m["plot_cols"]), int(m["plot_rows"]), int(m["cell"])]


func _draw_plots() -> void:
	var g: Array = _plot_geo()
	var origin: Vector2 = g[0] as Vector2
	var cols: int = g[1] as int
	var rows: int = g[2] as int
	var cs: int = g[3] as int
	for cy: int in range(rows):
		for cx: int in range(cols):
			var r: Rect2 = Rect2(origin + Vector2(cx * cs, cy * cs), Vector2(cs, cs))
			var p: Dictionary = Game.plot(Vector2i(cx, cy))
			if p.is_empty():
				draw_rect(r, Color(1, 1, 1, 0.10), false, 1.0)
				continue
			var wet: bool = bool(p["wet"])
			draw_rect(r.grow(-1.0), Color("#43251D") if wet else Color("#7F442C"))
			var cid: String = str(p["crop"])
			if cid == "":
				continue
			var c: Dictionary = Game.crops[cid] as Dictionary
			var f: float = float(int(p["grown"])) / float(int(c["days"]))
			var ctr: Vector2 = r.get_center()
			if Game.is_ready(p):
				draw_circle(ctr + Vector2(0, -1), 5.5, Color(c["color"]))
				draw_circle(ctr + Vector2(-1.5, -3), 1.5, Color(1, 1, 1, 0.7))
				draw_rect(Rect2(ctr.x - 1, ctr.y - 9, 2, 3), Color("#4E912F"))
			else:
				var h: float = 2.0 + f * 7.0
				draw_rect(Rect2(ctr.x - 0.5, ctr.y + 4 - h, 1, h), Color("#6EA427"))
				draw_circle(ctr + Vector2(-2, 4 - h), 1.8, Color("#94BD1B"))
				if f > 0.4:
					draw_circle(ctr + Vector2(2, 5 - h), 1.8, Color("#94BD1B"))


# ---------------- HUD ----------------
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	hud_root = Control.new()
	hud_root.theme = UI.make_theme()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)

	var top: PanelContainer = PanelContainer.new()
	top.position = Vector2(12, 12)
	hud_root.add_child(top)
	var tv: VBoxContainer = VBoxContainer.new()
	top.add_child(tv)
	lbl_day = UI.label("Hari 1  06:00", 24)
	lbl_gold = UI.label("Emas 0", 24, Color("#FFD65A"))
	bar_stam = ProgressBar.new()
	bar_stam.custom_minimum_size = Vector2(220, 18)
	bar_stam.show_percentage = false
	tv.add_child(lbl_day)
	tv.add_child(lbl_gold)
	tv.add_child(bar_stam)

	var bl: PanelContainer = PanelContainer.new()
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 12
	bl.offset_top = -92
	bl.offset_bottom = -12
	hud_root.add_child(bl)
	seed_box = HBoxContainer.new()
	seed_box.add_theme_constant_override("separation", 8)
	bl.add_child(seed_box)

	var br: HBoxContainer = HBoxContainer.new()
	br.anchor_left = 1.0
	br.anchor_right = 1.0
	br.anchor_top = 1.0
	br.anchor_bottom = 1.0
	br.offset_left = -300
	br.offset_right = -12
	br.offset_top = -80
	br.offset_bottom = -12
	br.alignment = BoxContainer.ALIGNMENT_END
	br.add_theme_constant_override("separation", 8)
	hud_root.add_child(br)
	var bz_out: Button = UI.button("-", 64, 64)
	bz_out.pressed.connect(func() -> void: change_zoom(-1))
	var bz_in: Button = UI.button("+", 64, 64)
	bz_in.pressed.connect(func() -> void: change_zoom(1))
	var bsave: Button = UI.button("Simpan", 120, 64)
	bsave.pressed.connect(func() -> void:
		save_now()
		show_toast("Tersimpan"))
	br.add_child(bz_out)
	br.add_child(bz_in)
	br.add_child(bsave)

	toast = UI.label("", 26, Color("#FFEE9A"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.offset_top = 90
	toast.offset_bottom = 140
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(toast)

	fade = ColorRect.new()
	fade.color = Color("#241912")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	hud_root.add_child(fade)


func _refresh_hud() -> void:
	var f: float = float(Game.s["t"]) / Game.DAY_LEN
	var minutes: int = int((6.0 + f * 18.0) * 60.0)
	lbl_day.text = "Hari %d   %02d:%02d" % [int(Game.s["day"]), (minutes / 60) % 24, minutes % 60]
	lbl_gold.text = "Emas %d" % Game.gold()
	bar_stam.max_value = float(Game.s["max_stam"])
	bar_stam.value = float(Game.s["stam"])
	for c: Node in seed_box.get_children():
		c.queue_free()
	var any: bool = false
	for id: String in Game.items.keys():
		if id.begins_with("_"):
			continue
		var it: Dictionary = Game.items[id] as Dictionary
		if str(it["type"]) != "seed" or Game.count(id) <= 0:
			continue
		any = true
		if sel_seed == "":
			sel_seed = id
		var b: Button = UI.button("%s x%d" % [str(it["name"]).replace("Benih ", ""), Game.count(id)], 0, 56)
		if id == sel_seed:
			b.text = "> " + b.text
			b.modulate = Color("#FFEE9A")
		var sid: String = id
		b.pressed.connect(func() -> void:
			sel_seed = sid
			_refresh_hud())
		seed_box.add_child(b)
	if not any:
		seed_box.add_child(UI.label("Tidak ada benih - beli di toko kota", 22))
	if sel_seed != "" and Game.count(sel_seed) <= 0:
		sel_seed = ""


func show_toast(text: String) -> void:
	toast.text = text
	if toast_tw != null:
		toast_tw.kill()
	toast.modulate.a = 1.0
	toast_tw = create_tween()
	toast_tw.tween_interval(1.6)
	toast_tw.tween_property(toast, "modulate:a", 0.0, 0.5)


func _apply_zoom() -> void:
	var z: float = ZOOMS[zoom_i]
	cam.zoom = Vector2(z, z)


func change_zoom(dir: int) -> void:
	zoom_i = clampi(zoom_i + dir, 0, ZOOMS.size() - 1)
	_apply_zoom()


# ---------------- dialog & toko ----------------
func _open_modal(w: float, h: float) -> VBoxContainer:
	close_dialog()
	ui_open = true
	path = PackedVector2Array()
	pending = {}
	player.set("walking", false)
	dlg = Control.new()
	dlg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dlg.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	UI.center(panel, w, h)
	dlg.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	hud_root.add_child(dlg)
	return v


func close_dialog() -> void:
	if dlg != null:
		dlg.queue_free()
		dlg = null
	ui_open = false
	shop_vbox = null
	_refresh_hud()


func open_dialog(title: String, text: String, buttons: Array) -> void:
	var v: VBoxContainer = _open_modal(720, 300)
	v.add_child(UI.label(title, 30, Color("#FFD65A")))
	v.add_child(UI.label(text, 24))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for b: Array in buttons:
		var btn: Button = UI.button(str(b[0]), 180, 56)
		var cb: Callable = b[1] as Callable
		btn.pressed.connect(func() -> void:
			close_dialog()
			if cb.is_valid():
				cb.call())
		row.add_child(btn)
	v.add_child(row)


func open_npc(id: String) -> void:
	if id == "marlo":
		open_shop()
		return
	var lines: Dictionary = {
		"brann": ["Brann, Pandai Besi", "Tungku masih dingin. Cangkul dan kapak yang lebih baik akan kubuat di pembaruan berikutnya."],
		"una": ["Una, Kedai Tong", "Dapurku belum buka. Nanti kusajikan sup hangat untuk petani yang rajin."],
		"tetua": ["Tetua", "Selamat datang, %s. Ketuk tanah di ladangmu untuk menanam, siram tiap hari, lalu jual panen ke Marlo. Tidur di rumah jamurmu untuk berganti hari." % str(Game.s["name"])],
		"tomas": ["Tomas, Penjaga Gerbang", "Jalan ke desa timur masih ditutup. Sabar ya."],
	}
	var l: Array = lines[id] as Array
	open_dialog(str(l[0]), str(l[1]), [["Tutup", Callable()]])


func open_shop() -> void:
	var v: VBoxContainer = _open_modal(860, 600)
	v.add_child(UI.label("Toko Serba Ada - Marlo", 30, Color("#FFD65A")))
	shop_gold = UI.label("", 24, Color("#FFEE9A"))
	v.add_child(shop_gold)
	var sc: ScrollContainer = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 360)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	shop_vbox = VBoxContainer.new()
	shop_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_vbox.add_theme_constant_override("separation", 8)
	sc.add_child(shop_vbox)
	var close: Button = UI.button("Tutup", 180, 56)
	close.pressed.connect(close_dialog)
	v.add_child(close)
	_shop_fill()


func _shop_fill() -> void:
	for c: Node in shop_vbox.get_children():
		c.queue_free()
	shop_gold.text = "Emasmu: %d" % Game.gold()
	shop_vbox.add_child(UI.label("BELI BENIH", 22, Color("#78C8EB")))
	for id: String in Game.items.keys():
		if id.begins_with("_"):
			continue
		var it: Dictionary = Game.items[id] as Dictionary
		if str(it["type"]) != "seed":
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var l: Label = UI.label("%s  (%d emas)   punya: %d" % [str(it["name"]), int(it["price"]), Game.count(id)], 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b: Button = UI.button("Beli", 110, 52)
		var iid: String = id
		b.disabled = Game.gold() < int(it["price"])
		b.pressed.connect(func() -> void:
			Game.buy(iid)
			_shop_fill())
		row.add_child(b)
		shop_vbox.add_child(row)
	shop_vbox.add_child(UI.label("JUAL HASIL PANEN", 22, Color("#FFD65A")))
	var sold_any: bool = false
	for id: String in Game.items.keys():
		if id.begins_with("_"):
			continue
		var it: Dictionary = Game.items[id] as Dictionary
		if str(it["type"]) != "crop" or Game.count(id) <= 0:
			continue
		sold_any = true
		var row: HBoxContainer = HBoxContainer.new()
		var l: Label = UI.label("%s x%d  (%d emas / buah)" % [str(it["name"]), Game.count(id), int(it["sell"])], 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b1: Button = UI.button("Jual 1", 110, 52)
		var b2: Button = UI.button("Jual semua", 170, 52)
		var iid: String = id
		b1.pressed.connect(func() -> void:
			Game.sell(iid, 1)
			_shop_fill())
		b2.pressed.connect(func() -> void:
			Game.sell(iid, 9999)
			_shop_fill())
		row.add_child(b1)
		row.add_child(b2)
		shop_vbox.add_child(row)
	if not sold_any:
		shop_vbox.add_child(UI.label("Belum ada hasil panen untuk dijual.", 22, Color("#B5B0A6")))


# ---------------- input ----------------
func _pinch_distance() -> float:
	var v: Array = touches.values()
	return (v[0] as Vector2).distance_to(v[1] as Vector2)


func _unhandled_input(e: InputEvent) -> void:
	if ui_open:
		return
	if e is InputEventScreenTouch:
		var t: InputEventScreenTouch = e as InputEventScreenTouch
		if t.pressed:
			touches[t.index] = t.position
			if touches.size() == 2:
				pinch_ref = _pinch_distance()
				pinch_done = false
				was_multi = true
		else:
			touches.erase(t.index)
	elif e is InputEventScreenDrag:
		var dr: InputEventScreenDrag = e as InputEventScreenDrag
		touches[dr.index] = dr.position
		if touches.size() == 2 and not pinch_done and pinch_ref > 1.0:
			var ratio: float = _pinch_distance() / pinch_ref
			if ratio >= PINCH_IN:
				change_zoom(1)
				pinch_done = true
			elif ratio <= PINCH_OUT:
				change_zoom(-1)
				pinch_done = true
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb.pressed:
			pressing = true
			press_pos = mb.position
			press_t = Time.get_ticks_msec() / 1000.0
			was_multi = touches.size() >= 2
		else:
			var dt: float = Time.get_ticks_msec() / 1000.0 - press_t
			if pressing and not was_multi and mb.position.distance_to(press_pos) <= TAP_MAX_DIST and dt <= TAP_MAX_TIME:
				on_tap(get_canvas_transform().affine_inverse() * mb.position)
			pressing = false
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k: Key = (e as InputEventKey).keycode
		if k == KEY_EQUAL or k == KEY_KP_ADD or k == KEY_PLUS:
			change_zoom(1)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			change_zoom(-1)


func on_tap(wp: Vector2) -> void:
	fx_pos = wp
	fx_t = 0.4
	# NPC
	for n: Dictionary in npcs:
		var np: Vector2 = n["pos"] as Vector2
		if wp.distance_to(np + Vector2(0, -10)) < 22.0:
			request_move(np + Vector2(0, 14), {"type": "npc", "id": n["id"]})
			return
	if map_name == "farm":
		var m: Dictionary = meta["farm"] as Dictionary
		var hd: Array = m["house_door"] as Array
		var door: Vector2 = Vector2(float(hd[0]), float(hd[1]))
		if wp.distance_to(door + Vector2(0, -16)) < 30.0:
			request_move(door + Vector2(0, 8), {"type": "sleep"})
			return
		var g: Array = _plot_geo()
		var origin: Vector2 = g[0] as Vector2
		var cs: int = g[3] as int
		var rel: Vector2 = (wp - origin) / float(cs)
		var cell: Vector2i = Vector2i(floori(rel.x), floori(rel.y))
		if cell.x >= 0 and cell.y >= 0 and cell.x < (g[1] as int) and cell.y < (g[2] as int):
			request_move(origin + Vector2(cell.x * cs + cs / 2.0, cell.y * cs + cs / 2.0), {"type": "plot", "cell": cell})
			return
	request_move(wp, {})


func request_move(target: Vector2, act: Dictionary) -> void:
	var p: PackedVector2Array = find_path(player.position, target)
	pending = act
	path = p
	if path.size() > 0 and path[0].distance_to(player.position) < CELL:
		path.remove_at(0)
	if path.is_empty():
		_finish_move()


func _finish_move() -> void:
	player.set("walking", false)
	var act: Dictionary = pending
	pending = {}
	if act.is_empty():
		return
	var t: String = str(act["type"])
	if t == "npc":
		open_npc(str(act["id"]))
	elif t == "sleep":
		open_dialog("Rumah", "Tidur sekarang? Hari berganti dan tanaman yang sudah disiram akan tumbuh.", [["Tidur", Callable(self, "sleep_now")], ["Nanti", Callable()]])
	elif t == "plot":
		_do_plot(act["cell"] as Vector2i)


func _do_plot(cell: Vector2i) -> void:
	var p: Dictionary = Game.plot(cell)
	if p.is_empty():
		if not Game.till(cell):
			show_toast("Terlalu lelah. Tidur dulu di rumah.")
			return
		var msg: String = "Tanah digemburkan"
		if sel_seed != "" and Game.count(sel_seed) > 0 and Game.plant(cell, sel_seed):
			Game.water(cell)
			msg = "Ditanam dan disiram"
		show_toast(msg)
	elif str(p["crop"]) == "":
		if sel_seed == "" or Game.count(sel_seed) <= 0:
			show_toast("Pilih benih di kiri bawah")
		elif Game.plant(cell, sel_seed):
			Game.water(cell)
			show_toast("Ditanam dan disiram")
		else:
			show_toast("Terlalu lelah. Tidur dulu di rumah.")
	elif Game.is_ready(p):
		if Game.harvest(cell):
			show_toast("Panen!")
		else:
			show_toast("Terlalu lelah. Tidur dulu di rumah.")
	elif bool(p["wet"]):
		show_toast("Sudah disiram hari ini")
	elif Game.water(cell):
		show_toast("Disiram")
	else:
		show_toast("Terlalu lelah. Tidur dulu di rumah.")
	_refresh_hud()
	queue_redraw()


func sleep_now() -> void:
	if transitioning:
		return
	transitioning = true
	ui_open = true
	var tw: Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.5)
	await tw.finished
	Game.next_day()
	var m: Dictionary = meta["farm"] as Dictionary
	var hd: Array = m["house_door"] as Array
	if map_name != "farm":
		load_map("farm", Vector2(float(hd[0]), float(hd[1]) + 14.0))
	else:
		player.position = _cell_center(_nearest_free(_to_cell(Vector2(float(hd[0]), float(hd[1]) + 14.0))))
	path = PackedVector2Array()
	save_now()
	_refresh_hud()
	queue_redraw()
	var tw2: Tween = create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, 0.6)
	await tw2.finished
	ui_open = false
	transitioning = false
	show_toast("Hari %d dimulai. Tanaman tumbuh!" % int(Game.s["day"]))


func save_now() -> void:
	Game.s["px"] = player.position.x
	Game.s["py"] = player.position.y
	Game.s["loc"] = map_name
	Game.save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and player != null:
		save_now()


# ---------------- loop ----------------
func _kbd_dir() -> Vector2:
	var d: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	return d


func _process(delta: float) -> void:
	if fx_t > 0.0:
		fx_t -= delta
		queue_redraw()
	if gate_cd > 0.0:
		gate_cd -= delta
	if ui_open or transitioning:
		return
	# waktu
	Game.s["t"] = float(Game.s["t"]) + delta
	var f: float = float(Game.s["t"]) / Game.DAY_LEN
	var col: Color = Color.WHITE
	if f > 0.6:
		var k: float = clampf((f - 0.6) / 0.4, 0.0, 1.0)
		col = Color.WHITE.lerp(Color(1.0, 0.8, 0.68), minf(k * 1.6, 1.0)).lerp(Color(0.78, 0.72, 0.92), maxf(k - 0.6, 0.0) / 0.4)
	tint.color = col
	if f >= 1.0:
		open_dialog("Larut malam", "Kamu kelelahan dan tertidur...", [["Bangun", Callable(self, "sleep_now")]])
		return
	if int(Game.s["t"]) != int(Game.s["t"] - delta):
		_refresh_hud()
	# gerak
	var kd: Vector2 = _kbd_dir()
	var step: float = SPEED * delta
	if kd != Vector2.ZERO:
		path = PackedVector2Array()
		pending = {}
		_move_free(kd.normalized() * step)
		player.set("walking", true)
	elif path.size() > 0:
		var tgt: Vector2 = path[0]
		var to: Vector2 = tgt - player.position
		if to.length() <= step:
			player.position = tgt
			path.remove_at(0)
			if path.is_empty():
				_finish_move()
		else:
			player.position += to.normalized() * step
			if absf(to.x) > 0.5:
				player.set("facing", signf(to.x))
		player.set("walking", path.size() > 0)
	else:
		player.set("walking", false)
	_check_gates()


func _move_free(s: Vector2) -> void:
	var p: Vector2 = player.position
	if s.x != 0.0:
		player.set("facing", signf(s.x))
	if not is_solid(p + s):
		player.position = p + s
	elif not is_solid(p + Vector2(s.x, 0.0)):
		player.position = p + Vector2(s.x, 0.0)
	elif not is_solid(p + Vector2(0.0, s.y)):
		player.position = p + Vector2(0.0, s.y)


func _rect_of(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))


func _check_gates() -> void:
	if gate_cd > 0.0 or transitioning:
		return
	if map_name == "farm":
		var m: Dictionary = meta["farm"] as Dictionary
		if _rect_of(m["gate_east"] as Array).grow(6.0).has_point(player.position):
			_go("city", Vector2(-1, -1))
	else:
		var c: Dictionary = meta["city"] as Dictionary
		if _rect_of(c["gate_west"] as Array).grow(6.0).has_point(player.position):
			var ge: Array = (meta["farm"] as Dictionary)["gate_east"] as Array
			_go("farm", Vector2(float(ge[0]) - 30.0, (float(ge[1]) + float(ge[3])) / 2.0))
		elif _rect_of(c["gate_east"] as Array).grow(6.0).has_point(player.position):
			path = PackedVector2Array()
			pending = {}
			player.position.x -= 24.0
			gate_cd = 2.0
			show_toast("Jalan ke desa timur belum dibuka")


func _go(mname: String, spawn: Vector2) -> void:
	transitioning = true
	var tw: Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.25)
	await tw.finished
	load_map(mname, spawn)
	save_now()
	_refresh_hud()
	var tw2: Tween = create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, 0.3)
	await tw2.finished
	transitioning = false
	show_toast("Ladangmu" if mname == "farm" else "Kota Aether")
