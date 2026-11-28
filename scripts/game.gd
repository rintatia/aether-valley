extends Node
## Autoload "Game": karakter pilihan, waktu & musim, koin, kristal, isi tas.

const DAY_SECONDS: float = 300.0          # 1 hari permainan = 5 menit nyata
const START_MINUTE: float = 6.0 * 60.0    # mulai jam 06:00
const SEASON_DAYS: int = 28
const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const WEEKDAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const BAG_PAGES: int = 10
const BAG_PER_PAGE: int = 25
var ITEMS: Dictionary = {
	"kayu": {"nama": "Wood", "ikon": "res://assets/ui/item_kayu.png", "tumpuk": 999},
	"kupu": {"nama": "Butterfly", "ikon": "res://assets/ui/item_kupu.png", "tumpuk": 99},
	"batu": {"nama": "Stone", "ikon": "res://assets/ui/item_batu.png", "tumpuk": 999},
	"cangkul": {"nama": "Hoe", "ikon": "res://assets/ui/alat_cangkul.png", "tumpuk": 1, "alat": true},
	"penyiram": {"nama": "Watering Can", "ikon": "res://assets/ui/alat_penyiram.png", "tumpuk": 1, "alat": true},
	"sekop": {"nama": "Trowel", "ikon": "res://assets/ui/alat_sekop.png", "tumpuk": 1, "alat": true},
	"arit": {"nama": "Sickle", "ikon": "res://assets/ui/alat_arit.png", "tumpuk": 1, "alat": true},
	"pisau": {"nama": "Knife", "ikon": "res://assets/ui/alat_pisau.png", "tumpuk": 1, "alat": true},
	"kapak": {"nama": "Axe", "ikon": "res://assets/ui/alat_kapak.png", "tumpuk": 1, "alat": true},
	"beliung": {"nama": "Pickaxe", "ikon": "res://assets/ui/alat_beliung.png", "tumpuk": 1, "alat": true},
	"pedang": {"nama": "Sword", "ikon": "res://assets/ui/alat_pedang.png", "tumpuk": 1, "alat": true},
	"jaring": {"nama": "Bug Net", "ikon": "res://assets/ui/alat_jaring.png", "tumpuk": 1, "alat": true},
	"pancing": {"nama": "Fishing Rod", "ikon": "res://assets/ui/alat_pancing.png", "tumpuk": 1, "alat": true},
}
const START_TOOLS: Array[String] = ["cangkul", "penyiram", "sekop", "arit", "pisau", "kapak", "beliung", "pedang", "jaring", "pancing"]
## tema warna isi bingkai/panel (nama -> warna). "Peach" = warna dasar kotak day.date
const THEMES: Dictionary = {
	"Peach": Color("#FADCBD"), "Cream": Color("#FBEEE3"), "Mint": Color("#D8EDCF"),
	"Sky": Color("#D3E6F3"), "Lavender": Color("#E4DAF3"), "Rose": Color("#F7D6DC"),
}
const SPEEDS: Dictionary = {"Slow": 0.75, "Normal": 1.0, "Fast": 1.35}
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 1

# karakter
var gender: String = "cowok"
var player_name: String = "Farmer"
var colors: Dictionary = {}               # part -> Color (kosong = warna asli)

# waktu
var day: int = 1                          # hari ke- sejak awal (1..)
var minute: float = START_MINUTE          # menit dalam hari (0..1440)
var raining: bool = false

# uang & tas
const START_COINS: int = 1000000
const START_CRYSTALS: int = 10000
var coins: int = START_COINS
var crystals: int = START_CRYSTALS
var bag: Array = []                       # BAG_PAGES * BAG_PER_PAGE slot: {} atau {"id":..,"n":..}
var selected_slot: int = 0               # -1 = tangan kosong

# pengaturan (tersimpan di user://settings.cfg)
var volume: float = 0.8
var speed_name: String = "Normal"
var theme_name: String = "Peach"

# tanah olahan per peta: map_id -> {Vector2i: {"wet": bool}}
var tilled: Dictionary = {}

# katalog (data/katalog.json): items (bangunan, pagar, dekor, alam, bibit, hasil, ternak), tanaman, ternak, resep
var katalog: Dictionary = {}
var tanaman: Dictionary = {}
var ternak: Dictionary = {}
var resep: Array = []
# objek yang dipasang di Farm (Build mode): [{"id", "cell": Vector2i}]
var placed: Array = []
# tanaman di tanah olahan Farm: Vector2i -> {"id": jenis, "days": hari tumbuh}
var crops: Dictionary = {}
# ternak di Farm: [{"jenis", "age", "pos": Vector2, "product": "" / id hasil}]
var animals: Array = []

signal day_changed
signal bag_changed


func _ready() -> void:
	bag.resize(BAG_PAGES * BAG_PER_PAGE)
	for i: int in range(bag.size()):
		bag[i] = {}
	_roll_weather()
	load_settings()
	_load_katalog()


func _load_katalog() -> void:
	var j: JSON = load("res://data/katalog.json") as JSON
	if j == null:
		return
	katalog = j.data as Dictionary
	tanaman = katalog["tanaman"] as Dictionary
	ternak = katalog["ternak"] as Dictionary
	resep = katalog["resep"] as Array
	for k: String in (katalog["items"] as Dictionary).keys():
		ITEMS[k] = (katalog["items"] as Dictionary)[k]


func new_game() -> void:
	for i: int in range(bag.size()):
		bag[i] = {}
	for i: int in range(START_TOOLS.size()):
		bag[i] = {"id": START_TOOLS[i], "n": 1}
	selected_slot = 0
	tilled = {}
	resume_map = ""
	resume_pos = Vector2(-1, -1)
	placed = []
	crops = {}
	animals = []
	day = 1
	minute = START_MINUTE
	coins = START_COINS
	crystals = START_CRYSTALS
	_roll_weather()
	bag_changed.emit()


# ---------------- simpan / muat (lokal di perangkat) ----------------
## Dipakai world saat memuat permainan tersimpan: peta & posisi pemain terakhir.
var resume_map: String = ""
var resume_pos: Vector2 = Vector2(-1, -1)
var last_saved_unix: int = 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _cell_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _key_cell(k: String) -> Vector2i:
	var p: PackedStringArray = k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


## Simpan seluruh progres. map_id & pos = peta dan posisi pemain sekarang.
func save_game(map_id: String, pos: Vector2) -> bool:
	var td: Dictionary = {}
	for mid: Variant in tilled.keys():
		var m: Dictionary = {}
		for cv: Variant in (tilled[mid] as Dictionary).keys():
			m[_cell_key(cv as Vector2i)] = bool(((tilled[mid] as Dictionary)[cv] as Dictionary).get("wet", false))
		td[str(mid)] = m
	var pl: Array = []
	for ev: Variant in placed:
		var e: Dictionary = ev as Dictionary
		pl.append({"id": str(e["id"]), "c": _cell_key(e["cell"] as Vector2i)})
	var cr: Dictionary = {}
	for cv: Variant in crops.keys():
		var c: Dictionary = crops[cv] as Dictionary
		cr[_cell_key(cv as Vector2i)] = {"id": str(c["id"]), "days": int(c["days"])}
	var an: Array = []
	for av: Variant in animals:
		var a: Dictionary = av as Dictionary
		var ap: Vector2 = a["pos"] as Vector2
		an.append({"jenis": str(a["jenis"]), "age": int(a["age"]), "x": ap.x, "y": ap.y, "product": str(a.get("product", ""))})
	var data: Dictionary = {
		"v": SAVE_VERSION, "time": int(Time.get_unix_time_from_system()),
		"gender": gender, "name": player_name, "day": day, "minute": minute, "raining": raining,
		"coins": coins, "crystals": crystals, "bag": bag, "slot": selected_slot,
		"tilled": td, "placed": pl, "crops": cr, "animals": an,
		"map": map_id, "px": pos.x, "py": pos.y,
	}
	var tmp: String = SAVE_PATH + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	# tulis ke berkas sementara dulu lalu ganti nama -> berkas simpan tidak rusak bila aplikasi tertutup di tengah jalan
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null or dir.rename(tmp.get_file(), SAVE_PATH.get_file()) != OK:
		return false
	last_saved_unix = int(data["time"])
	return true


## Muat progres tersimpan. Hasil: berhasil?
func load_game() -> bool:
	if not has_save():
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not parsed is Dictionary:
		return false
	var d: Dictionary = parsed as Dictionary
	new_game()
	gender = str(d.get("gender", gender))
	player_name = str(d.get("name", player_name))
	day = int(d.get("day", 1))
	minute = float(d.get("minute", START_MINUTE))
	raining = bool(d.get("raining", false))
	coins = int(d.get("coins", START_COINS))
	crystals = int(d.get("crystals", START_CRYSTALS))
	var b: Array = d.get("bag", []) as Array
	for i: int in range(bag.size()):
		bag[i] = {}
		if i < b.size() and b[i] is Dictionary and not (b[i] as Dictionary).is_empty():
			var it: Dictionary = b[i] as Dictionary
			if ITEMS.has(str(it.get("id", ""))):
				bag[i] = {"id": str(it["id"]), "n": int(it.get("n", 1))}
	selected_slot = int(d.get("slot", 0))
	tilled = {}
	var td: Dictionary = d.get("tilled", {}) as Dictionary
	for mid: String in td.keys():
		var m: Dictionary = {}
		for k: String in (td[mid] as Dictionary).keys():
			m[_key_cell(k)] = {"wet": bool((td[mid] as Dictionary)[k])}
		tilled[mid] = m
	placed = []
	for ev: Variant in d.get("placed", []) as Array:
		var e: Dictionary = ev as Dictionary
		if ITEMS.has(str(e.get("id", ""))):
			placed.append({"id": str(e["id"]), "cell": _key_cell(str(e["c"]))})
	crops = {}
	var cr: Dictionary = d.get("crops", {}) as Dictionary
	for k2: String in cr.keys():
		var c: Dictionary = cr[k2] as Dictionary
		if tanaman.has(str(c.get("id", ""))):
			crops[_key_cell(k2)] = {"id": str(c["id"]), "days": int(c.get("days", 0))}
	animals = []
	for av: Variant in d.get("animals", []) as Array:
		var a: Dictionary = av as Dictionary
		if ternak.has(str(a.get("jenis", ""))):
			animals.append({"jenis": str(a["jenis"]), "age": int(a.get("age", 0)), "pos": Vector2(float(a.get("x", 0)), float(a.get("y", 0))),
				"product": str(a.get("product", ""))})
	resume_map = str(d.get("map", "ladang"))
	resume_pos = Vector2(float(d.get("px", -1)), float(d.get("py", -1)))
	last_saved_unix = int(d.get("time", 0))
	bag_changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------- pengaturan ----------------
func load_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		volume = clampf(float(cf.get_value("game", "volume", volume)), 0.0, 1.0)
		speed_name = str(cf.get_value("game", "speed", speed_name))
		theme_name = str(cf.get_value("game", "theme", theme_name))
	if not SPEEDS.has(speed_name):
		speed_name = "Normal"
	if not THEMES.has(theme_name):
		theme_name = "Peach"
	apply_volume()


func save_settings() -> void:
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("game", "volume", volume)
	cf.set_value("game", "speed", speed_name)
	cf.set_value("game", "theme", theme_name)
	cf.save(SETTINGS_PATH)


func apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func set_volume(v: float) -> void:
	volume = clampf(snappedf(v, 0.1), 0.0, 1.0)
	apply_volume()
	save_settings()


func speed_mult() -> float:
	return float(SPEEDS[speed_name])


func theme_color() -> Color:
	return THEMES[theme_name] as Color


# ---------------- waktu ----------------
func tick(delta: float) -> void:
	minute += delta * 1440.0 / DAY_SECONDS
	if minute >= 1440.0:
		minute -= 1440.0
		day += 1
		new_day()
		day_changed.emit()


## Hari baru: tanaman yang kemarin disiram (atau kena hujan) tumbuh 1 hari; ternak bertambah umur & menghasilkan.
func new_day() -> void:
	var farm: Dictionary = tilled_of("ladang")
	for cv: Variant in crops.keys():
		var cr: Dictionary = crops[cv] as Dictionary
		if raining or bool((farm.get(cv, {}) as Dictionary).get("wet", false)):
			cr["days"] = int(cr["days"]) + 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = day * 31337
	for av: Variant in animals:
		var a: Dictionary = av as Dictionary
		a["age"] = int(a["age"]) + 1
		if is_adult(a) and str(a.get("product", "")) == "":
			a["product"] = _roll_product(str(a["jenis"]), rng)
	_roll_weather()
	# tanah yang disiram kering lagi di hari baru
	for mp: Variant in tilled.values():
		for cv: Variant in (mp as Dictionary).values():
			(cv as Dictionary)["wet"] = raining


func hour() -> int:
	return int(minute / 60.0) % 24


func clock_text() -> String:
	return "%02d:%02d" % [hour(), int(minute) % 60]


func season_index() -> int:
	return int((day - 1) / SEASON_DAYS) % 4


func season_name() -> String:
	return SEASONS[season_index()]


func date_in_season() -> int:
	return (day - 1) % SEASON_DAYS + 1


func date_text() -> String:
	return "%s . %d" % [WEEKDAYS[(day - 1) % 7], date_in_season()]


func status_text() -> String:
	## isi kotak status: Spring / Summer / Autumn / Winter / Rainy
	return "Rainy" if raining else season_name()


func is_night() -> bool:
	return minute >= 18.0 * 60.0 or minute < 6.0 * 60.0


## warna suasana untuk CanvasModulate (lembut, tidak muram)
func ambient() -> Color:
	var h: float = minute / 60.0
	var dayc: Color = Color(1, 1, 1)
	var dusk: Color = Color(0.96, 0.78, 0.66)
	var night: Color = Color(0.40, 0.45, 0.70)   # malam gelap kebiruan, tetap terlihat
	var c: Color
	if h >= 6.0 and h < 17.0:
		c = dayc
	elif h >= 17.0 and h < 19.0:
		c = dayc.lerp(dusk, (h - 17.0) / 2.0)
	elif h >= 19.0 and h < 21.0:
		c = dusk.lerp(night, (h - 19.0) / 2.0)
	elif h >= 21.0 or h < 4.5:
		c = night
	else:
		c = night.lerp(dayc, (h - 4.5) / 1.5)
	if raining:
		c = c * Color(0.9, 0.92, 0.98)
	return c


func _roll_weather() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = day * 7919 + 13
	raining = season_index() != 3 and r.randf() < 0.2


# ---------------- tas ----------------
func add_item(id: String, n: int) -> int:
	var left: int = n
	var stack: int = int((ITEMS[id] as Dictionary).get("tumpuk", 99))
	for i: int in range(bag.size()):
		var s: Dictionary = bag[i] as Dictionary
		if not s.is_empty() and str(s["id"]) == id and int(s["n"]) < stack:
			var put: int = mini(left, stack - int(s["n"]))
			s["n"] = int(s["n"]) + put
			left -= put
			if left == 0:
				break
	if left > 0:
		for i: int in range(bag.size()):
			if (bag[i] as Dictionary).is_empty():
				var put2: int = mini(left, stack)
				bag[i] = {"id": id, "n": put2}
				left -= put2
				if left == 0:
					break
	bag_changed.emit()
	return n - left


func count(id: String) -> int:
	var total: int = 0
	for s: Variant in bag:
		var d: Dictionary = s as Dictionary
		if not d.is_empty() and str(d["id"]) == id:
			total += int(d["n"])
	return total


func is_tool(id: String) -> bool:
	return ITEMS.has(id) and bool((ITEMS[id] as Dictionary).get("alat", false))


## Alat yang sedang dipegang (slot terpilih), "" bila tangan kosong / bukan alat.
func held_tool() -> String:
	if selected_slot < 0 or selected_slot >= bag.size():
		return ""
	var s: Dictionary = bag[selected_slot] as Dictionary
	if s.is_empty() or not is_tool(str(s["id"])):
		return ""
	return str(s["id"])


func tilled_of(map_id: String) -> Dictionary:
	if not tilled.has(map_id):
		tilled[map_id] = {}
	return tilled[map_id] as Dictionary


# ---------------- katalog, tanam, ternak ----------------
func item(id: String) -> Dictionary:
	return ITEMS.get(id, {}) as Dictionary


func is_placeable(id: String) -> bool:
	return item(id).has("gambar") or item(id).has("hewan")


func is_seed(id: String) -> bool:
	return id.begins_with("bibit_")


## Barang yang sedang dipegang (slot terpilih), "" bila kosong.
func held_item() -> String:
	if selected_slot < 0 or selected_slot >= bag.size():
		return ""
	var s: Dictionary = bag[selected_slot] as Dictionary
	return "" if s.is_empty() else str(s["id"])


func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left: int = n
	for i: int in range(bag.size() - 1, -1, -1):
		var s: Dictionary = bag[i] as Dictionary
		if not s.is_empty() and str(s["id"]) == id:
			var take: int = mini(left, int(s["n"]))
			s["n"] = int(s["n"]) - take
			left -= take
			if int(s["n"]) <= 0:
				bag[i] = {}
			if left == 0:
				break
	bag_changed.emit()
	return true


## Beli dari Shop: bayar koin atau kristal. Hasil: "" (berhasil) atau alasan gagal.
func buy(id: String, n: int = 1) -> String:
	var it: Dictionary = item(id)
	var kr: int = int(it.get("kristal", 0)) * n
	var co: int = int(it.get("harga", 0)) * n
	if kr <= 0 and co <= 0:
		return "Not for sale"
	if kr > crystals or co > coins:
		return "Not enough " + ("crystals" if kr > crystals else "coins")
	if add_item(id, n) < n:
		return "Bag is full"
	crystals -= kr
	coins -= co
	return ""


func sell(id: String, n: int = 1) -> int:
	var price: int = int(item(id).get("jual", 0))
	if price <= 0 or not remove_item(id, n):
		return 0
	coins += price * n
	return price * n


func crop_stage(cr: Dictionary) -> int:
	var t: Dictionary = tanaman[str(cr["id"])] as Dictionary
	var n: int = (t["tahap"] as Array).size()
	if int(cr["days"]) >= int(t["hari"]):
		return n - 1
	return clampi(int(float(cr["days"]) / float(t["hari"]) * float(n - 1)), 0, n - 2)


func crop_ready(cr: Dictionary) -> bool:
	return int(cr["days"]) >= int((tanaman[str(cr["id"])] as Dictionary)["hari"])


func is_adult(a: Dictionary) -> bool:
	return int(a["age"]) >= int((ternak[str(a["jenis"])] as Dictionary)["dewasa"])


func _roll_product(jenis: String, rng: RandomNumberGenerator) -> String:
	var r: float = rng.randf()
	match jenis:
		"cow":
			return "milk_pail" if r < 0.1 else "milk"
		"chicken":
			return "golden_egg" if r < 0.03 else ("large_egg" if r < 0.13 else ("brown_egg" if r < 0.55 else "egg"))
		"duck":
			return "feather" if r < 0.2 else "duck_egg"
		"goose":
			return "down" if r < 0.1 else ("goose_feather" if r < 0.25 else ("quail_egg" if r < 0.35 else "goose_egg"))
		"sheep":
			return "fine_wool" if r < 0.15 else "wool"
	return ""


func can_cook(r: Dictionary) -> bool:
	for k: String in (r["bahan"] as Dictionary).keys():
		if count(k) < int((r["bahan"] as Dictionary)[k]):
			return false
	return r.has("hasil")


func cook(r: Dictionary) -> bool:
	if not can_cook(r):
		return false
	for k: String in (r["bahan"] as Dictionary).keys():
		remove_item(k, int((r["bahan"] as Dictionary)[k]))
	add_item(str(r["hasil"]), 1)
	return true


func item_icon(id: String) -> Texture2D:
	var it: Dictionary = item(id)
	return UIKit.mip_tex(str(it.get("ikon", it.get("gambar", ""))))


# ---------------- karakter ----------------
func char_meta() -> Dictionary:
	var j: JSON = load("res://assets/karakter_v7/karakter.json") as JSON
	return (j.data as Dictionary)[gender] as Dictionary


## ShaderMaterial pewarna ulang karakter (ukuran: "besar" / "kecil")
func char_material(size: String) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://scripts/char_recolor.gdshader") as Shader
	apply_colors(m, size)
	return m


func apply_colors(m: ShaderMaterial, size: String) -> void:
	var meta: Dictionary = char_meta()
	var asli: Dictionary = meta["warna_asli"] as Dictionary
	var mean: Dictionary = meta["mean"] as Dictionary
	m.set_shader_parameter("maskA", load("res://assets/karakter_v7/%s_%s_maskA.png" % [gender, size]))
	m.set_shader_parameter("maskB", load("res://assets/karakter_v7/%s_%s_maskB.png" % [gender, size]))
	for part: String in ["hair", "shirt", "pants", "boots", "skin"]:
		var c: Color = colors.get(part, Color(str(asli[part]))) as Color
		m.set_shader_parameter("c_" + part, c)
		m.set_shader_parameter("mean_" + part, float(mean[part]))
		m.set_shader_parameter("ref_" + part, Color(str(asli[part])))


func char_texture(size: String) -> Texture2D:
	return load("res://assets/karakter_v7/%s_%s.png" % [gender, size]) as Texture2D
