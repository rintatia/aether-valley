extends Node
## Autoload "Game": karakter pilihan, waktu & musim, koin, kristal, isi tas.

const DAY_SECONDS: float = 300.0          # 1 hari permainan = 5 menit nyata
const START_MINUTE: float = 6.0 * 60.0    # mulai jam 06:00
const SEASON_DAYS: int = 28
const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const WEEKDAYS: Array[String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const BAG_PAGES: int = 10
const BAG_PER_PAGE: int = 25
const ITEMS: Dictionary = {
	"kayu": {"nama": "Wood", "ikon": "res://assets/ui/item_kayu.png", "tumpuk": 999},
}

# karakter
var gender: String = "cowok"
var player_name: String = "Farmer"
var colors: Dictionary = {}               # part -> Color (kosong = warna asli)

# waktu
var day: int = 1                          # hari ke- sejak awal (1..)
var minute: float = START_MINUTE          # menit dalam hari (0..1440)
var raining: bool = false

# uang & tas
var coins: int = 500
var crystals: int = 0
var bag: Array = []                       # BAG_PAGES * BAG_PER_PAGE slot: {} atau {"id":..,"n":..}
var selected_slot: int = 0

signal day_changed
signal bag_changed


func _ready() -> void:
	bag.resize(BAG_PAGES * BAG_PER_PAGE)
	for i: int in range(bag.size()):
		bag[i] = {}
	_roll_weather()


# ---------------- waktu ----------------
func tick(delta: float) -> void:
	minute += delta * 1440.0 / DAY_SECONDS
	if minute >= 1440.0:
		minute -= 1440.0
		day += 1
		_roll_weather()
		day_changed.emit()


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
	var dusk: Color = Color(1.0, 0.86, 0.74)
	var night: Color = Color(0.70, 0.74, 0.92)
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
	var stack: int = int((ITEMS[id] as Dictionary)["tumpuk"])
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


func item_icon(id: String) -> Texture2D:
	return load(str((ITEMS[id] as Dictionary)["ikon"])) as Texture2D


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
