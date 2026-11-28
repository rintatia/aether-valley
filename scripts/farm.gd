extends Node2D
## Sistem Farm: objek yang dipasang (Build mode: seret & letakkan, pindah, simpan), tanaman (tabur -> tumbuh -> matang
## -> panen) dan ternak (anak -> dewasa -> hasil harian). Hanya aktif di peta "ladang".

const T: int = 32
const FARM: String = "ladang"
const ANIM_SPEED: float = 22.0

var world: Node2D
var placed_nodes: Array[Dictionary] = []     # {"e": entri Game.placed, "node", "cells"}
var occ: Dictionary = {}                      # sel -> entri Game.placed
var crop_nodes: Dictionary = {}               # sel -> Node2D
var animal_nodes: Array[Dictionary] = []      # {"a": entri Game.animals, "node", "spr", "bubble", "target", "wait"}
var tex_cache: Dictionary = {}

# Build mode
var build_mode: bool = false
var ghost: Node2D
var ghost_spr: Sprite2D
var ghost_id: String = ""
var ghost_from: Dictionary = {}               # entri yang sedang dipindah ({} = barang baru dari tas)
var ghost_origin: Vector2i = Vector2i.ZERO
var ghost_ok: bool = false
var pressing: bool = false
var press_pos: Vector2 = Vector2.ZERO
var press_obj: Dictionary = {}
var panning: bool = false
var selected: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ghost = Node2D.new()
	ghost.z_index = 100
	ghost.visible = false
	ghost.draw.connect(_draw_ghost)
	add_child(ghost)
	ghost_spr = Sprite2D.new()
	ghost_spr.centered = false
	ghost_spr.modulate = Color(1, 1, 1, 0.72)
	ghost.add_child(ghost_spr)
	Game.day_changed.connect(_on_new_day)


func active() -> bool:
	return world != null and str(world.get("map_id")) == FARM


func tex(path: String) -> Texture2D:
	return UIKit.mip_tex(path)


## Dipanggil world.load_map setelah peta dibangun (node lama di ysort sudah dihapus world).
func rebuild() -> void:
	placed_nodes.clear()
	occ.clear()
	crop_nodes.clear()
	animal_nodes.clear()
	selected = {}
	_cancel_ghost()
	if not active():
		if build_mode:
			set_build_mode(false)
		return
	for ev: Variant in Game.placed:
		_spawn(ev as Dictionary)
	for cv: Variant in Game.crops.keys():
		_crop_node(cv as Vector2i)
	for av: Variant in Game.animals:
		_animal_node(av as Dictionary)


# ---------------- objek terpasang ----------------
func _tapak(id: String) -> Vector2i:
	var tp: Array = Game.item(id).get("tapak", [1, 1]) as Array
	return Vector2i(int(tp[0]), int(tp[1]))


func origin_for(id: String, pointer_cell: Vector2i) -> Vector2i:
	var tp: Vector2i = _tapak(id)
	return Vector2i(pointer_cell.x - tp.x / 2, pointer_cell.y - tp.y + 1)


func cells_of(id: String, origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tp: Vector2i = _tapak(id)
	for y: int in range(origin.y, origin.y + tp.y):
		for x: int in range(origin.x, origin.x + tp.x):
			out.append(Vector2i(x, y))
	return out


func pos_for(id: String, origin: Vector2i) -> Vector2:
	var tp: Vector2i = _tapak(id)
	return Vector2((origin.x + tp.x / 2.0) * T, (origin.y + tp.y) * T)


func _make_sprite(id: String) -> Sprite2D:
	var it: Dictionary = Game.item(id)
	var sp: Sprite2D = Sprite2D.new()
	sp.texture = tex(str(it["gambar"]))
	sp.centered = false
	var ts: Vector2 = sp.texture.get_size()
	var uk: Array = it["ukuran"] as Array
	var k: float = float(uk[0]) / ts.x
	sp.scale = Vector2(k, k)
	sp.offset = Vector2(-ts.x / 2.0, -ts.y)
	return sp


func _spawn(e: Dictionary) -> void:
	var id: String = str(e["id"])
	var origin: Vector2i = e["cell"] as Vector2i
	var holder: Node2D = Node2D.new()
	holder.position = pos_for(id, origin)
	holder.add_child(_make_sprite(id))
	(world.get("ysort") as Node2D).add_child(holder)
	var cells: Array[Vector2i] = cells_of(id, origin)
	var astar: AStarGrid2D = world.get("astar") as AStarGrid2D
	var solid: bool = not bool(Game.item(id).get("lewat", false))
	for c: Vector2i in cells:
		occ[c] = e
		if solid and astar.region.has_point(c):
			astar.set_point_solid(c, true)
	placed_nodes.append({"e": e, "node": holder, "cells": cells})


func _despawn(e: Dictionary) -> void:
	for i: int in range(placed_nodes.size()):
		var pn: Dictionary = placed_nodes[i]
		if pn["e"] == e:
			var astar: AStarGrid2D = world.get("astar") as AStarGrid2D
			for c: Vector2i in pn["cells"] as Array[Vector2i]:
				occ.erase(c)
				if astar.region.has_point(c):
					astar.set_point_solid(c, false)
			(pn["node"] as Node2D).queue_free()
			placed_nodes.remove_at(i)
			return


## Boleh diletakkan? Semua sel tapak di dalam Farm, bukan sabuk hutan/gerbang, kosong, bukan tanah olahan.
func can_place(id: String, origin: Vector2i, ignore: Dictionary = {}) -> bool:
	if not active():
		return false
	var astar: AStarGrid2D = world.get("astar") as AStarGrid2D
	var grid: PackedStringArray = world.get("grid") as PackedStringArray
	var gates: Dictionary = world.get("gates") as Dictionary
	var td: Dictionary = Game.tilled_of(FARM)
	var cells: Array[Vector2i] = cells_of(id, origin)
	if Game.item(id).has("hewan"):
		cells = [origin]
	var pc: Vector2i = world.call("_cell", (world.get("player") as Node2D).position) as Vector2i
	for c: Vector2i in cells:
		if not astar.region.has_point(c) or c.y < 1:
			return false
		var ch: String = grid[c.y][c.x]
		if ch == "#" or "<>^v".contains(ch) or gates.has(c):
			return false
		if td.has(c) or Game.crops.has(c):
			return false
		if occ.has(c) and occ[c] != ignore:
			return false
		if astar.is_point_solid(c) and not (occ.has(c) and occ[c] == ignore):
			return false
		if c == pc and not bool(Game.item(id).get("lewat", false)) and not Game.item(id).has("hewan"):
			return false
	return true


## Letakkan barang dari tas. Hasil: berhasil?
func place_new(id: String, origin: Vector2i) -> bool:
	if Game.count(id) <= 0 or not can_place(id, origin):
		return false
	Game.remove_item(id, 1)
	if Game.item(id).has("hewan"):
		var a: Dictionary = {"jenis": str(Game.item(id)["hewan"]), "age": 0, "pos": Vector2((origin.x + 0.5) * T, (origin.y + 1) * T - 4), "product": ""}
		Game.animals.append(a)
		_animal_node(a)
	else:
		var e: Dictionary = {"id": id, "cell": origin}
		Game.placed.append(e)
		_spawn(e)
	UIKit.sfx("gali", 1.3)
	_dust_at(pos_for(id, origin))
	return true


func move_to(e: Dictionary, origin: Vector2i) -> bool:
	if not can_place(str(e["id"]), origin, e):
		return false
	_despawn(e)
	e["cell"] = origin
	_spawn(e)
	UIKit.sfx("gali", 1.3)
	return true


## Simpan kembali ke tas.
func store(e: Dictionary) -> void:
	_despawn(e)
	Game.placed.erase(e)
	Game.add_item(str(e["id"]), 1)
	selected = {}
	UIKit.sfx("klik")


func entry_at(wp: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var by: float = -1e9
	for pn: Dictionary in placed_nodes:
		var e: Dictionary = pn["e"] as Dictionary
		var it: Dictionary = Game.item(str(e["id"]))
		var uk: Array = it["ukuran"] as Array
		var p: Vector2 = (pn["node"] as Node2D).position
		var r: Rect2 = Rect2(p.x - float(uk[0]) / 2.0, p.y - float(uk[1]), float(uk[0]), float(uk[1]))
		if r.has_point(wp) and p.y > by:   # paling depan (y terbesar) menang
			by = p.y
			best = e
	return best


# ---------------- Build mode ----------------
func set_build_mode(on: bool) -> void:
	build_mode = on and active()
	_cancel_ghost()
	selected = {}
	pressing = false
	panning = false
	var cam: Camera2D = world.get("cam") as Camera2D
	if not build_mode and cam != null:
		create_tween().tween_property(cam, "offset", Vector2.ZERO, 0.25)
	var hud: CanvasLayer = world.get("hud") as CanvasLayer
	if hud != null:
		hud.call("on_build_mode", build_mode)


## Mulai menyeret barang baru dari panel Build.
func begin_new(id: String) -> void:
	if not build_mode:
		return
	selected = {}
	_start_ghost(id, {})


func _start_ghost(id: String, from: Dictionary) -> void:
	ghost_id = id
	ghost_from = from
	var it: Dictionary = Game.item(id)
	if it.has("hewan"):
		var t: Texture2D = tex("res://assets/ternak/%s_bayi.png" % str(it["hewan"]))
		ghost_spr.texture = t
		var k: float = float((Game.ternak[str(it["hewan"])] as Dictionary)["k"])
		ghost_spr.scale = Vector2(k, k)
		ghost_spr.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	else:
		var sp: Sprite2D = _make_sprite(id)
		ghost_spr.texture = sp.texture
		ghost_spr.scale = sp.scale
		ghost_spr.offset = sp.offset
		sp.free()
	if not from.is_empty():
		for pn: Dictionary in placed_nodes:
			if pn["e"] == from:
				(pn["node"] as Node2D).modulate.a = 0.25
	ghost.visible = true


func _update_ghost(screen_pos: Vector2) -> void:
	var wp: Vector2 = world.get_canvas_transform().affine_inverse() * screen_pos
	var pc: Vector2i = world.call("_cell", wp) as Vector2i
	ghost_origin = pc if Game.item(ghost_id).has("hewan") else origin_for(ghost_id, pc)
	ghost_ok = can_place(ghost_id, ghost_origin, ghost_from)
	ghost.position = Vector2((ghost_origin.x + 0.5) * T, (ghost_origin.y + 1) * T) if Game.item(ghost_id).has("hewan") else pos_for(ghost_id, ghost_origin)
	ghost_spr.modulate = Color(1, 1, 1, 0.8) if ghost_ok else Color(1, 0.55, 0.55, 0.7)
	ghost.queue_redraw()


func _draw_ghost() -> void:
	if ghost_id == "":
		return
	var col: Color = Color(0.45, 1.0, 0.45, 0.35) if ghost_ok else Color(1.0, 0.35, 0.35, 0.35)
	var cells: Array[Vector2i] = cells_of(ghost_id, ghost_origin)
	if Game.item(ghost_id).has("hewan"):
		cells = [ghost_origin]
	for c: Vector2i in cells:
		var r: Rect2 = Rect2(Vector2(c.x * T, c.y * T) - ghost.position, Vector2(T, T))
		ghost.draw_rect(r.grow(-1.0), col)
		ghost.draw_rect(r.grow(-1.0), Color(col, 0.9), false, 1.0)


func _finish_ghost(screen_pos: Vector2) -> void:
	var hud: CanvasLayer = world.get("hud") as CanvasLayer
	var over_panel: bool = hud != null and bool(hud.call("over_build_panel", screen_pos))
	if not over_panel:
		_update_ghost(screen_pos)
		if ghost_from.is_empty():
			if not place_new(ghost_id, ghost_origin):
				world.call("show_toast", "Can't place here")
		elif not move_to(ghost_from, ghost_origin):
			world.call("show_toast", "Can't place here")
	_cancel_ghost()
	if hud != null:
		hud.call("refresh_build_panel")


func _cancel_ghost() -> void:
	for pn: Dictionary in placed_nodes:
		(pn["node"] as Node2D).modulate.a = 1.0
	ghost_id = ""
	ghost_from = {}
	if ghost != null:
		ghost.visible = false


func dragging() -> bool:
	return ghost_id != ""


## Seret barang baru (dimulai dari panel HUD): ikuti jari di mana pun, lepas = letakkan.
func _input(e: InputEvent) -> void:
	if not build_mode or ghost_id == "":
		return
	if e is InputEventMouseMotion:
		_update_ghost((e as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed:
		_finish_ghost((e as InputEventMouseButton).position)
		pressing = false
		get_viewport().set_input_as_handled()


## Input dunia saat Build mode: seret objek = pindah, seret kosong = geser kamera, ketuk objek = pilih.
func build_input(e: InputEvent) -> void:
	var cam: Camera2D = world.get("cam") as Camera2D
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb.pressed:
			pressing = true
			panning = false
			press_pos = mb.position
			press_obj = entry_at(world.get_canvas_transform().affine_inverse() * mb.position)
		else:
			if pressing and not panning and ghost_id == "":
				selected = press_obj
				var hud: CanvasLayer = world.get("hud") as CanvasLayer
				hud.call("show_selected", selected)
			pressing = false
			panning = false
	elif e is InputEventMouseMotion and pressing and ghost_id == "":
		var mm: InputEventMouseMotion = e as InputEventMouseMotion
		if not panning and mm.position.distance_to(press_pos) > 18.0:
			if not press_obj.is_empty():
				_start_ghost(str(press_obj["id"]), press_obj)
				_update_ghost(mm.position)
				return
			panning = true
		if panning:
			cam.offset -= mm.relative / cam.zoom.x
			_clamp_cam()


func _clamp_cam() -> void:
	var cam: Camera2D = world.get("cam") as Camera2D
	var pl: Node2D = world.get("player") as Node2D
	var vs: Vector2 = get_viewport_rect().size / cam.zoom.x
	var mw: float = float(world.get("mw")) * T
	var mh: float = float(world.get("mh")) * T
	var c: Vector2 = pl.position + cam.offset
	c.x = clampf(c.x, vs.x / 2.0, maxf(vs.x / 2.0, mw - vs.x / 2.0))
	c.y = clampf(c.y, vs.y / 2.0, maxf(vs.y / 2.0, mh - vs.y / 2.0))
	cam.offset = c - pl.position


# ---------------- tanaman ----------------
func plant(seed_id: String, c: Vector2i) -> bool:
	if not active() or not Game.tilled_of(FARM).has(c) or Game.crops.has(c) or Game.count(seed_id) <= 0:
		return false
	var crop: String = seed_id.trim_prefix("bibit_")
	if not Game.tanaman.has(crop):
		return false
	Game.remove_item(seed_id, 1)
	Game.crops[c] = {"id": crop, "days": 0}
	_crop_node(c)
	UIKit.sfx("gali", 1.5)
	return true


func _crop_node(c: Vector2i) -> void:
	if crop_nodes.has(c):
		(crop_nodes[c] as Node2D).queue_free()
	var cr: Dictionary = Game.crops[c] as Dictionary
	var t: Dictionary = Game.tanaman[str(cr["id"])] as Dictionary
	var st: Dictionary = (t["tahap"] as Array)[Game.crop_stage(cr)] as Dictionary
	var holder: Node2D = Node2D.new()
	holder.position = Vector2((c.x + 0.5) * T, (c.y + 1) * T - 3)
	var sp: Sprite2D = Sprite2D.new()
	sp.texture = tex(str(st["p"]))
	sp.centered = false
	var k: float = float(st["k"])
	sp.scale = Vector2(k, k)
	sp.offset = Vector2(-sp.texture.get_width() / 2.0, -sp.texture.get_height())
	holder.add_child(sp)
	if Game.crop_ready(cr):
		var tw: Tween = holder.create_tween().set_loops()
		tw.tween_property(sp, "modulate", Color(1.25, 1.25, 1.1), 0.7)
		tw.tween_property(sp, "modulate", Color.WHITE, 0.7)
	(world.get("ysort") as Node2D).add_child(holder)
	crop_nodes[c] = holder


func harvest(c: Vector2i) -> bool:
	if not Game.crops.has(c) or not Game.crop_ready(Game.crops[c] as Dictionary):
		return false
	var cr: Dictionary = Game.crops[c] as Dictionary
	var hasil: String = str((Game.tanaman[str(cr["id"])] as Dictionary)["hasil"])
	var n: int = 1 + (1 if randf() < 0.3 else 0)
	Game.add_item(hasil, n)
	Game.crops.erase(c)
	if crop_nodes.has(c):
		var node: Node2D = crop_nodes[c] as Node2D
		crop_nodes.erase(c)
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(node, "position:y", node.position.y - 20.0, 0.25)
		tw.tween_property(node, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(node.queue_free)
	UIKit.sfx("tangkap")
	world.call("show_toast", "+%d %s" % [n, str(Game.item(hasil)["nama"])])
	return true


func _on_new_day() -> void:
	if not active():
		return
	for cv: Variant in Game.crops.keys():
		_crop_node(cv as Vector2i)
	for an: Dictionary in animal_nodes:
		_animal_look(an, Vector2.ZERO)


# ---------------- ternak ----------------
func _animal_node(a: Dictionary) -> void:
	var holder: Node2D = Node2D.new()
	holder.position = a["pos"] as Vector2
	var sp: Sprite2D = Sprite2D.new()
	sp.centered = false
	holder.add_child(sp)
	var bub: Sprite2D = Sprite2D.new()
	bub.z_index = 20
	holder.add_child(bub)
	(world.get("ysort") as Node2D).add_child(holder)
	var an: Dictionary = {"a": a, "node": holder, "spr": sp, "bubble": bub, "target": holder.position, "wait": randf_range(0.5, 3.0)}
	animal_nodes.append(an)
	_animal_look(an, Vector2.ZERO)


func _animal_look(an: Dictionary, vel: Vector2) -> void:
	var a: Dictionary = an["a"] as Dictionary
	var j: String = str(a["jenis"])
	var view: String = "bayi"
	var flip: bool = false
	if Game.is_adult(a):
		if Game.is_night():
			view = "duduk"
		elif vel.length() < 0.1:
			view = "depan"
		elif absf(vel.x) > absf(vel.y):
			view = "samping"
			flip = vel.x > 0.0
		else:
			view = "depan" if vel.y > 0.0 else "belakang"
	else:
		flip = vel.x > 0.0
	var sp: Sprite2D = an["spr"] as Sprite2D
	var t: Texture2D = tex("res://assets/ternak/%s_%s.png" % [j, view])
	if sp.texture != t:
		sp.texture = t
		var k: float = float((Game.ternak[j] as Dictionary)["k"])
		sp.scale = Vector2(k, k)
		sp.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	sp.flip_h = flip
	var bub: Sprite2D = an["bubble"] as Sprite2D
	var pr: String = str(a.get("product", ""))
	bub.visible = pr != ""
	if pr != "":
		var it: Texture2D = Game.item_icon(pr)
		bub.texture = it
		bub.scale = Vector2(16.0, 16.0) / it.get_size()
		bub.position = Vector2(0, -float(t.get_height()) * sp.scale.y - 12.0)


func _process(delta: float) -> void:
	if not active() or animal_nodes.is_empty():
		return
	var astar: AStarGrid2D = world.get("astar") as AStarGrid2D
	var night: bool = Game.is_night()
	for an: Dictionary in animal_nodes:
		var node: Node2D = an["node"] as Node2D
		var a: Dictionary = an["a"] as Dictionary
		var bub: Sprite2D = an["bubble"] as Sprite2D
		if bub.visible:
			bub.position.y += sin(Time.get_ticks_msec() / 300.0) * 0.08
		if night:
			_animal_look(an, Vector2.ZERO)
			continue
		an["wait"] = float(an["wait"]) - delta
		if float(an["wait"]) > 0.0:
			continue
		var tgt: Vector2 = an["target"] as Vector2
		var to: Vector2 = tgt - node.position
		var spd: float = ANIM_SPEED * (1.0 if Game.is_adult(a) else 1.3)
		if to.length() <= spd * delta:
			node.position = tgt
			an["wait"] = randf_range(1.5, 5.0)
			_animal_look(an, Vector2.ZERO)
			var c0: Vector2i = world.call("_cell", tgt) as Vector2i
			for k: int in range(12):
				var c: Vector2i = c0 + Vector2i(randi_range(-4, 4), randi_range(-3, 3))
				if astar.region.has_point(c) and not astar.is_point_solid(c) and str((world.get("grid") as PackedStringArray)[c.y][c.x]) != "#" and not (world.get("gates") as Dictionary).has(c):
					an["target"] = Vector2((c.x + 0.5) * T + randf_range(-8, 8), (c.y + 1) * T - 4)
					break
		else:
			var v: Vector2 = to.normalized() * spd
			node.position += v * delta
			_animal_look(an, v)
		a["pos"] = node.position


func animal_at(wp: Vector2) -> Dictionary:
	for an: Dictionary in animal_nodes:
		var node: Node2D = an["node"] as Node2D
		var sp: Sprite2D = an["spr"] as Sprite2D
		if sp.texture == null:
			continue
		var sz: Vector2 = sp.texture.get_size() * sp.scale
		if Rect2(node.position.x - sz.x / 2.0 - 4.0, node.position.y - sz.y - 4.0, sz.x + 8.0, sz.y + 8.0).has_point(wp):
			return an
	return {}


func collect(an: Dictionary) -> void:
	var a: Dictionary = an["a"] as Dictionary
	var pr: String = str(a.get("product", ""))
	var nm: String = str((Game.ternak[str(a["jenis"])] as Dictionary)["nama"])
	if pr == "":
		var node: Node2D = an["node"] as Node2D
		var tw: Tween = create_tween()
		tw.tween_property(node, "scale", Vector2(1.1, 0.9), 0.1)
		tw.tween_property(node, "scale", Vector2.ONE, 0.15)
		if Game.is_adult(a):
			world.call("show_toast", "%s is happy! Come back tomorrow" % nm)
		else:
			var left: int = int((Game.ternak[str(a["jenis"])] as Dictionary)["dewasa"]) - int(a["age"])
			world.call("show_toast", "Baby %s - grows up in %d day%s" % [nm, left, "" if left == 1 else "s"])
		return
	Game.add_item(pr, 1)
	a["product"] = ""
	_animal_look(an, Vector2.ZERO)
	UIKit.sfx("tangkap")
	world.call("show_toast", "+1 %s" % str(Game.item(pr)["nama"]))


func _dust_at(p: Vector2) -> void:
	if world.has_method("_dust"):
		world.call("_dust", p, Color("#C9A36B"))


# ---------------- ketukan biasa (bukan Build mode) ----------------
## Hasil true bila ketukan ditangani Farm (ternak, panen, tanam).
func tap(wp: Vector2) -> bool:
	if not active():
		return false
	var pl: Node2D = world.get("player") as Node2D
	var an: Dictionary = animal_at(wp)
	if not an.is_empty():
		if pl.position.distance_to((an["node"] as Node2D).position) <= 1.8 * T:
			collect(an)
		else:
			world.call("walk_to", world.call("_cell", (an["node"] as Node2D).position), {"type": "farm", "wp": wp})
		return true
	var c: Vector2i = world.call("_cell", wp) as Vector2i
	var near: bool = pl.position.distance_to(Vector2((c.x + 0.5) * T, (c.y + 0.5) * T)) <= 1.8 * T
	if Game.crops.has(c):
		var cr: Dictionary = Game.crops[c] as Dictionary
		if Game.crop_ready(cr):
			if near:
				harvest(c)
			else:
				world.call("walk_to", c, {"type": "farm", "wp": wp})
			return true
		var held: String = Game.held_tool()
		if held == "" or held == "jaring" or held == "pedang":
			var t: Dictionary = Game.tanaman[str(cr["id"])] as Dictionary
			var wet: bool = bool((Game.tilled_of(FARM).get(c, {}) as Dictionary).get("wet", false))
			world.call("show_toast", "%s  %d/%d days%s" % [str(t["nama"]), int(cr["days"]), int(t["hari"]), "" if wet else " - needs water"])
			return true
		return false
	var item: String = Game.held_item()
	if Game.is_seed(item) and Game.tilled_of(FARM).has(c):
		if near:
			if not plant(item, c):
				world.call("show_toast", "Can't plant here")
		else:
			world.call("walk_to", c, {"type": "farm", "wp": wp})
		return true
	if Game.is_seed(item):
		world.call("show_toast", "Sow seeds on tilled soil (use the Hoe)")
		return true
	return false


## Setelah berjalan mendekat.
func arrived(wp: Vector2) -> void:
	var an: Dictionary = animal_at(wp)
	if not an.is_empty():
		collect(an)
		return
	var c: Vector2i = world.call("_cell", wp) as Vector2i
	if Game.crops.has(c):
		harvest(c)
	elif Game.is_seed(Game.held_item()):
		plant(Game.held_item(), c)
