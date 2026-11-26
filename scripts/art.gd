extends Node
## Autoload "Art": memuat aset dari res://assets/ sesuai data/assets.json.
## Kalau file belum ada, dibuatkan kotak warna polos seukuran aset (placeholder).

var reg: Dictionary = {}
var _cache: Dictionary = {}
var missing: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reg = load_json("res://data/assets.json")


func load_json(p: String) -> Dictionary:
	var j: JSON = load(p) as JSON
	if j != null and j.data is Dictionary:
		return j.data as Dictionary
	return {}


func info(key: String) -> Dictionary:
	if reg.has(key):
		return reg[key] as Dictionary
	return {}


func size_of(key: String) -> Vector2i:
	var s: Array = info(key).get("size", [16, 16]) as Array
	return Vector2i(int(s[0]), int(s[1]))


func has_file(key: String) -> bool:
	var f: String = str(info(key).get("file", ""))
	return f != "" and ResourceLoader.exists("res://assets/" + f)


## Tekstur penuh (untuk strip animasi: semua bingkai berjajar ke kanan).
func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key] as Texture2D
	var t: Texture2D = null
	if has_file(key):
		t = load("res://assets/" + str(info(key)["file"])) as Texture2D
	if t == null:
		t = _placeholder(key)
		if not missing.has(key):
			missing.append(key)
	_cache[key] = t
	return t


## Satu bingkai dari strip animasi.
func frame(key: String, i: int) -> Texture2D:
	var n: int = int(info(key).get("frames", 1))
	if n <= 1:
		return tex(key)
	var ck: String = "%s#%d" % [key, i % n]
	if _cache.has(ck):
		return _cache[ck] as Texture2D
	var full: Texture2D = tex(key)
	var fw: int = full.get_width() / n
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = full
	at.region = Rect2(fw * (i % n), 0, fw, full.get_height())
	_cache[ck] = at
	return at


func _placeholder(key: String) -> Texture2D:
	var d: Dictionary = info(key)
	var sz: Vector2i = size_of(key)
	var n: int = int(d.get("frames", 1))
	var kind: String = str(d.get("kind", "object"))
	var c: Color = Color(str(d.get("color", "#FF00FF")))
	var img: Image = Image.create(sz.x * n, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f: int in range(n):
		var ox: int = f * sz.x
		if kind == "tile":
			img.fill_rect(Rect2i(ox, 0, sz.x, sz.y), c)
			# titik halus agar petak terbaca, tetap polos
			img.set_pixel(ox + 3, 4, c.darkened(0.08))
			img.set_pixel(ox + 11, 10, c.darkened(0.08))
		elif kind == "character":
			var bob: int = 1 if f % 2 == 1 else 0
			img.fill_rect(Rect2i(ox + 3, 9 - bob, 10, 11), c)
			img.fill_rect(Rect2i(ox + 4, 2 - bob, 8, 7), Color("#F5D0B0"))
			img.fill_rect(Rect2i(ox + 4, 1 - bob + 1, 8, 2), Color("#43251D"))
			img.fill_rect(Rect2i(ox + 4, 20, 3, 4), Color("#43251D"))
			img.fill_rect(Rect2i(ox + 9, 20, 3, 4), Color("#43251D"))
		else:
			var inset: int = 1
			img.fill_rect(Rect2i(ox + inset, inset, sz.x - inset * 2, sz.y - inset * 2), c.darkened(0.35))
			img.fill_rect(Rect2i(ox + inset + 1, inset + 1, sz.x - inset * 2 - 2, sz.y - inset * 2 - 2), c)
	return ImageTexture.create_from_image(img)
