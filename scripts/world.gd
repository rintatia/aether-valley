extends Node2D
## Dunia v7: peta petak 32 px dari data/maps/*.json, ketuk-untuk-jalan.
## Zoom = jarak KAMERA. Peta & detailnya tetap; karakter ikut membesar/mengecil di layar.
## Terjauh: seluruh peta memenuhi layar. Terdekat: x6. Di >= x1.5 zoom menempel ke angka bulat (piksel tajam).

const T: int = 32
const SPEED: float = 128.0  # piksel seni per detik (4 petak/detik)
const ZOOM_MAX: float = 6.0
const ZOOM_DEFAULT: float = 2.0
const ZOOM_STEPS: Array[float] = [0.5, 1.0, 2.0, 3.0, 4.0, 6.0]
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
var zoom_min: float = 1.0   # dihitung dari ukuran peta & layar (seluruh peta memenuhi layar)
var zoom_now: float = ZOOM_DEFAULT
var busy: bool = false
var chunk_root: Node2D
const FELL_HITS: int = 3                 # ayunan untuk menumbangkan pohon berdiri
const CLEAR_HITS: Array[int] = [2, 3, 5]  # ayunan membersihkan tumbangan + tunggul: kecil, sedang, besar
const REGROW_SECONDS: float = 300.0   # 1 hari permainan = 5 menit
var chop_trees: Array[Dictionary] = []
var chop_kinds: Array[String] = []   # jenis pohon tebang di peta ini (untuk tumbuh acak)
var chop_spots: Array[Vector2i] = []
var chop_atlas: Texture2D
var chop_regions: Dictionary = {}
var cut_tex: Dictionary = {}   # jenis -> {stump, top, cut}
var kayu: int = 0
var lbl_kayu: Label
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
	chunk_root = Node2D.new()
	ground.add_child(chunk_root)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	player = Node2D.new()
	player.set_script(load("res://scripts/player.gd"))
	ysort.add_child(player)
	cam = Camera2D.new()
	player.add_child(cam)
	_build_hud()
	get_viewport().size_changed.connect(func() -> void:
		_fit_zoom()
		_set_zoom(zoom_now))
	load_map("ladang", "")


# ---------------- peta ----------------
func load_map(id: String, from_gate: String) -> void:
	map_id = id
	var m: Dictionary = Art.load_json("res://data/maps/%s.json" % id)
	_load_chunks(str(m.get("chunks", "")))
	grid = PackedStringArray()
	for line: Variant in m.get("rows", []) as Array:
		grid.append(str(line))
	mh = grid.size()
	mw = grid[0].length() if mh > 0 else 0
	for c: Node in ysort.get_children():
		if c != player:
			ysort.remove_child(c)
			c.queue_free()
	gates.clear()
	buildings.clear()
	chop_trees.clear()
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
				gates[Vector2i(x, y)] = str((m.get("gerbang", {}) as Dictionary).get(str(L["gate"]), ""))
			if bool(L.get("spawn", false)):
				spawn = Vector2i(x, y)
			if L.has("obj"):
				_place_object(str(L["obj"]), Vector2i(x, y), str(L.get("id", "")))
	if m.has("pohon"):
		_place_trees(str(m["pohon"]))
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
	lbl_map.text = str(m.get("nama", id))
	_refresh_kayu()
	ground.queue_redraw()
	_fit_zoom()
	_set_zoom(zoom_now)


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


## Lanskap dipanggang dipasang per potongan 1024 px (aman untuk batas tekstur GPU HP).
## Mipmap dibuat agar saat kamera jauh rumput tidak berkedip.
func _load_chunks(dir: String) -> void:
	for c: Node in chunk_root.get_children():
		chunk_root.remove_child(c)
		c.queue_free()
	if dir == "":
		return
	var info: Dictionary = Art.load_json("res://assets/lanskap/%s/info.json" % dir)
	var cs: int = int(info["chunk"])
	for cy: int in range(int(info["ny"])):
		for cx: int in range(int(info["nx"])):
			var src: Texture2D = load("res://assets/lanskap/%s/c_%d_%d.png" % [dir, cx, cy]) as Texture2D
			var img: Image = src.get_image()
			img.convert(Image.FORMAT_RGB8)
			img.generate_mipmaps()
			var sp: Sprite2D = Sprite2D.new()
			sp.texture = ImageTexture.create_from_image(img)
			sp.centered = false
			sp.position = Vector2(cx * cs, cy * cs)
			chunk_root.add_child(sp)


## Hutan batas (Flora musim semi FL..): satu atlas resolusi tinggi untuk semua; skala per pohon pecahan
## (gambar asli besar diperkecil -> tetap tajam, tidak pecah). Urutan-Y: karakter bisa di depan/belakang.
func _place_trees(id: String) -> void:
	var d: Dictionary = Art.load_json("res://data/maps/%s.json" % id)
	var src: Texture2D = load("res://assets/" + str(d["atlas"])) as Texture2D
	var img: Image = src.get_image()
	img.generate_mipmaps()
	var atlas: ImageTexture = ImageTexture.create_from_image(img)
	var regions: Dictionary = d["region"] as Dictionary
	var blocks: Dictionary = d.get("menghalangi", {}) as Dictionary
	var tapak: Dictionary = d.get("tapak", {}) as Dictionary
	for tv: Variant in d["pohon"] as Array:
		var t: Dictionary = tv as Dictionary
		var holder: Node2D = _sprite_from(atlas, regions, t)
		var code: String = str(t["obj"])
		if bool(blocks.get(code, true)):
			_block_base(holder.position, float((regions[code] as Array)[2]) * float(t["skala"]), float(tapak.get(code, 0.4)))
	# pohon tebang: 3 ayunan -> tumbang ke kiri & hilang -> tumbuh lagi di titik ACAK (1 hari = 5 menit)
	chop_kinds.clear()
	chop_atlas = atlas
	chop_regions = regions
	chop_kinds.clear()
	for tv: Variant in d.get("tebang", []) as Array:
		var kd: String = str((tv as Dictionary)["obj"])
		if not chop_kinds.has(kd):
			chop_kinds.append(kd)
	_build_cut_textures(img, regions)
	for tv: Variant in d.get("tebang", []) as Array:
		var t: Dictionary = tv as Dictionary
		if not chop_kinds.has(str(t["obj"])):
			chop_kinds.append(str(t["obj"]))
		_spawn_chop_tree(t)
	_find_chop_spots()


## Untuk tiap jenis pohon tebang: dua gambar dari gambar aslinya, dibelah garis BERGERIGI
## (zigzag tak beraturan seperti bekas kapak). Permukaan tunggul diberi warna kayu terang.
func _build_cut_textures(img: Image, regions: Dictionary) -> void:
	cut_tex.clear()
	for code: String in chop_kinds:
		var r: Array = regions[code] as Array
		var w: int = int(r[2])
		var h: int = int(r[3])
		var src: Image = img.get_region(Rect2i(int(r[0]), int(r[1]), w, h))
		src.convert(Image.FORMAT_RGBA8)
		var cut: int = clampi(int(roundf(h * 0.11)), 10, 22)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash(code)
		var line: PackedInt32Array = PackedInt32Array()
		var off: int = 0
		for x: int in range(w):
			if x % 2 == 0:
				off = clampi(off + rng.randi_range(-2, 2), -4, 3)
			line.append(h - cut + off + (2 if x % 4 < 2 else 0))
		var stump: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
		var top: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for x: int in range(w):
			for y: int in range(h):
				var c: Color = src.get_pixel(x, y)
				if c.a == 0.0:
					continue
				if y < line[x]:
					top.set_pixel(x, y, c)
				else:
					stump.set_pixel(x, y, c)
		# versi "sudah dipotong": permukaan kayu terang di sepanjang garis gerigi (tunggul & ujung batang)
		var stump_cut: Image = stump.duplicate() as Image
		var top_cut: Image = top.duplicate() as Image
		var wood_a: Color = Color("#E8B28A")
		var wood_b: Color = Color("#C68672")
		for x: int in range(w):
			var ys: int = line[x]
			if ys < h and stump.get_pixel(x, ys).a > 0.0:
				stump_cut.set_pixel(x, ys, wood_a if x % 3 != 0 else wood_b)
				if ys + 1 < h and stump.get_pixel(x, ys + 1).a > 0.0 and x % 2 == 0:
					stump_cut.set_pixel(x, ys + 1, wood_b)
			if ys - 1 >= 0 and top.get_pixel(x, ys - 1).a > 0.0:
				top_cut.set_pixel(x, ys - 1, wood_a if x % 3 != 1 else wood_b)
		cut_tex[code] = {"stump": ImageTexture.create_from_image(stump), "top": ImageTexture.create_from_image(top),
			"stump_cut": ImageTexture.create_from_image(stump_cut), "top_cut": ImageTexture.create_from_image(top_cut), "cut": cut}


func _spawn_chop_tree(t: Dictionary) -> Dictionary:
	var ct: Dictionary = {"t": t}
	chop_trees.append(ct)
	_raise_tree(ct, t)
	return ct


## Pohon berdiri = 2 bagian dari satu gambar: TUNGGUL (bawah) + BATANG ATAS (berputar di titik potong).
func _raise_tree(ct: Dictionary, t: Dictionary) -> void:
	var holder: Node2D = Node2D.new()
	holder.position = Vector2(float(t["x"]), float(t["y"]))
	ysort.add_child(holder)
	var r: Array = chop_regions[str(t["obj"])] as Array
	var sc: float = float(t["skala"])
	var w: float = float(r[2])
	var h: float = float(r[3])
	var ctx: Dictionary = cut_tex[str(t["obj"])] as Dictionary
	var cut: float = float(ctx["cut"])
	var mirror: bool = bool(t["cermin"])
	var stump: Sprite2D = _tex_sprite(ctx["stump"] as Texture2D, sc, mirror)
	stump.position = Vector2(-w * sc / 2.0, -h * sc)
	holder.add_child(stump)
	var pivot: Node2D = Node2D.new()
	pivot.position = Vector2(0, -cut * sc)
	holder.add_child(pivot)
	var top: Sprite2D = _tex_sprite(ctx["top"] as Texture2D, sc, mirror)
	top.position = Vector2(-w * sc / 2.0, -h * sc + cut * sc)
	pivot.add_child(top)
	ct["stump_spr"] = stump
	ct["top_spr"] = top
	var hh: float = h * sc
	var size: int = 2 if hh >= 160.0 else (1 if hh >= 110.0 else 0)   # 0 kecil, 1 sedang, 2 besar
	ct["t"] = t
	ct["node"] = holder
	ct["pivot"] = pivot
	ct["w"] = w * sc
	ct["h"] = hh
	ct["len"] = (h - cut) * sc
	ct["size"] = size
	ct["state"] = "berdiri"
	ct["hp"] = FELL_HITS
	ct["regrow"] = 0.0
	ct["cell"] = _cell(holder.position - Vector2(0, 2))
	ct["log_cells"] = []
	astar.set_point_solid(ct["cell"] as Vector2i, true)


func _tex_sprite(tex: Texture2D, sc: float, mirror: bool) -> Sprite2D:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.flip_h = mirror
	spr.scale = Vector2(sc, sc)
	return spr


func _region_sprite(rect: Rect2, sc: float, mirror: bool) -> Sprite2D:
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = chop_atlas
	spr.region_enabled = true
	spr.region_rect = rect
	spr.centered = false
	spr.flip_h = mirror
	spr.scale = Vector2(sc, sc)
	return spr


## Titik-titik calon tumbuh: petak bebas di bagian dalam hutan, jauh dari sabuk & gerbang.
func _find_chop_spots() -> void:
	chop_spots.clear()
	if chop_kinds.is_empty():
		return
	for y: int in range(2, mh - 2):
		for x: int in range(2, mw - 2):
			var ok: bool = true
			for yy: int in range(y - 1, y + 2):
				for xx: int in range(x - 1, x + 2):
					var ch: String = grid[yy][xx]
					if ch == "#" or ch == "<" or ch == ">":
						ok = false
			if ok:
				chop_spots.append(Vector2i(x, y))


func _sprite_from(atlas: Texture2D, regions: Dictionary, t: Dictionary) -> Node2D:
	var holder: Node2D = Node2D.new()
	holder.position = Vector2(float(t["x"]), float(t["y"]))
	_set_tree_sprite(holder, atlas, regions, str(t["obj"]), float(t["skala"]), bool(t["cermin"]))
	ysort.add_child(holder)
	return holder


func _set_tree_sprite(holder: Node2D, atlas: Texture2D, regions: Dictionary, code: String, sc: float, mirror: bool) -> void:
	for c: Node in holder.get_children():
		c.queue_free()
	var r: Array = regions[code] as Array
	var w: float = float(r[2])
	var h: float = float(r[3])
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = atlas
	spr.region_enabled = true
	spr.region_rect = Rect2(float(r[0]), float(r[1]), w, h)
	spr.centered = false
	spr.flip_h = mirror
	spr.scale = Vector2(sc, sc)
	spr.position = Vector2(-w * sc / 2.0, -h * sc)
	holder.add_child(spr)


## tapak penghalang selebar dasar objek (batang pohon sempit, kayu/batu lebih lebar)
func _block_base(pos: Vector2, width: float, frac: float) -> void:
	var half: float = maxf(width * frac / 2.0, 4.0)
	var c0: Vector2i = _cell(pos + Vector2(-half, -2))
	var c1: Vector2i = _cell(pos + Vector2(half, -2))
	for cx: int in range(c0.x, c1.x + 1):
		var c: Vector2i = Vector2i(cx, c0.y)
		if astar.region.has_point(c):
			astar.set_point_solid(c, true)


# ---------------- menebang ----------------
## Pohon/batang yang diketuk: pohon berdiri (kotak tubuhnya) atau pohon tumbang (batang rebah + tunggul).
func _tree_at(wp: Vector2) -> int:
	var best: int = -1
	var best_y: float = -1.0
	for i: int in range(chop_trees.size()):
		var ct: Dictionary = chop_trees[i]
		if str(ct.get("state", "")) == "hilang" or ct.get("node") == null:
			continue
		var p: Vector2 = (ct["node"] as Node2D).position
		var w: float = float(ct["w"])
		var hit: Rect2
		if str(ct["state"]) == "berdiri":
			hit = Rect2(p.x - w * 0.4, p.y - float(ct["h"]), w * 0.8, float(ct["h"]) + 4.0)
		else:
			var ln: float = float(ct["len"])
			hit = Rect2(p.x - ln - 8.0, p.y - w * 0.55, ln + w * 0.25 + 8.0, w * 0.6)
		if hit.has_point(wp) and p.y > best_y:
			best = i
			best_y = p.y
	return best


func _near_tree(ct: Dictionary) -> bool:
	var pc: Vector2i = _cell(player.position)
	if pc.distance_to(ct["cell"] as Vector2i) <= 1.5:
		return true
	for lc: Variant in ct["log_cells"] as Array:
		if pc.distance_to(lc as Vector2i) <= 1.5:
			return true
	return false


func chop_hit(i: int) -> void:
	var ct: Dictionary = chop_trees[i]
	var node: Node2D = ct.get("node") as Node2D
	if node == null or str(ct["state"]) == "hilang":
		return
	ct["hp"] = int(ct["hp"]) - 1
	if str(ct["state"]) == "berdiri":
		if int(ct["hp"]) > 0:
			var tw: Tween = create_tween()
			tw.tween_property(ct["pivot"], "rotation", 0.05, 0.05)
			tw.tween_property(ct["pivot"], "rotation", -0.03, 0.07)
			tw.tween_property(ct["pivot"], "rotation", 0.0, 0.06)
			show_toast("Tok! (%d lagi)" % int(ct["hp"]))
			return
		_fell(ct)
		return
	# membersihkan pohon tumbang + tunggul
	var sh: Tween = create_tween()
	sh.tween_property(node, "position:x", node.position.x + 2.0, 0.04)
	sh.tween_property(node, "position:x", node.position.x, 0.06)
	if int(ct["hp"]) > 0:
		show_toast("Kapak! (%d lagi)" % int(ct["hp"]))
		return
	_clear_fallen(ct)


## Batang atas tumbang SELALU ke kiri, tunggul tetap berdiri. Batang rebah menghalangi jalan.
func _fell(ct: Dictionary) -> void:
	ct["state"] = "tumbang"
	var ctx: Dictionary = cut_tex[str((ct["t"] as Dictionary)["obj"])] as Dictionary
	(ct["stump_spr"] as Sprite2D).texture = ctx["stump_cut"] as Texture2D
	(ct["top_spr"] as Sprite2D).texture = ctx["top_cut"] as Texture2D
	ct["hp"] = CLEAR_HITS[int(ct["size"])]
	var pivot: Node2D = ct["pivot"] as Node2D
	var fall: Tween = create_tween()
	fall.tween_property(pivot, "rotation", 0.06, 0.12).set_trans(Tween.TRANS_SINE)          # sedikit condong balik
	fall.tween_property(pivot, "rotation", -0.25, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)   # mulai miring pelan
	fall.tween_property(pivot, "rotation", -PI / 2.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)  # jatuh makin cepat
	fall.tween_property(pivot, "rotation", -PI / 2.0 + 0.09, 0.07).set_ease(Tween.EASE_OUT)  # memantul
	fall.tween_property(pivot, "rotation", -PI / 2.0, 0.10).set_ease(Tween.EASE_IN)
	fall.tween_property(pivot, "rotation", -PI / 2.0 + 0.025, 0.05)
	fall.tween_property(pivot, "rotation", -PI / 2.0, 0.06)
	var base: Vector2 = (ct["node"] as Node2D).position
	var cells: Array = []
	var x: float = base.x - 6.0
	while x > base.x - float(ct["len"]) * 0.9:
		var c: Vector2i = _cell(Vector2(x, base.y - 2.0))
		if astar.region.has_point(c) and not astar.is_point_solid(c) and not cells.has(c):
			astar.set_point_solid(c, true)
			cells.append(c)
		x -= float(T) / 2.0
	ct["log_cells"] = cells
	show_toast("Pohon tumbang! Kapak %dx untuk membersihkan" % int(ct["hp"]))


func _clear_fallen(ct: Dictionary) -> void:
	var node: Node2D = ct["node"] as Node2D
	astar.set_point_solid(ct["cell"] as Vector2i, false)
	for lc: Variant in ct["log_cells"] as Array:
		astar.set_point_solid(lc as Vector2i, false)
	ct["log_cells"] = []
	var got: int = [2, 4, 6][int(ct["size"])] + randi() % 2
	kayu += got
	_refresh_kayu()
	show_toast("+%d kayu" % got)
	ct["state"] = "hilang"
	ct["node"] = null
	ct["regrow"] = REGROW_SECONDS
	var tw: Tween = create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.35)
	tw.tween_callback(node.queue_free)


func _regrow(delta: float) -> void:
	for ct: Dictionary in chop_trees:
		if str(ct.get("state", "")) != "hilang":
			continue
		ct["regrow"] = float(ct["regrow"]) - delta
		if float(ct["regrow"]) <= 0.0:
			_grow_random(ct)


## Tumbuh lagi di titik ACAK yang lapang (bukan di bekasnya), jenis/ukuran/arah acak.
func _grow_random(ct: Dictionary) -> void:
	var pc: Vector2i = _cell(player.position)
	for attempt: int in range(80):
		if chop_spots.is_empty():
			break
		var c: Vector2i = chop_spots[randi() % chop_spots.size()]
		if c.distance_to(pc) < 4.0 or astar.is_point_solid(c):
			continue
		var crowded: bool = false
		for o: Dictionary in chop_trees:
			if str(o.get("state", "")) != "hilang" and (o["cell"] as Vector2i).distance_to(c) < 2.2:
				crowded = true
				break
		if crowded:
			continue
		var t: Dictionary = {"obj": chop_kinds[randi() % chop_kinds.size()], "skala": randf_range(0.78, 1.0), "cermin": randf() < 0.5,
			"x": (c.x + randf_range(0.25, 0.75)) * T, "y": (c.y + 1) * T - 2.0}
		_raise_tree(ct, t)
		var holder: Node2D = ct["node"] as Node2D
		holder.scale = Vector2(0.2, 0.2)
		create_tween().tween_property(holder, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	ct["regrow"] = 10.0   # belum ada tempat lapang (mis. pemain terlalu dekat) -> coba lagi nanti


func _refresh_kayu() -> void:
	if lbl_kayu != null:
		lbl_kayu.text = "Kayu: %d" % kayu


func _draw_ground() -> void:
	if chunk_root.get_child_count() > 0:
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
	lbl_kayu = UIKit.label("Kayu: 0", 22)
	lbl_kayu.position = Vector2(16, 50)
	root.add_child(lbl_kayu)
	root.add_child(lbl_map)
	root.add_child(UIKit.version_label())
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


func _fit_zoom() -> void:
	var vs: Vector2 = get_viewport_rect().size
	if mw == 0 or mh == 0:
		return
	zoom_min = maxf(vs.x / float(mw * T), vs.y / float(mh * T))


func _set_zoom(z: float) -> void:
	zoom_now = clampf(z, zoom_min, ZOOM_MAX)
	cam.zoom = Vector2(zoom_now, zoom_now)
	# kamera jauh (< x1): beberapa piksel peta jadi satu piksel layar -> pakai mipmap agar tidak berkedip
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if zoom_now < 1.0 else CanvasItem.TEXTURE_FILTER_NEAREST
	ysort.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _apply_zoom() -> void:
	_set_zoom(zoom_now)


func _tween_zoom(target: float) -> void:
	if snap_tw != null:
		snap_tw.kill()
	snap_tw = create_tween()
	snap_tw.tween_method(_set_zoom, cam.zoom.x, clampf(target, zoom_min, ZOOM_MAX), 0.15)


func _levels() -> Array[float]:
	var out: Array[float] = [zoom_min]
	for z: float in ZOOM_STEPS:
		if z > zoom_min * 1.08 and z <= ZOOM_MAX:
			out.append(z)
	return out


## Jari dilepas: di >= x1.5 menempel ke angka bulat terdekat (piksel tajam); lebih jauh dari itu dibiarkan.
func _pinch_end() -> void:
	pinching = false
	var z: float = cam.zoom.x
	if z >= 1.5:
		_tween_zoom(roundf(z))
	else:
		_set_zoom(z)


func change_zoom(d: int) -> void:
	var lv: Array[float] = _levels()
	var best: int = 0
	for i: int in range(lv.size()):
		if absf(lv[i] - zoom_now) < absf(lv[best] - zoom_now):
			best = i
	_tween_zoom(lv[clampi(best + d, 0, lv.size() - 1)])


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
			_set_zoom(pinch_zoom0 * (v2[0] as Vector2).distance_to(v2[1] as Vector2) / pinch_ref)
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
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed and ((e as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP or (e as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_set_zoom(zoom_now * (1.1 if (e as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1))
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
	var ti: int = _tree_at(wp)
	if ti >= 0:
		var tc: Vector2i = chop_trees[ti]["cell"] as Vector2i
		if _near_tree(chop_trees[ti]):
			chop_hit(ti)
		else:
			walk_to(tc, {"type": "chop", "i": ti})
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
	elif str(a["type"]) == "chop":
		chop_hit(int(a["i"]))
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
	_regrow(delta)
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
