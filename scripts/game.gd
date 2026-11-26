extends Node
## Autoload "Game": state, simpan/muat, aturan tanam & dagang.

const DAY_LEN: float = 300.0  # 1 hari = 5 menit nyata
const SAVE_PATH: String = "user://aether_v6.json"
const OUTFITS: Array[String] = ["#D8574F", "#2480BE", "#4E912F", "#9C8CF0", "#E0B83C", "#F37CAB"]

var items: Dictionary = {}
var crops: Dictionary = {}
var s: Dictionary = {}


func _ready() -> void:
	items = load_json("res://data/items.json")
	crops = load_json("res://data/crops.json")


func load_json(p: String) -> Dictionary:
	var j: JSON = load(p) as JSON
	if j != null and j.data is Dictionary:
		return j.data as Dictionary
	return {}


func new_game(pname: String, color_i: int, farm_type: String) -> void:
	s = {
		"name": pname, "color": color_i, "farm": farm_type,
		"gold": 100, "day": 1, "t": 0.0, "max_stam": 100, "stam": 100.0,
		"inv": {"item_turnip_seed": 8, "item_wheat_seed": 4},
		"plots": {}, "loc": "farm", "px": -1.0, "py": -1.0,
	}
	if farm_type == "padang":
		add_item("item_carrot_seed", 6)
	elif farm_type == "hutan":
		s["gold"] = 250
	elif farm_type == "sungai":
		s["max_stam"] = 130
		s["stam"] = 130.0


# ---------- inventori ----------
func count(id: String) -> int:
	return int((s["inv"] as Dictionary).get(id, 0))


func add_item(id: String, n: int) -> void:
	var inv: Dictionary = s["inv"] as Dictionary
	inv[id] = int(inv.get(id, 0)) + n
	if int(inv[id]) <= 0:
		inv.erase(id)


func gold() -> int:
	return int(s["gold"])


func use_stam(c: float) -> bool:
	if float(s["stam"]) < c:
		return false
	s["stam"] = float(s["stam"]) - c
	return true


func buy(id: String) -> bool:
	var price: int = int((items[id] as Dictionary)["price"])
	if gold() < price:
		return false
	s["gold"] = gold() - price
	add_item(id, 1)
	return true


func sell(id: String, n: int) -> int:
	var have: int = mini(n, count(id))
	if have <= 0:
		return 0
	var earned: int = have * int((items[id] as Dictionary)["sell"])
	add_item(id, -have)
	s["gold"] = gold() + earned
	return earned


# ---------- ladang ----------
func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func plot(cell: Vector2i) -> Dictionary:
	var plots: Dictionary = s["plots"] as Dictionary
	if plots.has(key(cell)):
		return plots[key(cell)] as Dictionary
	return {}


func is_ready(p: Dictionary) -> bool:
	var cid: String = str(p.get("crop", ""))
	if cid == "":
		return false
	return int(p.get("grown", 0)) >= int((crops[cid] as Dictionary)["days"])


func till(cell: Vector2i) -> bool:
	if not plot(cell).is_empty() or not use_stam(3.0):
		return false
	(s["plots"] as Dictionary)[key(cell)] = {"crop": "", "grown": 0, "wet": false}
	return true


func plant(cell: Vector2i, seed_id: String) -> bool:
	var p: Dictionary = plot(cell)
	if p.is_empty() or str(p["crop"]) != "" or count(seed_id) <= 0:
		return false
	if not use_stam(1.0):
		return false
	add_item(seed_id, -1)
	p["crop"] = str((items[seed_id] as Dictionary)["crop"])
	p["grown"] = 0
	p["wet"] = false
	return true


func water(cell: Vector2i) -> bool:
	var p: Dictionary = plot(cell)
	if p.is_empty() or str(p["crop"]) == "" or bool(p["wet"]) or is_ready(p):
		return false
	if not use_stam(2.0):
		return false
	p["wet"] = true
	return true


func harvest(cell: Vector2i) -> bool:
	var p: Dictionary = plot(cell)
	if not is_ready(p) or not use_stam(1.0):
		return false
	var cid: String = str(p["crop"])
	add_item(str((crops[cid] as Dictionary)["item"]), 1)
	p["crop"] = ""
	p["grown"] = 0
	p["wet"] = false
	return true


func next_day() -> void:
	var plots: Dictionary = s["plots"] as Dictionary
	for k: String in plots.keys():
		var p: Dictionary = plots[k] as Dictionary
		if str(p["crop"]) != "" and bool(p["wet"]):
			p["grown"] = int(p["grown"]) + 1
		p["wet"] = false
	s["day"] = int(s["day"]) + 1
	s["t"] = 0.0
	s["stam"] = float(s["max_stam"])


# ---------- simpan ----------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(s))


func load_game() -> bool:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var v: Variant = JSON.parse_string(f.get_as_text())
	if v is Dictionary and (v as Dictionary).has("inv"):
		s = v as Dictionary
		return true
	return false
