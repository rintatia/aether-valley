extends CanvasLayer
## HUD permainan: status bar (siang/malam), setting + buku (kiri atas), shortcut bar + peta + tas (bawah),
## popup tas (5x5, 10 halaman), peta, buku, setting. Semua tombol bisa ditekan.

const STATUS_W: float = 440.0
const BAR_W: float = 640.0
const ICON_SET: float = 78.0
const ICON_BIG: float = 92.0

var world: Node2D
var root: Control
var status: Control
var st_day: TextureRect
var st_night: TextureRect
var lb_date: Label
var lb_clock: Label
var lb_coin: Label
var lb_crystal: Label
var lb_season: Label
var season_icon: Control
var btn_set: TextureButton
var btn_book: TextureButton
var bar: Control
var btn_map: TextureButton
var btn_bag: TextureButton
var slot_nodes: Array[Dictionary] = []
var toast: Label
var toast_tw: Tween
var fade: ColorRect
var modal: Control
var modal_open: bool = false
var bag_page: int = 0
var bag_slots: Array[Dictionary] = []
var bag_page_label: Label
var bag_dots: Control
var last_minute: int = -1


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_status()
	_build_left()
	_build_bottom()
	toast = UIKit.pixel_label("", 24, UIKit.CREAM, 6, Color("#2B2730"))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	root.add_child(toast)
	fade = ColorRect.new()
	fade.color = Color("#2B2730")
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	root.add_child(fade)
	get_viewport().size_changed.connect(_layout)
	Game.bag_changed.connect(_refresh_items)
	_layout()
	_refresh_items()
	_refresh_status(true)


# ---------------- tata letak (ikut ukuran layar & jarak aman bingkai HP) ----------------
func _layout() -> void:
	var vs: Vector2 = root.get_viewport_rect().size
	var m: Vector4 = UIKit.safe_margin(root)
	status.position = Vector2(vs.x - m.z - STATUS_W, m.y)
	btn_set.position = Vector2(m.x, m.y)
	btn_book.position = Vector2(m.x, m.y + btn_set.size.y + 10.0)
	var total: float = btn_map.size.x + 10.0 + BAR_W + 10.0 + btn_bag.size.x
	var x0: float = (vs.x - total) / 2.0
	var bar_h: float = bar.size.y
	var y_bar: float = vs.y - m.w - bar_h
	btn_map.position = Vector2(x0, y_bar + (bar_h - btn_map.size.y) / 2.0)
	bar.position = Vector2(x0 + btn_map.size.x + 10.0, y_bar)
	btn_bag.position = Vector2(bar.position.x + BAR_W + 10.0, y_bar + (bar_h - btn_bag.size.y) / 2.0)
	toast.position = Vector2(0, m.y + 150.0)
	toast.size = Vector2(vs.x, 40)
	fade.position = Vector2.ZERO
	fade.size = vs
	if modal != null:
		modal.size = vs


# ---------------- status bar ----------------
func _build_status() -> void:
	status = Control.new()
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status)
	st_day = UIKit.image("res://assets/ui/status_siang.png", STATUS_W)
	st_night = UIKit.image("res://assets/ui/status_malam.png", STATUS_W, st_day.size.y)
	status.add_child(st_day)
	status.add_child(st_night)
	status.size = st_day.size
	var L: Dictionary = UIKit.layout["status"] as Dictionary
	var sz: Vector2 = st_day.size
	lb_date = _field_label(L["tanggal"] as Array, sz, 18)
	lb_clock = _field_label(L["jam"] as Array, sz, 21)
	lb_coin = _field_label(L["koin"] as Array, sz, 18)
	lb_crystal = _field_label(L["kristal"] as Array, sz, 18)
	lb_coin.add_theme_color_override("font_color", Color("#FFEE9A"))
	lb_crystal.add_theme_color_override("font_color", Color("#C9BFFA"))
	var sh: Array = L["musim"] as Array
	season_icon = Control.new()
	season_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(season_icon, sz, [sh[0], float(sh[1]) + 0.04, sh[2], float(sh[1]) + 0.36])
	season_icon.draw.connect(_draw_season_icon)
	status.add_child(season_icon)
	lb_season = UIKit.pixel_label("", 12, UIKit.BROWN)
	UIKit.place(lb_season, sz, [float(sh[0]) - 0.01, float(sh[1]) + 0.36, float(sh[2]) + 0.01, float(sh[1]) + 0.52])
	lb_season.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_season.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_child(lb_season)


func _field_label(r: Array, sz: Vector2, fs: int) -> Label:
	var l: Label = UIKit.pixel_label("", fs, UIKit.BROWN)
	UIKit.place(l, sz, r)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.offset_top -= 2
	status.add_child(l)
	return l


func _refresh_status(force: bool = false) -> void:
	var mi: int = int(Game.minute)
	if mi == last_minute and not force:
		return
	last_minute = mi
	var night: bool = Game.is_night()
	st_day.visible = not night
	st_night.visible = night
	lb_date.text = Game.date_text()
	lb_clock.text = Game.clock_text()
	lb_clock.add_theme_color_override("font_color", UIKit.CREAM if night else UIKit.BROWN)
	lb_coin.text = str(clampi(Game.coins, 0, 99999999))
	lb_crystal.text = str(clampi(Game.crystals, 0, 999999))
	lb_season.text = Game.status_text()
	season_icon.queue_redraw()


func _draw_season_icon() -> void:
	var c: Vector2 = season_icon.size / 2.0
	var r: float = minf(season_icon.size.x, season_icon.size.y) * 0.34
	var s: String = Game.status_text()
	var ink: Color = Color("#43251D")
	if s == "Spring":
		for i: int in range(5):
			var a: float = TAU * i / 5.0 - PI / 2.0
			season_icon.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.42, Color("#F37CAB"))
		season_icon.draw_circle(c, r * 0.30, Color("#FFD65A"))
	elif s == "Summer":
		for i: int in range(8):
			var a2: float = TAU * i / 8.0
			season_icon.draw_line(c + Vector2(cos(a2), sin(a2)) * r * 0.62, c + Vector2(cos(a2), sin(a2)) * r * 1.0, Color("#E0B83C"), 2.0)
		season_icon.draw_circle(c, r * 0.52, Color("#FFD65A"))
	elif s == "Autumn":
		var pts: PackedVector2Array = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.1), c + Vector2(r * 0.25, r * 0.9),
			c + Vector2(-r * 0.25, r * 0.9), c + Vector2(-r * 0.8, -r * 0.1)])
		season_icon.draw_colored_polygon(pts, Color("#C87D38"))
		season_icon.draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 1.05), ink, 1.5)
	elif s == "Winter":
		for i: int in range(3):
			var a3: float = PI * i / 3.0
			season_icon.draw_line(c - Vector2(cos(a3), sin(a3)) * r, c + Vector2(cos(a3), sin(a3)) * r, Color("#2480BE"), 2.5)
		season_icon.draw_circle(c, r * 0.18, Color("#78C8EB"))
	else:
		season_icon.draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.42, Color("#B5B0A6"))
		season_icon.draw_circle(c + Vector2(r * 0.25, -r * 0.3), r * 0.5, Color("#B5B0A6"))
		season_icon.draw_rect(Rect2(c.x - r * 0.75, c.y - r * 0.2, r * 1.5, r * 0.4), Color("#B5B0A6"))
		for i: int in range(3):
			var x: float = c.x - r * 0.5 + i * r * 0.5
			season_icon.draw_line(Vector2(x, c.y + r * 0.35), Vector2(x - r * 0.15, c.y + r * 0.85), Color("#34A0D6"), 2.0)


# ---------------- kiri atas: setting & buku ----------------
func _build_left() -> void:
	btn_set = UIKit.icon_button("res://assets/ui/ikon_setting.png", ICON_SET)
	btn_set.pressed.connect(func() -> void: open_popup("setting"))
	root.add_child(btn_set)
	btn_book = UIKit.icon_button("res://assets/ui/ikon_buku.png", ICON_SET)
	btn_book.pressed.connect(func() -> void: open_popup("buku"))
	root.add_child(btn_book)


# ---------------- bawah: peta | shortcut | tas ----------------
func _build_bottom() -> void:
	bar = UIKit.image("res://assets/ui/bar_shortcut.png", BAR_W)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(bar)
	bar.size = bar.custom_minimum_size
	var L: Dictionary = UIKit.layout["shortcut"] as Dictionary
	var sy: Array = L["slot_y"] as Array
	var i: int = 0
	for sxv: Variant in L["slot_x"] as Array:
		var sx: Array = sxv as Array
		var slot: Dictionary = _make_slot(bar, bar.size, [sx[0], sy[0], sx[1], sy[1]], i)
		slot_nodes.append(slot)
		i += 1
	btn_map = UIKit.icon_button("res://assets/ui/ikon_peta.png", ICON_BIG)
	btn_map.pressed.connect(func() -> void: open_popup("peta"))
	root.add_child(btn_map)
	btn_bag = UIKit.icon_button("res://assets/ui/ikon_tas.png", ICON_BIG)
	btn_bag.pressed.connect(func() -> void: open_popup("tas"))
	root.add_child(btn_bag)


## Satu kotak item (dipakai di shortcut & tas): ikon + jumlah + sorot pilihan. Bisa ditekan.
func _make_slot(parent: Control, psize: Vector2, r: Array, index: int) -> Dictionary:
	var b: Button = Button.new()
	b.flat = true
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.place(b, psize, r)
	parent.add_child(b)
	var hl: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.93, 0.6, 0.18)
	sb.border_color = Color("#FFD65A")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	hl.add_theme_stylebox_override("panel", sb)
	hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.visible = false
	b.add_child(hl)
	var ic: TextureRect = TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 5
	ic.offset_top = 5
	ic.offset_right = -5
	ic.offset_bottom = -5
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var n: Label = UIKit.pixel_label("", 15, UIKit.CREAM, 4, Color("#43251D"))
	n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	n.offset_right = -3
	n.offset_bottom = 1
	b.add_child(n)
	var slot: Dictionary = {"btn": b, "icon": ic, "count": n, "hl": hl, "index": index}
	b.pressed.connect(func() -> void: _slot_pressed(slot))
	return slot


func _slot_pressed(slot: Dictionary) -> void:
	var idx: int = int(slot["index"])
	Game.selected_slot = idx
	_refresh_items()
	var s: Dictionary = Game.bag[idx] as Dictionary
	if not s.is_empty():
		show_toast("%s x%d" % [str((Game.ITEMS[str(s["id"])] as Dictionary)["nama"]), int(s["n"])])


func _fill_slot(slot: Dictionary) -> void:
	var idx: int = int(slot["index"])
	var s: Dictionary = Game.bag[idx] as Dictionary
	var ic: TextureRect = slot["icon"] as TextureRect
	var n: Label = slot["count"] as Label
	if s.is_empty():
		ic.texture = null
		n.text = ""
	else:
		ic.texture = Game.item_icon(str(s["id"]))
		n.text = str(int(s["n"])) if int(s["n"]) > 1 else ""
	(slot["hl"] as Panel).visible = idx == Game.selected_slot


func _refresh_items() -> void:
	for s: Dictionary in slot_nodes:
		_fill_slot(s)
	for s: Dictionary in bag_slots:
		_fill_slot(s)


# ---------------- popup ----------------
func open_popup(kind: String) -> void:
	close_popup()
	modal_open = true
	modal = Control.new()
	modal.size = root.get_viewport_rect().size
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	root.move_child(modal, fade.get_index())
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close_popup())
	match kind:
		"tas":
			_popup_bag()
		"peta":
			_popup_map()
		"buku":
			_popup_book()
		"setting":
			_popup_settings()
	modal.modulate.a = 0.0
	create_tween().tween_property(modal, "modulate:a", 1.0, 0.12)


func close_popup() -> void:
	if modal != null:
		modal.queue_free()
		modal = null
	bag_slots.clear()
	modal_open = false


func _panel(path: String, h_max: float) -> TextureRect:
	var vs: Vector2 = root.get_viewport_rect().size
	var tex: Texture2D = load(path) as Texture2D
	var ratio: float = tex.get_size().x / tex.get_size().y
	var h: float = minf(h_max, vs.y - 40.0)
	var p: TextureRect = UIKit.image(path, h * ratio, h)
	p.position = (vs - p.size) / 2.0
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(p)
	return p


func _hit(parent: Control, r: Array, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.flat = true
	for st: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UIKit.place(b, parent.size, r)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _popup_bag() -> void:
	var p: TextureRect = _panel("res://assets/ui/panel_tas.png", 560.0)
	var L: Dictionary = UIKit.layout["tas"] as Dictionary
	var cols: Array = L["kolom"] as Array
	var rows: Array = L["baris"] as Array
	for ri: int in range(5):
		for ci: int in range(5):
			var cr: Array = cols[ci] as Array
			var rr: Array = rows[ri] as Array
			bag_slots.append(_make_slot(p, p.size, [cr[0], rr[0], cr[1], rr[1]], 0))
	_hit(p, L["kiri"] as Array, func() -> void: _bag_turn(-1))
	_hit(p, L["kanan"] as Array, func() -> void: _bag_turn(1))
	_hit(p, L["x"] as Array, close_popup)
	bag_page_label = UIKit.pixel_label("", 16, UIKit.BROWN)
	UIKit.place(bag_page_label, p.size, L["halaman"] as Array)
	bag_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(bag_page_label)
	bag_dots = Control.new()
	bag_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_dots.size = p.size
	bag_dots.draw.connect(func() -> void:
		var r: float = float(L["titik_r"]) * p.size.x
		var c: Vector2 = Vector2((float(L["titik_x0"]) + float(L["titik_dx"]) * bag_page) * p.size.x, float(L["titik_y"]) * p.size.y)
		bag_dots.draw_circle(c, r + 1.5, Color("#43251D"))
		bag_dots.draw_circle(c, r, Color("#FFD65A")))
	p.add_child(bag_dots)
	_bag_show()


func _bag_turn(d: int) -> void:
	bag_page = (bag_page + d + Game.BAG_PAGES) % Game.BAG_PAGES
	_bag_show()


func _bag_show() -> void:
	for i: int in range(bag_slots.size()):
		bag_slots[i]["index"] = bag_page * Game.BAG_PER_PAGE + i
	bag_page_label.text = "%d / %d" % [bag_page + 1, Game.BAG_PAGES]
	bag_dots.queue_redraw()
	_refresh_items()


func _blank_panel(title: String) -> Array:
	var p: TextureRect = _panel("res://assets/ui/panel_kosong.png", 600.0)
	var P: Dictionary = UIKit.layout["pilih"] as Dictionary
	_hit(p, P["x"] as Array, close_popup)
	var isi: Array = P["isi"] as Array
	var inner: Control = Control.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(inner, p.size, isi)
	p.add_child(inner)
	var t: Label = UIKit.pixel_label("—  %s  —" % title, 30, UIKit.BROWN)
	t.position = Vector2(0, 14)
	t.size = Vector2(inner.size.x, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t)
	return [p, inner]


func _popup_map() -> void:
	var pi: Array = _blank_panel(str(world.get("map_title")))
	var inner: Control = pi[1] as Control
	var mid: String = str(world.get("map_id"))
	var img: TextureRect = UIKit.image("res://assets/lanskap/%s/peta_kecil.png" % mid, inner.size.x - 60.0, inner.size.y - 110.0)
	img.position = Vector2(30, 66)
	inner.add_child(img)
	var marker: Control = Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = img.size
	img.add_child(marker)
	var ws: Vector2 = Vector2(float(int(world.get("mw")) * 32), float(int(world.get("mh")) * 32))
	marker.draw.connect(func() -> void:
		var ts: Vector2 = img.texture.get_size()
		var sc: float = minf(img.size.x / ts.x, img.size.y / ts.y)
		var off: Vector2 = (img.size - ts * sc) / 2.0
		var pp: Vector2 = (world.get("player") as Node2D).position / ws * ts * sc + off
		marker.draw_circle(pp, 9.0, Color("#F8F1EA"))
		marker.draw_circle(pp, 6.0, Color("#D8574F")))
	var hint: Label = UIKit.pixel_label("You are here", 16, UIKit.BROWN)
	hint.position = Vector2(0, inner.size.y - 40)
	hint.size = Vector2(inner.size.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)


func _popup_book() -> void:
	var pi: Array = _blank_panel("Journal")
	var inner: Control = pi[1] as Control
	var lines: PackedStringArray = PackedStringArray([
		"%s  -  %s %d" % [Game.player_name, Game.season_name(), Game.date_in_season()],
		"Weather: %s" % ("Rainy" if Game.raining else "Clear"),
		"Wood collected: %d" % Game.count("kayu"),
		"",
		"Tips:",
		"- Walk west from the farm to reach the Woodland.",
		"- Tap a tree 3x to fell it, then chop the log & stump.",
		"- Fallen trees regrow somewhere else after a day."])
	var y: float = 70.0
	for ln: String in lines:
		var l: Label = UIKit.pixel_label(ln, 20, UIKit.BROWN)
		l.position = Vector2(46, y)
		l.size = Vector2(inner.size.x - 92, 30)
		inner.add_child(l)
		y += 32.0


func _popup_settings() -> void:
	var pi: Array = _blank_panel("Settings")
	var inner: Control = pi[1] as Control
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.position = Vector2(0, 70)
	col.size = Vector2(inner.size.x, inner.size.y - 130)
	inner.add_child(col)
	var items: Array = [["Resume", close_popup],
		["Zoom In", func() -> void: world.call("change_zoom", 1)],
		["Zoom Out", func() -> void: world.call("change_zoom", -1)],
		["Main Menu", func() -> void:
			close_popup()
			world.get_parent().call("back_to_title")]]
	for it: Array in items:
		var b: TextureButton = UIKit.pill_button(str(it[0]), 260.0)
		b.pressed.connect(it[1] as Callable)
		var wrap: CenterContainer = CenterContainer.new()
		wrap.custom_minimum_size = Vector2(inner.size.x, b.size.y)
		wrap.add_child(b)
		col.add_child(wrap)
	var v: Label = UIKit.pixel_label(UIKit.version(), 14, Color("#7F442C"))
	v.position = Vector2(0, inner.size.y - 36)
	v.size = Vector2(inner.size.x, 24)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(v)


# ---------------- lain-lain ----------------
func show_toast(t: String) -> void:
	toast.text = t
	if toast_tw != null:
		toast_tw.kill()
	toast.modulate.a = 1.0
	toast_tw = create_tween()
	toast_tw.tween_interval(1.5)
	toast_tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func _process(_delta: float) -> void:
	_refresh_status()
