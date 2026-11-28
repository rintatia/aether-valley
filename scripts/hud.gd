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
var btn_shop: TextureButton
var btn_build: TextureButton
var shop_season: String = ""
# Build mode
var build_panel: Control
var build_tab: String = "Buildings"
var build_page: int = 0
var build_hint: Label
var build_done: TextureButton
var sel_panel: Control
# Shop & Buku
var shop_tab: String = "Buildings"
var shop_page: int = 0
var shop_sel: String = ""
var book_tab: String = "Crops"
var book_page: int = 0
const BUILD_TABS: Array[String] = ["Buildings", "Houses", "Fences", "Decor", "Nature", "Animals"]
const SHOP_TABS: Array[String] = ["Buildings", "Houses", "Fences", "Decor", "Nature", "Seeds", "Animals", "Sell"]
const BOOK_TABS: Array[String] = ["Crops", "Seeds", "Animals", "Products", "Buildings", "Houses", "Fences", "Decor", "Nature", "Tools", "Recipes"]


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
	_build_build_ui()
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
	btn_shop.position = Vector2(lx - 4.0, btn_book.position.y + btn_book.size.y + 10.0)
	btn_build.position = Vector2(lx + (ICON_SET - btn_build.size.x) / 2.0, btn_shop.position.y + btn_shop.size.y + 10.0)
	if build_panel != null:
		build_panel.position = Vector2((vs.x - build_panel.size.x) / 2.0, vs.y - m.w - build_panel.size.y)
		build_hint.position = Vector2(0, m.y + 6.0)
		build_hint.size = Vector2(vs.x, 30)
		build_done.position = Vector2(vs.x - m.z - build_done.size.x, build_panel.position.y - build_done.size.y - 8.0)
		sel_panel.position = Vector2((vs.x - sel_panel.size.x) / 2.0, m.y + 40.0)
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
	var sn: String = Game.season_name().to_lower()
	if sn != shop_season and btn_shop != null:
		shop_season = sn
		btn_shop.texture_normal = load("res://assets/ui/toko_%s.png" % sn) as Texture2D
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
	# Shop: ikon kios berganti sesuai musim
	btn_shop = UIKit.icon_button("res://assets/ui/toko_%s.png" % Game.season_name().to_lower(), ICON_SET + 8.0)
	btn_shop.pressed.connect(func() -> void: open_popup("toko"))
	root.add_child(btn_shop)
	btn_build = UIKit.round_button("tombol_build", ICON_SET - 10.0)
	btn_build.pressed.connect(func() -> void: world.get("farm").call("set_build_mode", true))
	root.add_child(btn_build)


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
		"toko":
			_popup_shop()
	modal.modulate.a = 0.0
	var mtw: Tween = create_tween()
	mtw.tween_property(modal, "modulate:a", 1.0, 0.12)


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


# ================= umum: angka, tombol tab, harga =================
func fmt(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _tab_button(txt: String, on: bool, h: float, fs: int = 18) -> Button:
	var b: Button = _nav_button(txt, h)
	b.add_theme_font_size_override("font_size", fs)
	if on:
		b.add_theme_stylebox_override("normal", UIKit.box(Color("#7DBE5A"), Color("#2F6A32"), 4))
		b.add_theme_stylebox_override("hover", UIKit.box(Color("#7DBE5A"), Color("#2F6A32"), 4))
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, UIKit.CREAM)
	return b


## Ikon koin/kristal + angka.
func _price_row(it: Dictionary, fs: int, w: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size = Vector2(w, fs + 4)
	var kr: int = int(it.get("kristal", 0))
	var ic: TextureRect = UIKit.image("res://assets/ui/%s.png" % ("ikon_kristal" if kr > 0 else "ikon_koin"), fs * 0.9, fs * 0.9)
	row.add_child(ic)
	var l: Label = UIKit.pixel_label(fmt(kr if kr > 0 else int(it.get("harga", 0))), fs, UIKit.BROWN)
	row.add_child(l)
	return row


func _icon_rect(tex: Texture2D, sz: Vector2) -> TextureRect:
	var t: TextureRect = TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = sz
	return t


func _ids_in(cat: String) -> Array[String]:
	var out: Array[String] = []
	for k: String in Game.ITEMS.keys():
		if str((Game.ITEMS[k] as Dictionary).get("kategori", "")) == cat:
			out.append(k)
	if cat == "Nature":
		var order: Dictionary = {"Spring": 0, "Autumn": 1, "Winter": 2}
		out.sort_custom(func(a: String, b: String) -> bool:
			return int(order.get(str(Game.item(a).get("musim", "")), 3)) < int(order.get(str(Game.item(b).get("musim", "")), 3)))
	return out


# ================= Build mode =================
func _build_build_ui() -> void:
	build_panel = Control.new()
	build_panel.size = Vector2(980, 176)
	build_panel.visible = false
	root.add_child(build_panel)
	var bg: Panel = Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.box(Game.theme_color(), Color("#7F442C"), 4))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	build_panel.add_child(bg)
	build_hint = UIKit.pixel_label("Drag items onto your farm - drag placed items to move - tap one to store it", 22, UIKit.CREAM, 6, Color("#2B2730"))
	build_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_hint.visible = false
	root.add_child(build_hint)
	build_done = UIKit.pill_button("Done", 150.0)
	build_done.visible = false
	build_done.pressed.connect(func() -> void: world.get("farm").call("set_build_mode", false))
	root.add_child(build_done)
	sel_panel = Control.new()
	sel_panel.size = Vector2(460, 64)
	sel_panel.visible = false
	root.add_child(sel_panel)


func on_map_changed() -> void:
	if btn_build != null:
		btn_build.visible = str(world.get("map_id")) == "ladang"


func on_build_mode(on: bool) -> void:
	for c: Control in [bar, btn_map, btn_bag, btn_set, btn_book, btn_shop, btn_build]:
		c.visible = not on
	if not on:
		on_map_changed()
	build_panel.visible = on
	build_hint.visible = on
	build_done.visible = on
	sel_panel.visible = false
	if on:
		refresh_build_panel()
	_layout()


func over_build_panel(pos: Vector2) -> bool:
	return build_panel.visible and build_panel.get_global_rect().grow(6.0).has_point(pos)


## Barang yang bisa dipasang di tas untuk satu kategori: [[id, jumlah]].
func _owned(cat: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for sv: Variant in Game.bag:
		var d: Dictionary = sv as Dictionary
		if d.is_empty():
			continue
		var id: String = str(d["id"])
		if not Game.is_placeable(id) or str(Game.item(id).get("kategori", "")) != cat or seen.has(id):
			continue
		seen[id] = true
		out.append([id, Game.count(id)])
	return out


func refresh_build_panel() -> void:
	for c: Node in build_panel.get_children():
		if c.get_index() > 0:
			c.queue_free()
	var x: float = 14.0
	for t: String in BUILD_TABS:
		var tb: Button = _tab_button(t, t == build_tab, 38.0, 18)
		tb.size = Vector2(140, 38)
		tb.position = Vector2(x, 10)
		tb.pressed.connect(func() -> void:
			build_tab = t
			build_page = 0
			refresh_build_panel())
		build_panel.add_child(tb)
		x += 150.0
	var items: Array = _owned(build_tab)
	var per: int = 9
	var pages: int = maxi(1, int(ceil(items.size() / float(per))))
	build_page = clampi(build_page, 0, pages - 1)
	var y: float = 58.0
	var cs: float = 96.0
	var x0: float = (build_panel.size.x - (cs * per + 8.0 * (per - 1))) / 2.0
	if items.is_empty():
		var l: Label = UIKit.pixel_label("Nothing to place here - buy %s at the Shop" % build_tab.to_lower(), 22, UIKit.BROWN)
		l.position = Vector2(0, y + 30)
		l.size = Vector2(build_panel.size.x, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		build_panel.add_child(l)
	for i: int in range(per):
		var k: int = build_page * per + i
		if k >= items.size():
			break
		var id: String = str((items[k] as Array)[0])
		var n: int = int((items[k] as Array)[1])
		var b: Button = Button.new()
		b.add_theme_stylebox_override("normal", UIKit.box(Game.theme_color().darkened(0.09), Color("#B58A2A"), 3))
		b.add_theme_stylebox_override("hover", UIKit.box(Game.theme_color().darkened(0.09), Color("#B58A2A"), 3))
		b.add_theme_stylebox_override("pressed", UIKit.box(Color("#FFE9A8"), Color("#FFD65A"), 3))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.position = Vector2(x0 + i * (cs + 8.0), y)
		b.size = Vector2(cs, cs + 8.0)
		var ic: TextureRect = _icon_rect(Game.item_icon(id), Vector2(cs - 16.0, cs - 26.0))
		ic.position = Vector2(8, 6)
		b.add_child(ic)
		var nl: Label = UIKit.pixel_label("x%d" % n, 17, UIKit.CREAM, 4, Color("#43251D"))
		nl.position = Vector2(0, cs - 18.0)
		nl.size = Vector2(cs - 6.0, 22)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(nl)
		b.button_down.connect(func() -> void:
			UIKit.sfx("klik")
			world.get("farm").call("begin_new", id))
		build_panel.add_child(b)
	if pages > 1:
		var lb: Button = _nav_button("<", 34.0)
		lb.position = Vector2(build_panel.size.x - 110.0, 14)
		lb.pressed.connect(func() -> void:
			build_page = (build_page - 1 + pages) % pages
			refresh_build_panel())
		build_panel.add_child(lb)
		var rb: Button = _nav_button(">", 34.0)
		rb.position = Vector2(build_panel.size.x - 58.0, 14)
		rb.pressed.connect(func() -> void:
			build_page = (build_page + 1) % pages
			refresh_build_panel())
		build_panel.add_child(rb)


## Objek terpilih di Build mode: nama + Store (kembali ke tas).
func show_selected(e: Dictionary) -> void:
	for c: Node in sel_panel.get_children():
		c.queue_free()
	sel_panel.visible = not e.is_empty()
	if e.is_empty():
		return
	var bg: Panel = Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.box(Game.theme_color(), Color("#7F442C"), 4))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sel_panel.add_child(bg)
	var l: Label = UIKit.pixel_label(str(Game.item(str(e["id"]))["nama"]), 22, UIKit.BROWN)
	l.position = Vector2(16, 0)
	l.size = Vector2(240, 64)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	sel_panel.add_child(l)
	var st: TextureButton = UIKit.pill_button("Store", 130.0)
	st.position = Vector2(260, (64 - st.size.y) / 2.0)
	st.pressed.connect(func() -> void:
		world.get("farm").call("store", e)
		show_selected({})
		refresh_build_panel())
	sel_panel.add_child(st)
	var x: TextureButton = UIKit.round_button("tombol_x", 40.0)
	x.position = Vector2(406, 12)
	x.pressed.connect(func() -> void: show_selected({}))
	sel_panel.add_child(x)


# ================= Shop =================
func _popup_shop() -> void:
	var fr: Array = _frame("bingkai_15", 640.0, "Shop")
	var inner: Control = fr[1] as Control
	var tx: float = 20.0
	var tw: float = (inner.size.x - 40.0 - 6.0 * 7.0) / 8.0
	for t: String in SHOP_TABS:
		var tb: Button = _tab_button(t, t == shop_tab, 34.0, 17)
		tb.size = Vector2(tw, 34)
		tb.position = Vector2(tx, 50)
		tb.pressed.connect(func() -> void:
			shop_tab = t
			shop_page = 0
			shop_sel = ""
			_reopen("toko"))
		inner.add_child(tb)
		tx += tw + 6.0
	var ids: Array[String] = []
	if shop_tab == "Sell":
		for sv: Variant in Game.bag:
			var d: Dictionary = sv as Dictionary
			if not d.is_empty() and int(Game.item(str(d["id"])).get("jual", 0)) > 0 and not ids.has(str(d["id"])):
				ids.append(str(d["id"]))
	else:
		ids = _ids_in(shop_tab)
	var cols: int = 6
	var rows: int = 2
	var per: int = cols * rows
	var pages: int = maxi(1, int(ceil(ids.size() / float(per))))
	shop_page = clampi(shop_page, 0, pages - 1)
	var gx: float = 20.0
	var gy: float = 94.0
	var gap: float = 8.0
	var cw: float = (inner.size.x - 40.0 - gap * (cols - 1)) / cols
	var ch: float = (inner.size.y - gy - 104.0 - gap) / rows
	if ids.is_empty():
		var el: Label = UIKit.pixel_label("Nothing to sell yet - harvest crops and collect animal products", 22, UIKit.BROWN)
		el.position = Vector2(0, gy + 60)
		el.size = Vector2(inner.size.x, 30)
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(el)
	for i: int in range(per):
		var k: int = shop_page * per + i
		if k >= ids.size():
			break
		var id: String = ids[k]
		var it: Dictionary = Game.item(id)
		var b: Button = Button.new()
		var on: bool = id == shop_sel
		var bx: StyleBox = UIKit.box(Color("#FFE9A8") if on else Game.theme_color().darkened(0.07), Color("#FFD65A") if on else Color("#B58A2A"), 3)
		for st: String in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, bx)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.position = Vector2(gx + (i % cols) * (cw + gap), gy + (i / cols) * (ch + gap))
		b.size = Vector2(cw, ch)
		var ic: TextureRect = _icon_rect(Game.item_icon(id), Vector2(cw - 20.0, ch - 58.0))
		ic.position = Vector2(10, 6)
		b.add_child(ic)
		var nl: Label = UIKit.pixel_label(str(it["nama"]), 16, UIKit.BROWN)
		nl.position = Vector2(4, ch - 50.0)
		nl.size = Vector2(cw - 8.0, 22)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		b.add_child(nl)
		var pr: HBoxContainer
		if shop_tab == "Sell":
			pr = _price_row({"harga": int(it.get("jual", 0))}, 16, cw)
			var cnt: Label = UIKit.pixel_label("x%d" % Game.count(id), 16, UIKit.CREAM, 4, Color("#43251D"))
			cnt.position = Vector2(cw - 44.0, 4)
			cnt.size = Vector2(40, 20)
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			b.add_child(cnt)
		else:
			pr = _price_row(it, 16, cw)
		pr.position = Vector2(0, ch - 27.0)
		b.add_child(pr)
		if str(it.get("musim", "")) != "":
			var sl: Label = UIKit.pixel_label(str(it["musim"]), 14, UIKit.CREAM, 4, Color("#43251D"))
			sl.position = Vector2(6, 4)
			sl.size = Vector2(cw, 18)
			b.add_child(sl)
		b.pressed.connect(func() -> void:
			UIKit.sfx("klik")
			shop_sel = id
			_reopen("toko"))
		inner.add_child(b)
	# bawah: halaman + rincian + tombol Buy/Sell
	var by: float = inner.size.y - 98.0
	if pages > 1:
		var lb: Button = _nav_button("<", 36.0)
		lb.position = Vector2(20, by)
		lb.pressed.connect(func() -> void:
			shop_page = (shop_page - 1 + pages) % pages
			_reopen("toko"))
		inner.add_child(lb)
		var pl: Label = UIKit.pixel_label("%d / %d" % [shop_page + 1, pages], 20, UIKit.BROWN)
		pl.position = Vector2(70, by)
		pl.size = Vector2(80, 36)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inner.add_child(pl)
		var rb: Button = _nav_button(">", 36.0)
		rb.position = Vector2(152, by)
		rb.pressed.connect(func() -> void:
			shop_page = (shop_page + 1) % pages
			_reopen("toko"))
		inner.add_child(rb)
	if shop_sel != "" and Game.ITEMS.has(shop_sel):
		var it2: Dictionary = Game.item(shop_sel)
		var dl: Label = UIKit.pixel_label("%s - %s" % [str(it2["nama"]), str(it2.get("desk", ""))], 18, UIKit.BROWN)
		dl.position = Vector2(220, by - 4)
		dl.size = Vector2(inner.size.x - 440.0, 44)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inner.add_child(dl)
		var act: TextureButton = UIKit.pill_button("Sell" if shop_tab == "Sell" else "Buy", 180.0)
		act.position = Vector2(inner.size.x - 200.0, by - 6.0)
		act.pressed.connect(func() -> void:
			if shop_tab == "Sell":
				var got: int = Game.sell(shop_sel, 1)
				show_toast("Sold %s +%s" % [str(it2["nama"]), fmt(got)] if got > 0 else "Nothing to sell")
				if Game.count(shop_sel) <= 0:
					shop_sel = ""
			else:
				var err: String = Game.buy(shop_sel, 1)
				show_toast(err if err != "" else "Bought %s (you have %d)" % [str(it2["nama"]), Game.count(shop_sel)])
			_refresh_status(true)
			_reopen("toko"))
		inner.add_child(act)
	else:
		var hl: Label = UIKit.pixel_label("Tap an item to see it", 18, Color("#7F442C"))
		hl.position = Vector2(220, by)
		hl.size = Vector2(inner.size.x - 440.0, 36)
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inner.add_child(hl)
	var money: Label = UIKit.pixel_label("Coins %s   Crystals %s" % [fmt(Game.coins), fmt(Game.crystals)], 18, Color("#7F442C"))
	money.position = Vector2(0, inner.size.y - 40.0)
	money.size = Vector2(inner.size.x, 26)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(money)


# ================= Buku: ensiklopedia + resep =================
const TOOL_INFO: Dictionary = {
	"cangkul": "Till farm grass into soil for planting.", "penyiram": "Water tilled soil so crops grow each day.",
	"sekop": "Flatten tilled soil back into grass.", "arit": "Cut all plants around the target.",
	"pisau": "Cut a single plant.", "kapak": "Chop trees (Woodland) for Wood.", "beliung": "Break rocks for Stone.",
	"pedang": "Swing at things. Monsters coming soon.", "jaring": "Catch butterflies on sunny days.",
	"pancing": "Fishing at the Lake - coming soon.",
}


func _book_entries(tab: String) -> Array:
	var out: Array = []   # [ikon, nama, baris1, baris2]
	match tab:
		"Crops":
			for k: String in Game.tanaman.keys():
				var t: Dictionary = Game.tanaman[k] as Dictionary
				out.append([Game.item_icon(k), str(t["nama"]), "Get: grow %s Seeds on tilled soil, water daily (%d days)." % [str(t["nama"]), int(t["hari"])],
					"Where: your Farm. Sells for %s coins." % fmt(int(t["jual"]))])
		"Seeds":
			for k: String in _ids_in("Seeds"):
				var it: Dictionary = Game.item(k)
				out.append([Game.item_icon(k), str(it["nama"]), "Get: buy at the Shop for %s coins." % fmt(int(it["harga"])), "Where: sow on tilled soil on your Farm. " + str(it["desk"]).get_slice(".", 2).strip_edges()])
		"Animals":
			for k: String in _ids_in("Animals"):
				var it2: Dictionary = Game.item(k)
				out.append([Game.item_icon(k), str(it2["nama"]), str(it2["desk"]), "Get: Shop (%s coins). Where: place on your Farm in Build mode." % fmt(int(it2["harga"]))])
		"Products":
			for k: String in _ids_in("Animal Products"):
				var it3: Dictionary = Game.item(k)
				out.append([Game.item_icon(k), str(it3["nama"]), str(it3["desk"]), "Where: your Farm animals. Sells for %s coins." % fmt(int(it3.get("jual", 0)))])
		"Tools":
			for k: String in Game.START_TOOLS:
				out.append([Game.item_icon(k), str(Game.item(k)["nama"]), str(TOOL_INFO.get(k, "")), "Get: starter tool. Where: your Bag."])
			out.append([Game.item_icon("kayu"), "Wood", "Get: chop trees with the Axe.", "Where: the Woodland, west of the Farm."])
			out.append([Game.item_icon("batu"), "Stone", "Get: break rocks with the Pickaxe.", "Where: rocks around the Farm and Woodland."])
			out.append([Game.item_icon("kupu"), "Butterfly", "Get: catch with the Bug Net on sunny days.", "Where: everywhere, in daytime."])
		"Recipes":
			for rv: Variant in Game.resep:
				var r: Dictionary = rv as Dictionary
				var parts: PackedStringArray = PackedStringArray()
				for b: String in (r["bahan"] as Dictionary).keys():
					parts.append("%s x%d" % [str(Game.item(b).get("nama", b)), int((r["bahan"] as Dictionary)[b])])
				var ic: Texture2D = Game.item_icon(str(r["hasil"])) if r.has("hasil") else Game.item_icon(str((r["bahan"] as Dictionary).keys()[0]))
				out.append([ic, str(r["nama"]), "Needs: " + ", ".join(parts), str(r["desk"]) + ("" if r.has("hasil") else " (cooking coming soon)"), r])
		_:
			for k: String in _ids_in(tab):
				var it4: Dictionary = Game.item(k)
				var price: String = ("%s crystals" % fmt(int(it4["kristal"]))) if int(it4.get("kristal", 0)) > 0 else ("%s coins" % fmt(int(it4.get("harga", 0))))
				out.append([Game.item_icon(k), str(it4["nama"]), str(it4.get("desk", "")), "Get: Shop (%s). Where: place on your Farm in Build mode." % price])
	return out


func _popup_book() -> void:
	var fr: Array = _frame("bingkai_21", 600.0, "Journal")
	var inner: Control = fr[1] as Control
	var ty: float = 52.0
	var th: float = (inner.size.y - ty - 14.0) / BOOK_TABS.size() - 4.0
	for t: String in BOOK_TABS:
		var tb: Button = _tab_button(t, t == book_tab, th, 17)
		tb.size = Vector2(150, th)
		tb.position = Vector2(22, ty)
		tb.pressed.connect(func() -> void:
			book_tab = t
			book_page = 0
			_reopen("buku"))
		inner.add_child(tb)
		ty += th + 4.0
	var ents: Array = _book_entries(book_tab)
	var per: int = 5
	var pages: int = maxi(1, int(ceil(ents.size() / float(per))))
	book_page = clampi(book_page, 0, pages - 1)
	var lx: float = 190.0
	var lw: float = inner.size.x - lx - 24.0
	var rh: float = (inner.size.y - 52.0 - 50.0) / per
	for i: int in range(per):
		var k: int = book_page * per + i
		if k >= ents.size():
			break
		var e: Array = ents[k] as Array
		var y: float = 52.0 + i * rh
		var bg: Panel = Panel.new()
		bg.add_theme_stylebox_override("panel", UIKit.box(Game.theme_color().darkened(0.06), Color("#D9B88A"), 2))
		bg.position = Vector2(lx, y)
		bg.size = Vector2(lw, rh - 6.0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(bg)
		var ic: TextureRect = _icon_rect(e[0] as Texture2D, Vector2(rh - 18.0, rh - 18.0))
		ic.position = Vector2(lx + 6.0, y + 6.0)
		inner.add_child(ic)
		var tx: float = lx + rh
		var nl: Label = UIKit.pixel_label(str(e[1]), 21, UIKit.BROWN)
		nl.position = Vector2(tx, y + 2.0)
		nl.size = Vector2(lw - rh - 10.0, 24)
		inner.add_child(nl)
		for j: int in range(2):
			var dl: Label = UIKit.pixel_label(str(e[2 + j]), 16, Color("#6B4A2E"))
			dl.position = Vector2(tx, y + 25.0 + j * 18.0)
			dl.size = Vector2(lw - rh - 120.0, 20)
			dl.clip_text = true
			inner.add_child(dl)
		if e.size() > 4:
			var r: Dictionary = e[4] as Dictionary
			if r.has("hasil"):
				var cb: Button = _tab_button("Cook", Game.can_cook(r), 32.0, 17)
				cb.size = Vector2(96, 32)
				cb.position = Vector2(lx + lw - 106.0, y + (rh - 38.0) / 2.0)
				cb.pressed.connect(func() -> void:
					if Game.cook(r):
						show_toast("Made %s!" % str(r["nama"]))
						_reopen("buku")
					else:
						show_toast("Not enough ingredients"))
				inner.add_child(cb)
	var nav_y: float = inner.size.y - 44.0
	if pages > 1:
		var lb: Button = _nav_button("<", 34.0)
		lb.position = Vector2(lx + lw / 2.0 - 110.0, nav_y)
		lb.pressed.connect(func() -> void:
			book_page = (book_page - 1 + pages) % pages
			_reopen("buku"))
		inner.add_child(lb)
		var rb: Button = _nav_button(">", 34.0)
		rb.position = Vector2(lx + lw / 2.0 + 70.0, nav_y)
		rb.pressed.connect(func() -> void:
			book_page = (book_page + 1) % pages
			_reopen("buku"))
		inner.add_child(rb)
	var pl: Label = UIKit.pixel_label("%s  %d / %d" % [book_tab, book_page + 1, pages], 18, UIKit.BROWN)
	pl.position = Vector2(lx + lw / 2.0 - 65.0, nav_y)
	pl.size = Vector2(130, 34)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(pl)


## Buka ulang popup tanpa animasi muncul (dipakai saat isi popup diperbarui).
func _reopen(kind: String) -> void:
	open_popup(kind)
	modal.modulate.a = 1.0
