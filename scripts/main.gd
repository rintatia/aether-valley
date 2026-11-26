extends Node
## Alur layar: login -> karakter & lahan -> dunia. Juga mode --selftest untuk CI.

const UI = preload("res://scripts/ui.gd")
const WorldScript = preload("res://scripts/world.gd")

var layer: CanvasLayer
var root: Control
var world: Node2D
var sel_color: int = 0
var sel_farm: String = "padang"


func _ready() -> void:
	if "--selftest" in OS.get_cmdline_user_args():
		await _selftest()
		return
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	root = Control.new()
	root.theme = UI.make_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	show_login()


func _clear() -> void:
	for c: Node in root.get_children():
		c.queue_free()
	var bg: TextureRect = TextureRect.new()
	bg.texture = load("res://assets/farm_map.png") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.55, 0.6, 0.6)
	root.add_child(bg)


func _panel(w: float, h: float) -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	UI.center(p, w, h)
	root.add_child(p)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func show_login() -> void:
	_clear()
	var v: VBoxContainer = _panel(640, 470)
	var t: Label = UI.label("Aether Valley", 54, Color("#FFD65A"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub: Label = UI.label("Lembah kecil, hidup yang tenang", 24, Color("#C4EBF7"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var email: LineEdit = LineEdit.new()
	email.placeholder_text = "Email (untuk sinkron online, menyusul)"
	email.custom_minimum_size = Vector2(0, 56)
	v.add_child(email)
	if Game.has_save():
		var cont: Button = UI.button("Lanjutkan", 0, 64)
		cont.pressed.connect(func() -> void:
			if Game.load_game():
				start_world())
		v.add_child(cont)
	var nw: Button = UI.button("Main Baru", 0, 64)
	nw.pressed.connect(show_create)
	v.add_child(nw)
	var note: Label = UI.label("Mode offline: progres tersimpan di perangkat ini. Login online (kode email) akan ditambahkan.", 20, Color("#B5B0A6"))
	v.add_child(note)


func show_create() -> void:
	_clear()
	var v: VBoxContainer = _panel(900, 560)
	v.add_child(UI.label("Buat Petani & Pilih Lahan", 36, Color("#FFD65A")))
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = "Petani"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(0, 56)
	v.add_child(name_edit)
	v.add_child(UI.label("Warna baju", 22))
	var cr: HBoxContainer = HBoxContainer.new()
	cr.add_theme_constant_override("separation", 10)
	v.add_child(cr)
	var color_btns: Array[Button] = []
	for i: int in range(Game.OUTFITS.size()):
		var b: Button = UI.button("", 64, 64)
		b.add_theme_stylebox_override("normal", UI.box(Color(Game.OUTFITS[i]), Color("#F8F1EA"), 3))
		b.add_theme_stylebox_override("hover", UI.box(Color(Game.OUTFITS[i]), Color("#FFD65A"), 3))
		b.add_theme_stylebox_override("pressed", UI.box(Color(Game.OUTFITS[i]), Color("#FFD65A"), 3))
		var idx: int = i
		b.pressed.connect(func() -> void:
			sel_color = idx
			for j: int in range(color_btns.size()):
				color_btns[j].text = "v" if j == idx else "")
		color_btns.append(b)
		cr.add_child(b)
	color_btns[0].text = "v"
	v.add_child(UI.label("Jenis lahan", 22))
	var farms: Array = [
		["padang", "Padang Subur  (+6 benih wortel)"],
		["hutan", "Hutan Tenang  (+150 emas awal)"],
		["sungai", "Tepi Sungai  (stamina 130)"],
	]
	var fb: Array[Button] = []
	for f: Array in farms:
		var b: Button = UI.button(str(f[1]), 0, 56)
		var fid: String = str(f[0])
		b.pressed.connect(func() -> void:
			sel_farm = fid
			for x: Button in fb:
				x.modulate = Color.WHITE
			b.modulate = Color("#FFEE9A"))
		fb.append(b)
		v.add_child(b)
	fb[0].modulate = Color("#FFEE9A")
	var go: Button = UI.button("Mulai", 0, 68)
	go.pressed.connect(func() -> void:
		var nm: String = name_edit.text.strip_edges()
		if nm == "":
			nm = "Petani"
		Game.new_game(nm, sel_color, sel_farm)
		start_world())
	v.add_child(go)


func start_world() -> void:
	for c: Node in root.get_children():
		c.queue_free()
	world = WorldScript.new()
	add_child(world)
	layer.visible = false


# ---------------- selftest (CI, headless) ----------------
var _fails: int = 0


func _check(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		_fails += 1


func _selftest() -> void:
	Game.new_game("Tes", 0, "padang")
	world = WorldScript.new()
	add_child(world)
	await get_tree().process_frame
	var fm: Dictionary = world.meta["farm"] as Dictionary
	_check(world.map_name == "farm" and world.mw == 1024 and world.mh == 1024, "peta ladang dimuat 1024x1024")
	var sp: Array = fm["spawn"] as Array
	var ge: Array = fm["gate_east"] as Array
	var gate_mid: Vector2 = Vector2(float(ge[0]) + 4.0, (float(ge[1]) + float(ge[3])) / 2.0)
	var p1: PackedVector2Array = world.find_path(world.player.position, gate_mid)
	_check(p1.size() > 5, "jalur spawn -> gerbang timur (%d titik)" % p1.size())
	var hd: Array = fm["house_door"] as Array
	var p2: PackedVector2Array = world.find_path(world.player.position, Vector2(float(hd[0]), float(hd[1]) + 8.0))
	_check(p2.size() > 3, "jalur spawn -> pintu rumah")
	var o: Array = fm["plot_origin"] as Array
	var free_cells: int = 0
	for cy: int in range(int(fm["plot_rows"])):
		for cx: int in range(int(fm["plot_cols"])):
			if not world.is_solid(Vector2(float(o[0]) + cx * 16 + 8, float(o[1]) + cy * 16 + 8)):
				free_cells += 1
	_check(free_cells == int(fm["plot_cols"]) * int(fm["plot_rows"]), "semua %d petak ladang bisa dijalani (ada %d)" % [int(fm["plot_cols"]) * int(fm["plot_rows"]), free_cells])

	# alur bertani
	var cell: Vector2i = Vector2i(0, 0)
	_check(Game.till(cell), "cangkul petak")
	_check(Game.plant(cell, "item_turnip_seed"), "tanam benih lobak")
	for d: int in range(4):
		_check(Game.water(cell), "siram hari %d" % (d + 1))
		Game.next_day()
	_check(Game.is_ready(Game.plot(cell)), "lobak siap panen setelah 4 hari")
	_check(Game.harvest(cell), "panen")
	_check(Game.count("item_turnip") == 1, "lobak masuk tas")
	var g0: int = Game.gold()
	Game.sell("item_turnip", 1)
	_check(Game.gold() == g0 + 55, "jual lobak +55 emas")
	_check(Game.buy("item_wheat_seed") and Game.count("item_wheat_seed") == 5, "beli benih gandum")

	# simpan / muat
	world.save_now()
	var gold_saved: int = Game.gold()
	Game.s = {}
	_check(Game.load_game() and Game.gold() == gold_saved, "simpan & muat")

	# kota
	world.load_map("city", Vector2(-1, -1))
	var cm: Dictionary = world.meta["city"] as Dictionary
	_check(world.map_name == "city" and world.mw == 1024 and world.mh == 768, "peta kota dimuat 1024x768")
	var doors: Dictionary = cm["doors"] as Dictionary
	for id: String in doors.keys():
		var d: Array = doors[id] as Array
		var pp: PackedVector2Array = world.find_path(world.player.position, Vector2(float(d[0]), float(d[1]) + 18.0))
		_check(pp.size() > 3, "jalur kota -> pintu %s (%d titik)" % [id, pp.size()])
	var gw: Array = cm["gate_west"] as Array
	var pg: PackedVector2Array = world.find_path(Vector2(900, 420), Vector2(float(gw[0]) + 4.0, (float(gw[1]) + float(gw[3])) / 2.0))
	_check(pg.size() > 5, "jalur kota timur -> gerbang barat")
	_check(world.npcs.size() == 5, "5 NPC di kota")

	print("SELFTEST " + ("OK" if _fails == 0 else "GAGAL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
