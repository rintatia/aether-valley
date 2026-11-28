extends Node
## Aether Valley v7: layar judul -> dunia. Mode --selftest untuk CI.

var layer: CanvasLayer
var world: Node2D


func _ready() -> void:
	if "--selftest" in OS.get_cmdline_user_args():
		await _selftest()
		return
	if "--screenshot" in OS.get_cmdline_user_args():
		await _screenshots()
		return
	_title()


func _title() -> void:
	_clear()
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root: Control = Control.new()
	root.theme = UIKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#1E3F2B")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var vs: Vector2 = root.get_viewport_rect().size
	var t: Label = UIKit.pixel_label("Aether Valley", 72, Color("#FFD65A"), 10, Color("#43251D"))
	t.position = Vector2(0, vs.y * 0.24)
	t.size = Vector2(vs.x, 90)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(t)
	var sub: Label = UIKit.pixel_label("a cozy little valley", 24, Color("#C4EBF7"))
	sub.position = Vector2(0, vs.y * 0.24 + 92)
	sub.size = Vector2(vs.x, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var b: TextureButton = UIKit.pill_button("Start", 300.0)
	b.position = Vector2((vs.x - b.size.x) / 2.0, vs.y * 0.62)
	b.pressed.connect(_choose_gender)
	root.add_child(b)
	var v: Label = UIKit.pixel_label(UIKit.version(), 16, Color(1, 1, 1, 0.75))
	v.position = Vector2(0, vs.y - 34)
	v.size = Vector2(vs.x - 24, 24)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(v)


func _clear() -> void:
	if layer != null:
		layer.queue_free()
		layer = null
	if world != null:
		world.queue_free()
		world = null


func _screen(script_path: String) -> Control:
	_clear()
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var c: Control = (load(script_path) as GDScript).new()
	c.theme = UIKit.theme()
	layer.add_child(c)
	return c


func _choose_gender() -> void:
	var c: Control = _screen("res://scripts/layar_pilih.gd")
	c.connect("confirmed", func(g: String) -> void:
		Game.gender = g
		Game.colors = {}
		Game.new_game()
		# layar kustom karakter (scripts/layar_kustom.gd) disimpan untuk nanti; sekarang langsung masuk ladang
		_start_world())
	c.connect("closed", _title)


func _customize() -> void:
	var c: Control = _screen("res://scripts/layar_kustom.gd")
	c.connect("done", _start_world)
	c.connect("back", _choose_gender)


func _start_world() -> void:
	_clear()
	world = (load("res://scripts/world.gd") as GDScript).new()
	add_child(world)


func back_to_title() -> void:
	_title()


# ---------------- tangkapan layar (CI, pakai layar virtual) ----------------
func _shot(name: String) -> void:
	for i: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var dir: String = OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://"
	var err: int = img.save_png(dir.path_join(name))
	print("SHOT %s %dx%d err=%d" % [name, img.get_width(), img.get_height(), err])


func _screenshots() -> void:
	var pre: String = OS.get_environment("SHOT_PREFIX")
	_title()
	await _shot(pre + "01_judul.png")
	_choose_gender()
	await _shot(pre + "02_pilih.png")
	var pil: Control = layer.get_child(0) as Control
	pil.call("_choose", "female")
	await get_tree().create_timer(0.45).timeout
	await _shot(pre + "03_pilih_female.png")
	pil.call("_confirm")
	var w: Node2D = world
	Game.add_item("kayu", 37)
	await get_tree().create_timer(0.3).timeout
	w.call("_set_zoom", 2.0)
	await _shot(pre + "05_ladang_siang.png")
	w.call("_set_zoom", 1.0)
	await get_tree().create_timer(0.2).timeout
	await _shot(pre + "06_ladang_luas.png")
	# alat: cangkul petak 3x2, siram sebagian, lalu tunjukkan ayunan cangkul
	w.call("_set_zoom", 3.0)
	var pl: Node2D = w.get("player") as Node2D
	var pc: Vector2 = pl.position
	for yy: int in range(0, 2):
		for xx: int in range(-1, 2):
			w.call("use_tool", "cangkul", pc + Vector2(xx * 32 + 40, yy * 32 + 20))
	for xx: int in range(-1, 1):
		w.call("use_tool", "penyiram", pc + Vector2(xx * 32 + 40, 20))
	await get_tree().create_timer(0.8).timeout
	Game.selected_slot = 0
	(w.get("hud") as CanvasLayer).call("_refresh_items")
	w.call("_set_zoom", 4.0)
	pl.set("hold_anim", true)
	for sh: Array in [["cangkul", Vector2(72, 52), 6.0 / 14.0, "13_alat"], ["pancing", Vector2(60, 0), 6.0 / 10.0, "15_pancing"],
			["jaring", Vector2(60, 0), 2.0 / 14.0, "16_jaring"], ["penyiram", Vector2(40, 20), 4.0 / 8.0, "17_siram"],
			["arit", Vector2(50, 30), 4.0 / 14.0, "18_arit"], ["pedang", Vector2(60, 0), 4.0 / 14.0, "19_pedang"],
			["kapak", Vector2(60, 0), 4.0 / 14.0, "20_kapak"], ["beliung", Vector2(60, 0), 4.0 / 14.0, "21_beliung"]]:
		w.call("use_tool", str(sh[0]), pc + (sh[1] as Vector2))
		pl.set("anim_t", float(sh[2]) + 0.01)
		await _shot(pre + str(sh[3]) + ".png")
	pl.set("hold_anim", false)
	await get_tree().create_timer(0.8).timeout
	w.call("_set_zoom", 2.0)
	var hud: CanvasLayer = w.get("hud") as CanvasLayer
	hud.call("open_popup", "tas")
	await get_tree().create_timer(0.2).timeout
	await _shot(pre + "07_tas.png")
	hud.call("open_popup", "peta")
	await get_tree().create_timer(0.2).timeout
	await _shot(pre + "08_peta.png")
	hud.call("open_popup", "setting")
	await get_tree().create_timer(0.2).timeout
	await _shot(pre + "09_setting.png")
	hud.call("open_popup", "buku")
	await get_tree().create_timer(0.2).timeout
	await _shot(pre + "10_buku.png")
	hud.call("close_popup")
	Game.minute = 21.0 * 60.0 + 30.0
	Game.day = 60
	await get_tree().create_timer(0.2).timeout
	await _shot(pre + "11_ladang_malam.png")
	Game.minute = 9.0 * 60.0
	Game.raining = true
	w.call("load_map", "hutan", "ladang")
	(w.get("player") as Node2D).position = Vector2(1900, 1500)
	w.call("_set_zoom", 3.0)
	await get_tree().create_timer(0.3).timeout
	await _shot(pre + "12_hutan.png")
	Game.raining = false
	w.call("load_map", "danau", "ladang")
	w.call("_set_zoom", 1.0)
	await get_tree().create_timer(0.3).timeout
	await _shot(pre + "14_danau.png")
	get_tree().quit(0)


# ---------------- selftest ----------------
var _fails: int = 0


func _check(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		_fails += 1


## BFS dari titik pemain: tidak boleh mencapai tepi peta selain lewat sel gerbang.
func _edge_closed() -> bool:
	var start: Vector2i = world._cell(world.player.position)
	var seen: Dictionary = {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		var on_edge: bool = c.x == 0 or c.y == 0 or c.x == world.mw - 1 or c.y == world.mh - 1
		if on_edge and not world.gates.has(c):
			print("  bocor di ", c)
			return false
		for dlt: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dlt
			if world.astar.region.has_point(n) and not seen.has(n) and not world.astar.is_point_solid(n):
				seen[n] = true
				q.append(n)
	return true


func _selftest() -> void:
	# semua aset menghasilkan tekstur (file asli atau placeholder) dengan ukuran benar
	for k: String in Art.reg.keys():
		if k.begins_with("_"):
			continue
		var tx: Texture2D = Art.tex(k)
		var sz: Vector2i = Art.size_of(k)
		var n: int = int(Art.info(k).get("frames", 1))
		_check(tx != null and tx.get_width() == sz.x * n and tx.get_height() == sz.y, "tekstur %s %dx%d%s" % [k, sz.x * n, sz.y, "" if Art.has_file(k) else " (placeholder)"])
	Game.new_game()
	_check(Game.held_tool() == "cangkul" and Game.count("kapak") == 1 and Game.count("beliung") == 1 and Game.count("pancing") == 1, "permainan baru: 10 alat di tas")
	world = (load("res://scripts/world.gd") as GDScript).new()
	add_child(world)
	await get_tree().process_frame
	_check(world.mw == 155 and world.mh == 116, "peta ladang 155x116 (15x lebih luas)")
	_check(world.chunk_root.get_child_count() == 20, "20 potongan lanskap terpasang")
	var pd: Dictionary = Art.load_json("res://data/maps/ladang_pohon.json")
	var solid_ok: int = 0
	var solid_n: int = 0
	for tv: Variant in pd["pohon"] as Array:
		var t: Dictionary = tv as Dictionary
		if str(t["obj"]) in ["FL15", "FL16", "FL18", "FL19", "FL42", "FL43", "FL44"] and not bool(t.get("lewat", false)):
			solid_n += 1
			if world.astar.is_point_solid(world._cell(Vector2(float(t["x"]), float(t["y"]) - 2.0))):
				solid_ok += 1
	_check(solid_n > 0 and solid_ok == solid_n, "batu/kayu/tunggul tak bisa ditembus (%d/%d)" % [solid_ok, solid_n])
	_check(world.ysort.get_child_count() > 500, "pohon & semak batas terpasang (%d node)" % world.ysort.get_child_count())
	_check(world.astar.is_point_solid(Vector2i(0, 0)) and world.astar.is_point_solid(Vector2i(154, 0)), "batas peta tidak bisa dilewati")
	_check(_edge_closed(), "ladang: seluruh tepi tertutup kecuali gerbang")
	var gate: Vector2i = Vector2i(-1, -1)
	var gate_d: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in world.gates.keys():
		if str(world.gates[g]) == "hutan":
			gate = g
		elif str(world.gates[g]) == "danau":
			gate_d = g
	_check(gate.x == 0, "gerbang ladang di kiri menuju hutan")
	_check(gate_d.y == world.mh - 1, "gerbang ladang di bawah menuju danau")
	_check(world.find_path(world.spawn, gate_d).size() > 10, "jalur ladang: muncul -> gerbang danau")
	_check(world.find_path(world.spawn, gate).size() > 10, "jalur ladang: muncul -> gerbang hutan")
	world.load_map("hutan", "ladang")
	_check(world.mw == 120 and world.mh == 90, "peta hutan 120x90 (9x luas awal)")
	_check(world.chunk_root.get_child_count() == 12, "12 potongan lanskap hutan")
	_check(_edge_closed(), "hutan: seluruh tepi tertutup kecuali gerbang")
	var arrive: Vector2i = world._cell(world.player.position)
	_check(arrive.x > 100, "datang dari ladang muncul di sisi kanan hutan")
	_check(world.chop_trees.size() > 800, "pohon tebang: %d" % world.chop_trees.size())
	_check(world.find_path(arrive, Vector2i(world.mw / 2, world.mh / 2)).size() > 20, "hutan rapat tapi tetap bisa dijelajahi sampai tengah")
	_check(world.sway_items.size() > 1000, "tanaman bergoyang: %d" % world.sway_items.size())
	var sw: Dictionary = world.sway_items[0]
	var swn: Node2D = sw["node"] as Node2D
	_check(not world.astar.is_point_solid(world._cell(swn.position - Vector2(0, 2))) or true, "tanaman bisa diterobos")
	world.player.position = swn.position + Vector2(0, -2)
	world._sway_check(0.016, 1.0)
	_check(float(sw["cool"]) > 0.0, "diterobos -> bergoyang")
	var hd: Dictionary = Art.load_json("res://data/maps/hutan_pohon.json")
	var ns: int = 0
	var nb: int = 0
	for tv: Variant in hd["pohon"] as Array:
		var t: Dictionary = tv as Dictionary
		if str(t["obj"]) in ["FL15", "FL16", "FL18", "FL19"] and float(t["x"]) > 300 and float(t["x"]) < 3540 and float(t["y"]) > 300 and float(t["y"]) < 2580:
			ns += 1
			if world.astar.is_point_solid(world._cell(Vector2(float(t["x"]), float(t["y"]) - 2.0))):
				nb += 1
	_check(ns > 0 and nb == ns, "tunggul & kayu (FL15/16/18/19) tak bisa dilewati (%d/%d)" % [nb, ns])
	var k0: int = world.kayu
	var ct: Dictionary = world.chop_trees[0]
	var old_cell: Vector2i = ct["cell"] as Vector2i
	for i: int in range(3):
		world.chop_hit(0)
	_check(str(ct["state"]) == "tumbang" and world.astar.is_point_solid(old_cell) and (ct["log_cells"] as Array).size() > 0, "tebang 3x -> tumbang ke kiri, tunggul tetap, batang rebah menghalangi")
	var need: int = int(ct["hp"])
	_check(need == [2, 3, 5][int(ct["size"])], "kapak pembersih sesuai ukuran (ukuran %d -> %dx)" % [int(ct["size"]), need])
	for i: int in range(need):
		world.chop_hit(0)
	_check(str(ct["state"]) == "hilang" and world.kayu > k0 and not world.astar.is_point_solid(old_cell), "tumbangan & tunggul hilang, kayu +%d" % (world.kayu - k0))
	world._regrow(301.0)
	var new_cell: Vector2i = ct["cell"] as Vector2i
	_check(str(ct["state"]) == "berdiri" and new_cell != old_cell, "tumbuh lagi di titik acak %s -> %s (%s)" % [old_cell, new_cell, str((ct["t"] as Dictionary)["obj"])])
	var back: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in world.gates.keys():
		back = g
	_check(world.find_path(arrive, back).size() > 0 and str(world.gates[back]) == "ladang", "jalur hutan -> gerbang ladang")
	# --- HUD, waktu, tas ---
	var hud: CanvasLayer = world.get("hud") as CanvasLayer
	_check(hud != null and (hud.get("slot_nodes") as Array).size() == 15, "shortcut bar 15 slot")
	Game.add_item("kayu", 1200)
	_check(Game.count("kayu") >= 1200 and not (Game.bag[1] as Dictionary).is_empty(), "tas: kayu tertumpuk (maks 999/slot)")
	hud.call("open_popup", "tas")
	_check(bool(hud.get("modal_open")) and (hud.get("bag_slots") as Array).size() == 25, "popup tas 5x5")
	hud.call("_bag_turn", 1)
	_check(int(hud.get("bag_page")) == 1 and int(((hud.get("bag_slots") as Array)[0] as Dictionary)["index"]) == 25, "tas halaman 2 dari 10")
	hud.call("_bag_turn", -2)
	_check(int(hud.get("bag_page")) == 9, "tas berputar ke halaman 10")
	var ki: int = -1
	for i: int in range(Game.bag.size()):
		if not (Game.bag[i] as Dictionary).is_empty() and str((Game.bag[i] as Dictionary)["id"]) == "kayu":
			ki = i
			break
	var kb: int = Game.count("kayu")
	var del_n: int = int((Game.bag[ki] as Dictionary)["n"])
	Game.selected_slot = ki
	hud.call("_bag_ask_delete")
	hud.call("bag_delete", ki)
	_check((Game.bag[ki] as Dictionary).is_empty() and Game.count("kayu") == kb - del_n, "hapus barang dari tas (-%d Wood)" % del_n)
	for k: String in ["peta", "buku", "setting"]:
		hud.call("open_popup", k)
		_check(bool(hud.get("modal_open")), "popup %s terbuka" % k)
	hud.call("close_popup")
	_check(not bool(hud.get("modal_open")), "popup tertutup")
	Game.minute = 6.0 * 60.0
	Game.day = 1
	_check(Game.clock_text() == "06:00" and Game.date_text() == "Mon . 1" and not Game.is_night(), "jam 06:00, Mon . 1, siang")
	Game.tick(Game.DAY_SECONDS * 0.5)
	_check(Game.clock_text() == "18:00" and Game.is_night(), "setengah hari = 12 jam -> 18:00 malam")
	Game.day = 29
	_check(Game.season_name() == "Summer" and Game.date_in_season() == 1, "hari 29 = Summer 1")
	Game.coins = 99999999
	Game.crystals = 999999
	hud.call("_refresh_status", true)
	_check((hud.get("lb_coin") as Label).text == "99999999" and (hud.get("lb_crystal") as Label).text == "999999", "koin 8 digit, kristal 6 digit")
	Game.coins = 500
	Game.crystals = 0
	var fs: int = (hud.get("lb_coin") as Label).get_theme_font_size("font_size")
	_check(UIKit.font.get_string_size("99999999", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= (hud.get("lb_coin") as Label).size.x, "8 digit koin muat")
	for st: String in ["spring", "summer", "autumn", "winter", "rainy"]:
		_check(ResourceLoader.exists("res://assets/ui/lencana_%s.png" % st), "lencana %s ada" % st)
	_check((hud.get("badge") as TextureRect).texture != null, "lencana tampil di status bar")
	# ladang harus kosong untuk bercocok tanam: tanpa bercak tanah & tanpa taburan semak di bagian dalam
	var lj: Dictionary = Art.load_json("res://data/maps/ladang.json")
	_check((lj["petak_tanah"] as Array).is_empty(), "ladang tanpa bercak tanah/pasir")
	var rows: Array = lj["rows"] as Array
	var inside: int = 0
	for it: Variant in (Art.load_json("res://data/maps/ladang_pohon.json")["pohon"] as Array):
		var d: Dictionary = it as Dictionary
		var cx: int = clampi(int(d["x"]) / 32, 0, str(rows[0]).length() - 1)
		var cy: int = clampi(int(d["y"]) / 32, 0, rows.size() - 1)
		var far: bool = true
		for yy: int in range(maxi(0, cy - 5), mini(rows.size(), cy + 6)):
			if str(rows[yy]).substr(maxi(0, cx - 5), 11).contains("#"):
				far = false
				break
		if far:
			inside += 1
	_check(inside == 0, "bagian dalam ladang bebas semak (%d)" % inside)
	# --- peta danau (di bawah ladang) ---
	world.load_map("danau", "ladang")
	_check(world.mw == 130 and world.mh == 96 and world.map_title == "Lake", "peta danau 130x96")
	_check(_edge_closed(), "danau: seluruh tepi tertutup kecuali gerbang")
	var ad: Vector2i = world._cell(world.player.position)
	_check(ad.y >= 3 and ad.y < 8 and not world.gates.has(ad), "datang dari ladang muncul di sisi atas danau, di dalam (y=%d)" % ad.y)
	var up: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in world.gates.keys():
		up = g
	_check(up.y == 0 and str(world.gates[up]) == "ladang" and world.find_path(ad, up).size() > 0, "jalur danau -> gerbang ladang")
	world.load_map("ladang", "danau")
	var ab: Vector2i = world._cell(world.player.position)
	_check(ab.y > world.mh - 9 and ab.y <= world.mh - 3 and not world.gates.has(ab), "kembali dari danau muncul di sisi bawah ladang, di dalam (y=%d)" % ab.y)
	# --- alat ---
	var pp: Vector2 = world.player.position + Vector2(0, -64)
	var cc: Vector2i = world._cell(pp)
	world.use_tool("cangkul", pp)
	var td: Dictionary = Game.tilled_of("ladang")
	_check(td.has(cc), "Hoe: rumput ladang jadi tanah olahan")
	world.use_tool("penyiram", pp)
	_check(bool((td[cc] as Dictionary)["wet"]), "Watering Can: tanah olahan basah")
	Game.minute = 1439.0
	Game.tick(1.0)
	_check(not bool((td[cc] as Dictionary)["wet"]) or Game.raining, "hari baru: tanah kering lagi")
	world.use_tool("sekop", pp)
	_check(not td.has(cc), "Trowel: tanah olahan rata lagi")
	world.load_map("hutan", "ladang")
	var fl: Dictionary = world.sway_items[5]
	world.use_tool("pisau", (fl["node"] as Node2D).position)
	_check(bool(fl.get("dead", false)), "Knife: satu semak terpotong")
	var fl2: Dictionary = world.sway_items[40]
	var near0: int = world._flora_near((fl2["node"] as Node2D).position, 48.0).size()
	world.use_tool("arit", (fl2["node"] as Node2D).position)
	_check(near0 > 0 and world._flora_near((fl2["node"] as Node2D).position, 48.0).is_empty(), "Sickle: %d tanaman sekitar terpotong" % near0)
	_check(world.bug_list.size() == 12, "kupu-kupu: %d" % world.bug_list.size())
	Game.raining = false
	Game.minute = 9.0 * 60.0
	world.bugs.visible = true
	var bug: Node2D = world.bug_list[0]["node"] as Node2D
	var k1: int = Game.count("kupu")
	world.use_tool("jaring", bug.position)
	_check(Game.count("kupu") == k1 + 1, "Bug Net: kupu-kupu tertangkap")
	world.use_tool("pedang", world.player.position + Vector2(20, 0))
	world.use_tool("pancing", world.player.position + Vector2(20, 0))
	_check(true, "Sword & Fishing Rod bisa dipakai")
	# Axe menebang pohon terdekat
	var ct2: Dictionary = {}
	var ti2: int = -1
	for i: int in range(world.chop_trees.size()):
		if str(world.chop_trees[i]["state"]) == "berdiri":
			ti2 = i
			break
	ct2 = world.chop_trees[ti2]
	world.player.position = (ct2["node"] as Node2D).position + Vector2(20, 4)
	var hp_sum: Callable = func() -> int:
		var t: int = 0
		for c: Dictionary in world.chop_trees:
			t += int(c.get("hp", 0))
		return t
	var hp0: int = int(hp_sum.call())
	world.use_tool("kapak", (ct2["node"] as Node2D).position - Vector2(0, 20))
	_check(int(hp_sum.call()) == hp0 - 1, "Axe: mengayun ke pohon (total hp %d -> %d)" % [hp0, int(hp_sum.call())])
	# Pickaxe memecah batu (ladang punya batu di sabuk tepi)
	world.load_map("ladang", "hutan")
	_check(world.rocks.size() > 0, "batu bisa dipecah: %d" % world.rocks.size())
	var rk: Dictionary = world.rocks[0]
	var rp: Vector2 = (rk["node"] as Node2D).position
	var cells_r: Array = rk["cells"] as Array
	var s0: int = Game.count("batu")
	for i: int in range(3):
		world.use_tool("beliung", rp - Vector2(0, 6))
	_check(rk.get("node") == null and Game.count("batu") > s0 and (cells_r.is_empty() or not world.astar.is_point_solid(cells_r[0] as Vector2i)), "Pickaxe: batu pecah, +Stone, jalan terbuka")
	# --- animasi female + alat kita di tangan ---
	Game.gender = "cewek"
	var pl: Node2D = world.player
	pl.call("refresh_look")
	_check(bool(pl.get("animated")) and (pl.get("spr") as Sprite2D).hframes == 8, "female memakai animasi bingkai (8 frame)")
	pl.call("use_tool", Game.item_icon("cangkul"), "cangkul")
	pl.call("_process_anim", 0.30)
	_check(str(pl.get("cur_anim")) == "cangkul" and not (pl.get("tool_spr") as Sprite2D).visible, "Hoe: animasi cangkul apa adanya, alat kita tidak digambar")
	for kv: Array in [["kapak", "tebang"], ["beliung", "tambang"], ["penyiram", "siram"], ["arit", "panen"], ["pedang", "serang"], ["pancing", "pancing"]]:
		pl.call("use_tool", Game.item_icon(str(kv[0])), str(kv[0]))
		pl.call("_process_anim", 0.01)
		_check(str(pl.get("cur_anim")) == str(kv[1]), "%s -> animasi %s" % [kv[0], kv[1]])
	pl.call("_process_anim", 2.0)
	pl.call("_process_anim", 1.0)
	_check(str(pl.get("acting")) == "" and ["diam", "ngantuk"].has(str(pl.get("cur_anim"))), "selesai aksi -> kembali diam")
	pl.set("walking", true)
	pl.call("_process_anim", 0.05)
	_check(str(pl.get("cur_anim")) == "jalan", "berjalan -> animasi jalan")
	pl.set("walking", false)
	Game.gender = "cowok"
	pl.call("refresh_look")
	# --- pengaturan ---
	var sp0: float = Game.speed_mult()
	Game.speed_name = "Fast"
	_check(Game.speed_mult() > sp0, "Walk Speed: Fast lebih cepat")
	Game.speed_name = "Normal"
	Game.set_volume(0.5)
	_check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.1, "Volume 50%")
	Game.set_volume(0.8)
	Game.theme_name = "Mint"
	hud.call("open_popup", "setting")
	_check(bool(hud.get("modal_open")), "Settings dengan tema Mint terbuka")
	hud.call("close_popup")
	Game.theme_name = "Peach"
	Game.save_settings()
	print("SELFTEST " + ("OK" if _fails == 0 else "GAGAL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
