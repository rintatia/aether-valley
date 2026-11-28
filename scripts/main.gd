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
	root.add_child(UIKit.version_label())
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.offset_left = -260
	v.offset_right = 260
	v.offset_top = -150
	v.offset_bottom = 150
	v.add_theme_constant_override("separation", 18)
	root.add_child(v)
	var t: Label = UIKit.label("Aether Valley", 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var keys: Array = []
	for k: String in Art.reg.keys():
		if not k.begins_with("_"):
			keys.append(k)
	var have: int = 0
	for k: String in keys:
		if Art.has_file(k):
			have += 1
	var s: Label = UIKit.label("Aset terpasang: %d / %d" % [have, keys.size()], 22)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b: Button = UIKit.button("Mulai", 0, 72)
	b.pressed.connect(func() -> void:
		layer.queue_free()
		world = (load("res://scripts/world.gd") as GDScript).new()
		add_child(world))
	v.add_child(b)


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
	var w: Node2D = (load("res://scripts/world.gd") as GDScript).new()
	add_child(w)
	var pre: String = OS.get_environment("SHOT_PREFIX")
	await _shot(pre + "ladang_x2_awal.png")
	w.call("_set_zoom", 2.0)
	(w.get("player") as Node2D).position = Vector2(900, 230)
	await _shot(pre + "ladang_tepi_hutan.png")
	w.call("_set_zoom", 0.01)
	await _shot(pre + "ladang_terjauh.png")
	w.call("_set_zoom", 6.0)
	await _shot(pre + "ladang_terdekat_x6.png")
	w.call("load_map", "hutan", "ladang")
	w.call("_set_zoom", 2.0)
	await _shot(pre + "hutan_x2_gerbang.png")
	(w.get("player") as Node2D).position = Vector2(1900, 1500)
	await _shot(pre + "hutan_x2_tengah.png")
	# pohon terdekat ditebang -> tangkap saat tumbang ke kiri
	var trees: Array = w.get("chop_trees") as Array
	var bi: int = 0
	var bd: float = 1e9
	for i: int in range(trees.size()):
		var dd: float = ((trees[i]["node"] as Node2D).position - Vector2(1900, 1500)).length()
		if dd < bd:
			bd = dd
			bi = i
	for k: int in range(3):
		w.call("chop_hit", bi)
	await get_tree().create_timer(0.62).timeout
	await _shot(pre + "hutan_tumbang_jatuh.png")
	await get_tree().create_timer(0.8).timeout
	await _shot(pre + "hutan_tumbang.png")
	(w.get("player") as Node2D).position = (trees[bi]["node"] as Node2D).position + Vector2(-40, 30)
	w.call("_set_zoom", 4.0)
	await _shot(pre + "hutan_tumbang_dekat.png")
	w.call("_set_zoom", 0.01)
	await _shot(pre + "hutan_terjauh.png")
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
		if str(t["obj"]) in ["FL15", "FL16", "FL18", "FL19", "FL42", "FL43", "FL44"]:
			solid_n += 1
			if world.astar.is_point_solid(world._cell(Vector2(float(t["x"]), float(t["y"]) - 2.0))):
				solid_ok += 1
	_check(solid_n > 0 and solid_ok == solid_n, "batu/kayu/tunggul tak bisa ditembus (%d/%d)" % [solid_ok, solid_n])
	_check(world.ysort.get_child_count() > 500, "pohon & semak batas terpasang (%d node)" % world.ysort.get_child_count())
	_check(world.astar.is_point_solid(Vector2i(0, 0)) and world.astar.is_point_solid(Vector2i(154, 0)), "batas peta tidak bisa dilewati")
	_check(_edge_closed(), "ladang: seluruh tepi tertutup kecuali gerbang")
	var gate: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in world.gates.keys():
		gate = g
	_check(gate.x == 0 and str(world.gates[gate]) == "hutan", "gerbang ladang di kiri menuju hutan")
	_check(world.find_path(world.spawn, gate).size() > 10, "jalur ladang: muncul -> gerbang hutan")
	world.load_map("hutan", "ladang")
	_check(world.mw == 120 and world.mh == 90, "peta hutan 120x90 (9x luas awal)")
	_check(world.chunk_root.get_child_count() == 12, "12 potongan lanskap hutan")
	_check(_edge_closed(), "hutan: seluruh tepi tertutup kecuali gerbang")
	var arrive: Vector2i = world._cell(world.player.position)
	_check(arrive.x > 100, "datang dari ladang muncul di sisi kanan hutan")
	_check(world.chop_trees.size() > 800, "pohon tebang: %d" % world.chop_trees.size())
	_check(world.find_path(arrive, Vector2i(world.mw / 2, world.mh / 2)).size() > 20, "hutan rapat tapi tetap bisa dijelajahi sampai tengah")
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
	print("SELFTEST " + ("OK" if _fails == 0 else "GAGAL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
