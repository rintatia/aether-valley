extends CanvasLayer
## HUD permainan: status bar (siang/malam), setting + buku (kiri atas), shortcut bar + peta + tas (bawah),
## popup tas (5x5, 10 halaman), peta, buku, setting. Semua tombol bisa ditekan.

const STATUS_W: float = 430.0
const BAR_W: float = 500.0
const ICON_SET: float = 60.0
const ICON_BIG: float = 72.0

var world: Node2D
var root: Control
var status: Control
var st_day: TextureRect
var st_night: TextureRect
var lb_date: Label
var lb_clock: Label
var lb_coin: Label
var lb_crystal: Label
var badge: TextureRect
var badge_now: String = ""
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
	btn_book.position = Vector2(m.x, m.y + btn_set.size.y + 8.0)
	var total: float = btn_map.size.x + 8.0 + BAR_W + 8.0 + btn_bag.size.x
	var x0: float = (vs.x - total) / 2.0
	var bar_h: float = bar.size.y
	var y_bar: float = vs.y - m.w - bar_h
	btn_map.position = Vector2(x0, y_bar + (bar_h - btn_map.size.y) / 2.0)
	bar.position = Vector2(x0 + btn_map.size.x + 8.0, y_bar)
	btn_bag.position = Vector2(bar.position.x + BAR_W + 8.0, y_bar + (bar_h - btn_bag.size.y) / 2.0)
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
	# tanggal & jam: di tengah ruang kosong setelah ikon; koin & kristal: rata kiri setelah ikon
	lb_date = _field_label(L["tanggal"] as Array, sz, 20, HORIZONTAL_ALIGNMENT_CENTER)
	lb_clock = _field_label(L["jam"] as Array, sz, 24, HORIZONTAL_ALIGNMENT_CENTER)
	lb_coin = _field_label(L["koin"] as Array, sz, 20, HORIZONTAL_ALIGNMENT_LEFT)
	lb_crystal = _field_label(L["kristal"] as Array, sz, 20, HORIZONTAL_ALIGNMENT_LEFT)
	lb_coin.add_theme_color_override("font_color", Color("#FFEE9A"))
	lb_crystal.add_theme_color_override("font_color", Color("#C9BFFA"))
	# lencana musim / hujan di perisai (gambar, tanpa tulisan)
	badge = TextureRect.new()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.place(badge, sz, L["lencana"] as Array)
	status.add_child(badge)


func _field_label(r: Array, sz: Vector2, fs: int, align: HorizontalAlignment) -> Label:
	var l: Label = UIKit.pixel_label("", fs, UIKit.BROWN)
	UIKit.place(l, sz, r)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = align
	l.clip_text = true
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
	var key: String = Game.status_text().to_lower()
	if key != badge_now:
		badge_now = key
		badge.texture = load("res://assets/ui/lencana_%s.png" % key) as Texture2D


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
	var n: Label = UIKit.pixel_label("", 13, UIKit.CREAM, 4, Color("#43251D"))
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


## Bingkai popup di tengah layar + judul + tombol X. Hasil: [panel, area isi].
func _frame(name: String, h_max: float, title: String) -> Array:
	var vs: Vector2 = root.get_viewport_rect().size
	var fr: Array = UIKit.frame(name, minf(h_max, vs.y - 40.0), vs.x - 60.0)
	var p: TextureRect = fr[0] as TextureRect
	var inner: Control = fr[1] as Control
	p.position = ((vs - p.size) / 2.0).round()
	modal.add_child(p)
	UIKit.frame_title(inner, title, 32)
	UIKit.close_button(p, inner).pressed.connect(close_popup)
	return fr


func _blank_panel(title: String) -> Array:
	return _frame("bingkai_15", 600.0, title)


func _nav_button(txt: String, d: float) -> Button:
	var b: Button = Button.new()
	b.text = txt
	b.add_theme_font_override("font", UIKit.font)
	b.add_theme_font_size_override("font_size", int(d * 0.55))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UIKit.BROWN)
	b.add_theme_stylebox_override("normal", UIKit.box(Color("#FEC473"), Color("#7F442C"), 4, 10))
	b.add_theme_stylebox_override("hover", UIKit.box(Color("#FFD65A"), Color("#7F442C"), 4, 10))
	b.add_theme_stylebox_override("pressed", UIKit.box(Color("#DE9A4C"), Color("#7F442C"), 4, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st: String in ["normal", "hover", "pressed"]:
		(b.get_theme_stylebox(st) as StyleBoxFlat).set_content_margin_all(0)
	b.size = Vector2(d * 1.2, d)
	return b


func _popup_bag() -> void:
	var fr: Array = _frame("bingkai_11", 640.0, "Bag")
	var inner: Control = fr[1] as Control
	var top: float = 54.0
	var nav_h: float = 40.0
	var dots_h: float = 18.0
	var avail: float = minf(inner.size.x - 40.0, inner.size.y - top - nav_h - dots_h - 22.0)
	var gap: float = avail * 0.025
	var cell: float = (avail - gap * 4.0) / 5.0
	var gx: float = (inner.size.x - (cell * 5.0 + gap * 4.0)) / 2.0
	var slot_bg: StyleBoxFlat = UIKit.box(Color("#EBCFA8"), Color("#B58A2A"), 3, 8)
	for ri: int in range(5):
		for ci: int in range(5):
			var x: float = gx + ci * (cell + gap)
			var y: float = top + ri * (cell + gap)
			var bgp: Panel = Panel.new()
			bgp.add_theme_stylebox_override("panel", slot_bg)
			bgp.position = Vector2(x, y)
			bgp.size = Vector2(cell, cell)
			bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(bgp)
			var r: Array = [x / inner.size.x, y / inner.size.y, (x + cell) / inner.size.x, (y + cell) / inner.size.y]
			bag_slots.append(_make_slot(inner, inner.size, r, 0))
	var grid_end: float = top + cell * 5.0 + gap * 4.0
	bag_dots = Control.new()
	bag_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_dots.position = Vector2(0, grid_end + 8.0)
	bag_dots.size = Vector2(inner.size.x, dots_h)
	bag_dots.draw.connect(func() -> void:
		var step: float = 20.0
		var x0: float = (inner.size.x - step * (Game.BAG_PAGES - 1)) / 2.0
		for k: int in range(Game.BAG_PAGES):
			var c: Vector2 = Vector2(x0 + step * k, dots_h / 2.0)
			bag_dots.draw_circle(c, 6.0, Color("#43251D"))
			bag_dots.draw_circle(c, 4.5, Color("#FFD65A") if k == bag_page else Color("#F8F1EA")))
	inner.add_child(bag_dots)
	var ny: float = grid_end + 8.0 + dots_h + 6.0
	var lb: Button = _nav_button("<", nav_h)
	lb.position = Vector2(gx, ny)
	lb.pressed.connect(func() -> void: _bag_turn(-1))
	inner.add_child(lb)
	var rb: Button = _nav_button(">", nav_h)
	rb.position = Vector2(inner.size.x - gx - rb.size.x, ny)
	rb.pressed.connect(func() -> void: _bag_turn(1))
	inner.add_child(rb)
	bag_page_label = UIKit.pixel_label("", 22, UIKit.BROWN)
	bag_page_label.position = Vector2(0, ny)
	bag_page_label.size = Vector2(inner.size.x, nav_h)
	bag_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(bag_page_label)
	_bag_show()


func _bag_turn(d: int) -> void:
	bag_page = (bag_page + d + Game.BAG_PAGES) % Game.BAG_PAGES
	_bag_show()


func _bag_show() -> void:
	for i: int in range(bag_slots.size()):
		bag_slots[i]["index"] = bag_page * Game.BAG_PER_PAGE + i
	bag_page_label.text = "Page %d / %d" % [bag_page + 1, Game.BAG_PAGES]
	bag_dots.queue_redraw()
	_refresh_items()


func _popup_map() -> void:
	var pi: Array = _blank_panel(str(world.get("map_title")))
	var inner: Control = pi[1] as Control
	var mid: String = str(world.get("map_id"))
	var img: TextureRect = UIKit.image("res://assets/lanskap/%s/peta_kecil.png" % mid, inner.size.x - 60.0, inner.size.y - 100.0)
	img.position = Vector2(30, 56)
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
	var hint: Label = UIKit.pixel_label("You are here", 20, UIKit.BROWN)
	hint.position = Vector2(0, inner.size.y - 38)
	hint.size = Vector2(inner.size.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(hint)


func _popup_book() -> void:
	var pi: Array = _frame("bingkai_21", 560.0, "Journal")
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
	var y: float = 58.0
	for ln: String in lines:
		var l: Label = UIKit.pixel_label(ln, 22, UIKit.BROWN)
		l.position = Vector2(40, y)
		l.size = Vector2(inner.size.x - 80, 30)
		inner.add_child(l)
		y += 34.0


func _popup_settings() -> void:
	var pi: Array = _blank_panel("Settings")
	var inner: Control = pi[1] as Control
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.position = Vector2(0, 56)
	col.size = Vector2(inner.size.x, inner.size.y - 100)
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
	var v: Label = UIKit.pixel_label(UIKit.version(), 18, Color("#7F442C"))
	v.position = Vector2(0, inner.size.y - 32)
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
