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
	get_tree().quit(0)


# ---------------- selftest ----------------
var _fails: int = 0


func _check(ok: bool, msg: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + msg)
	if not ok:
		_fails += 1


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
	_check(world.ysort.get_child_count() > 1500, "pohon & semak batas terpasang (%d node)" % world.ysort.get_child_count())
	_check(world.astar.is_point_solid(Vector2i(0, 0)) and world.astar.is_point_solid(Vector2i(154, 0)), "batas peta tidak bisa dilewati")
	var gate: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in world.gates.keys():
		gate = g
	var sp: Vector2i = world.spawn
	_check(world.find_path(sp, gate).size() > 10, "jalur ladang: muncul -> gerbang kota")
	for b: Dictionary in world.buildings:
		_check(world.find_path(sp, b["door"] as Vector2i).size() > 1, "jalur ladang -> pintu %s" % str(b["id"]))
	world.load_map("kota", "ladang")
	_check(world.mw == 40 and world.mh == 24, "peta kota 40x24")
	_check(world.buildings.size() == 4, "4 bangunan di kota")
	var arrive: Vector2i = world._cell(world.player.position)
	for b: Dictionary in world.buildings:
		var p: PackedVector2Array = world.find_path(arrive, b["door"] as Vector2i)
		_check(p.size() > 1, "jalur kota -> pintu %s (%d langkah)" % [str(b["id"]), p.size()])
	var back: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in world.gates.keys():
		back = g
	_check(world.find_path(arrive, back).size() > 0, "jalur kota -> gerbang ladang")
	print("SELFTEST " + ("OK" if _fails == 0 else "GAGAL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
