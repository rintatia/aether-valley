extends CanvasLayer
## HUD permainan: status bar (siang/malam), setting + buku (kiri atas), shortcut bar + peta + tas (bawah),
## popup tas (5x5, 10 halaman), peta, buku, setting. Semua tombol bisa ditekan.

const STATUS_W: float = 430.0
const BAR_W: float = 780.0     # shortcut 15 slot
const ICON_SET: float = 70.0
const ICON_BIG: float = 76.0

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
var bag_title: Label             # nama + jumlah barang terpilih (pengganti tulisan "Bag")
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
	# setting & buku: hampir mepet kiri (tetap di luar poni/lengkung layar), sedikit turun
	var lx: float = maxf(14.0, m.x - 30.0)
	btn_set.position = Vector2(lx, m.y + 18.0)
	btn_book.position = Vector2(lx, btn_set.position.y + btn_set.size.y + 12.0)
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
	# tanggal & jam: di tengah ruang kosong setelah ikon; koin & kristal: rata kanan
	lb_date = _field_label(L["tanggal"] as Array, sz, 20, HORIZONTAL_ALIGNMENT_CENTER)
	lb_clock = _field_label(L["jam"] as Array, sz, 24, HORIZONTAL_ALIGNMENT_CENTER)
	lb_coin = _field_label(L["koin"] as Array, sz, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	lb_crystal = _field_label(L["kristal"] as Array, sz, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	lb_coin.add_theme_color_override("font_color", Color("#FFEE9A"))
	lb_crystal.add_theme_color_override("font_color", Color("#C9BFFA"))
	# lencana musim / hujan di perisai (gambar, tanpa tulisan)
	badge = TextureRect.new()
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var i: int = 0
	for rv: Variant in L["slot"] as Array:
		slot_nodes.append(_make_slot(bar, bar.size, rv as Array, i))
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
	hl.add_theme_stylebox_override("panel", UIKit.box(Color(1, 0.93, 0.6, 0.22), Color("#FFD65A"), 2))
	hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.visible = false
	b.add_child(hl)
	var ic: TextureRect = TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 4
	ic.offset_top = 4
	ic.offset_right = -4
	ic.offset_bottom = -4
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var n: Label = UIKit.pixel_label("", 16, UIKit.CREAM, 4, Color("#43251D"))
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
	UIKit.sfx("klik")
	# memilih barang tidak memunculkan nama di layar; nama + jumlah hanya tampil di judul Bag
	Game.selected_slot = -1 if Game.selected_slot == idx else idx
	_refresh_items()


## Judul popup Bag = nama barang terpilih (+ jumlah). Kosong bila belum ada yang dipilih.
func _bag_title_text() -> String:
	var idx: int = Game.selected_slot
	if idx < 0 or idx >= Game.bag.size() or (Game.bag[idx] as Dictionary).is_empty():
		return ""
	var it: Dictionary = Game.bag[idx] as Dictionary
	var nm: String = str((Game.ITEMS[str(it["id"])] as Dictionary)["nama"])
	return nm if int(it["n"]) <= 1 else "%s  x%d" % [nm, int(it["n"])]


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
	if bag_title != null and is_instance_valid(bag_title):
		bag_title.text = _bag_title_text()


# ---------------- popup ----------------
func open_popup(kind: String) -> void:
	close_popup()
	modal_open = true
	modal = Control.new()
	modal.size = root.get_viewport_rect().size
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	root.move_child(modal, fade.get_index())
	root.move_child(toast, fade.get_index())   # pesan singkat tetap terlihat di atas popup
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
	b.size = Vector2(d * 1.2, d)
	b.button_down.connect(func() -> void: UIKit.sfx("klik"))
	return b


func _popup_bag() -> void:
	var fr: Array = _frame("bingkai_11", 640.0, "")
	var inner: Control = fr[1] as Control
	bag_title = inner.get_child(0) as Label
	var top: float = 60.0
	var nav_h: float = 40.0
	var dots_h: float = 16.0
	var side: float = 14.0
	var gap: float = 8.0
	# kotak mengisi seluruh area isi bingkai (lebar & tinggi), tanpa sisa ruang kosong
	var cw: float = (inner.size.x - side * 2.0 - gap * 4.0) / 5.0
	var chh: float = (inner.size.y - top - nav_h - dots_h - 22.0 - gap * 4.0) / 5.0
	var gx: float = side
	var slot_bg: StyleBox = UIKit.box(Game.theme_color().darkened(0.09), Color("#B58A2A"), 3, 8)
	for ri: int in range(5):
		for ci: int in range(5):
			var x: float = gx + ci * (cw + gap)
			var y: float = top + ri * (chh + gap)
			var bgp: Panel = Panel.new()
			bgp.add_theme_stylebox_override("panel", slot_bg)
			bgp.position = Vector2(x, y)
			bgp.size = Vector2(cw, chh)
			bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(bgp)
			var r: Array = [x / inner.size.x, y / inner.size.y, (x + cw) / inner.size.x, (y + chh) / inner.size.y]
			bag_slots.append(_make_slot(inner, inner.size, r, 0))
	var grid_end: float = top + chh * 5.0 + gap * 4.0
	bag_dots = Control.new()
	bag_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_dots.position = Vector2(0, grid_end + 6.0)
	bag_dots.size = Vector2(inner.size.x, dots_h)
	bag_dots.draw.connect(func() -> void:
		var step: float = 20.0
		var x0: float = (inner.size.x - step * (Game.BAG_PAGES - 1)) / 2.0
		for k: int in range(Game.BAG_PAGES):
			var c: Vector2 = Vector2(x0 + step * k, dots_h / 2.0)
			bag_dots.draw_circle(c, 6.0, Color("#43251D"))
			bag_dots.draw_circle(c, 4.5, Color("#FFD65A") if k == bag_page else Color("#F8F1EA")))
	inner.add_child(bag_dots)
	var ny: float = grid_end + 6.0 + dots_h + 6.0
	# navigasi di tengah, simetris: <  Page 1 / 10  >
	var lw: float = 190.0
	bag_page_label = UIKit.pixel_label("", 22, UIKit.BROWN)
	bag_page_label.position = Vector2((inner.size.x - lw) / 2.0, ny)
	bag_page_label.size = Vector2(lw, nav_h)
	bag_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bag_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(bag_page_label)
	var lb: Button = _nav_button("<", nav_h)
	lb.position = Vector2(bag_page_label.position.x - lb.size.x - 10.0, ny)
	lb.pressed.connect(func() -> void: _bag_turn(-1))
	inner.add_child(lb)
	var rb: Button = _nav_button(">", nav_h)
	rb.position = Vector2(bag_page_label.position.x + lw + 10.0, ny)
	rb.pressed.connect(func() -> void: _bag_turn(1))
	inner.add_child(rb)
	# tombol hapus (tempat sampah) di kiri atas = cermin tombol X di kanan atas
	# tombol hapus (pixel art) di kiri atas, cermin tombol X; agak ke dalam agar tidak menutupi hiasan bingkai
	var tb: TextureButton = UIKit.round_button("tombol_sampah", 46.0)
	tb.position = Vector2(UIKit.corner_inset(fr[0] as Control), 10.0)
	tb.pressed.connect(_bag_ask_delete)
	inner.add_child(tb)
	_bag_show()


## Hapus barang di slot terpilih: minta konfirmasi dulu.
func _bag_ask_delete() -> void:
	var idx: int = Game.selected_slot
	if idx < 0 or (Game.bag[idx] as Dictionary).is_empty():
		show_toast("Select an item first")
		return
	var it: Dictionary = Game.bag[idx] as Dictionary
	var nm: String = str((Game.ITEMS[str(it["id"])] as Dictionary)["nama"])
	var cover: ColorRect = ColorRect.new()
	cover.color = Color(0.08, 0.06, 0.05, 0.45)
	cover.size = modal.size
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(cover)
	var fr: Array = UIKit.frame("bingkai_21", 250.0)
	var p: TextureRect = fr[0] as TextureRect
	var inner: Control = fr[1] as Control
	p.position = ((modal.size - p.size) / 2.0).round()
	cover.add_child(p)
	var q: Label = UIKit.pixel_label("Delete %s%s?" % [nm, (" x%d" % int(it["n"])) if int(it["n"]) > 1 else ""], 26, UIKit.BROWN)
	q.position = Vector2(0, 18)
	q.size = Vector2(inner.size.x, 40)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(q)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.position = Vector2(0, inner.size.y - 74)
	row.size = Vector2(inner.size.x, 60)
	inner.add_child(row)
	var yes: TextureButton = UIKit.pill_button("Delete", 190.0)
	yes.pressed.connect(func() -> void:
		bag_delete(idx)
		cover.queue_free())
	row.add_child(yes)
	var no: TextureButton = UIKit.pill_button("Cancel", 190.0)
	no.pressed.connect(cover.queue_free)
	row.add_child(no)


func bag_delete(idx: int) -> void:
	var it: Dictionary = Game.bag[idx] as Dictionary
	if it.is_empty():
		return
	var nm: String = str((Game.ITEMS[str(it["id"])] as Dictionary)["nama"])
	Game.bag[idx] = {}
	Game.bag_changed.emit()
	show_toast("%s deleted" % nm)


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
	var lx: float = 60.0
	var cx: float = inner.size.x * 0.40
	var cw: float = inner.size.x - cx - 60.0
	var rh: float = 46.0
	var y: float = 70.0
	# --- Volume: [-] batang [+] persen
	_setting_label(inner, "Volume", lx, y, rh)
	var minus: Button = _nav_button("-", rh)
	minus.position = Vector2(cx, y)
	inner.add_child(minus)
	var plus: Button = _nav_button("+", rh)
	plus.position = Vector2(cx + cw - plus.size.x, y)
	inner.add_child(plus)
	var bar_bg: Panel = Panel.new()
	bar_bg.add_theme_stylebox_override("panel", UIKit.box(Color("#43251D"), Color("#7F442C"), 3, 8))
	bar_bg.position = Vector2(cx + minus.size.x + 14.0, y + 9.0)
	bar_bg.size = Vector2(cw - minus.size.x * 2.0 - 28.0, rh - 18.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bar_bg)
	var fill: Panel = Panel.new()
	fill.add_theme_stylebox_override("panel", UIKit.box(Color("#FFD65A"), Color("#FFD65A"), 0, 5))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(4, 4)
	bar_bg.add_child(fill)
	var pct: Label = UIKit.pixel_label("", 22, UIKit.CREAM, 6, Color("#43251D"))
	pct.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_bg.add_child(pct)
	var show_vol: Callable = func() -> void:
		fill.size = Vector2((bar_bg.size.x - 8.0) * Game.volume, bar_bg.size.y - 8.0)
		fill.visible = Game.volume > 0.0
		pct.text = "%d%%" % roundi(Game.volume * 100.0)
	show_vol.call()
	minus.pressed.connect(func() -> void:
		Game.set_volume(Game.volume - 0.1)
		show_vol.call())
	plus.pressed.connect(func() -> void:
		Game.set_volume(Game.volume + 0.1)
		show_vol.call())
	# --- Walk Speed: Slow / Normal / Fast
	y += rh + 26.0
	_setting_label(inner, "Walk Speed", lx, y, rh)
	var bw: float = (cw - 20.0) / 3.0
	var i: int = 0
	for sp: String in ["Slow", "Normal", "Fast"]:
		var b2: Button = _nav_button(sp, rh)
		b2.add_theme_font_size_override("font_size", 20)
		b2.size = Vector2(bw, rh)
		b2.position = Vector2(cx + i * (bw + 10.0), y)
		if sp == Game.speed_name:
			b2.add_theme_stylebox_override("normal", UIKit.box(Color("#7DBE5A"), Color("#2F6A32"), 4, 10))
			b2.add_theme_color_override("font_color", UIKit.CREAM)
		b2.pressed.connect(func() -> void:
			Game.speed_name = sp
			Game.save_settings()
			open_popup("setting"))
		inner.add_child(b2)
		i += 1
	# --- Theme: [<] contoh warna + nama [>]
	y += rh + 26.0
	_setting_label(inner, "Theme", lx, y, rh)
	var names: Array = Game.THEMES.keys()
	var prev: Button = _nav_button("<", rh)
	prev.position = Vector2(cx, y)
	inner.add_child(prev)
	var next: Button = _nav_button(">", rh)
	next.position = Vector2(cx + cw - next.size.x, y)
	inner.add_child(next)
	var sw: Panel = Panel.new()
	sw.add_theme_stylebox_override("panel", UIKit.box(Game.theme_color(), Color("#7F442C"), 3, 8))
	sw.position = Vector2(cx + prev.size.x + 14.0, y + 4.0)
	sw.size = Vector2(cw - prev.size.x * 2.0 - 28.0, rh - 8.0)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sw)
	var tn: Label = UIKit.pixel_label(Game.theme_name, 22, UIKit.BROWN)
	tn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sw.add_child(tn)
	for pair: Array in [[prev, -1], [next, 1]]:
		var d: int = int(pair[1])
		(pair[0] as Button).pressed.connect(func() -> void:
			var k: int = names.find(Game.theme_name)
			Game.theme_name = str(names[(k + d + names.size()) % names.size()])
			Game.save_settings()
			open_popup("setting"))
	# --- Resume / Main Menu
	y += rh + 34.0
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.position = Vector2(0, y)
	row.size = Vector2(inner.size.x, 64)
	inner.add_child(row)
	var res: TextureButton = UIKit.pill_button("Resume", 240.0)
	res.pressed.connect(close_popup)
	row.add_child(res)
	var mm: TextureButton = UIKit.pill_button("Main Menu", 240.0)
	mm.pressed.connect(func() -> void:
		close_popup()
		world.get_parent().call("back_to_title"))
	row.add_child(mm)
	var v: Label = UIKit.pixel_label(UIKit.version(), 18, Color("#7F442C"))
	v.position = Vector2(0, inner.size.y - 32)
	v.size = Vector2(inner.size.x, 24)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(v)


func _setting_label(inner: Control, text: String, x: float, y: float, h: float) -> void:
	var l: Label = UIKit.pixel_label(text, 24, UIKit.BROWN)
	l.position = Vector2(x, y)
	l.size = Vector2(inner.size.x * 0.4 - x, h)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(l)


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
