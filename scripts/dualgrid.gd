extends Node2D
## Satu lapis tileset dual-grid 15-piece SpriteCook (atlas 4x4).
## Petak logis (x,y) menempati [x*T, (x+1)*T]; ubin yang digambar bergeser setengah petak.
## Ubin dipakai persis dalam orientasi aslinya (tidak dicermin) agar setiap sambungan menyatu.
## Sisa salju: dipilih berkelompok lewat noise, lalu disebarkan ke tetangga bila bercak salju
## menyentuh tepi ubin. Batas salju/bersih hanya jatuh di tepi yang tidak bersalju -> tidak ada bercak terpotong.

const FRAME_BY_MASK: Array[int] = [-1, 15, 8, 9, 0, 11, 14, 7, 13, 4, 1, 10, 3, 2, 5, 6]
const SNOW_LEVEL: float = 0.18   # makin tinggi makin sedikit salju
const EDGE_PX: int = 2           # lebar pita tepi yang diperiksa
const DIRS: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]  # kiri, kanan, atas, bawah

var atlas: Texture2D
var clean_atlas: Texture2D
var cells: PackedByteArray = PackedByteArray()
var cols: int = 0
var rows: int = 0
var tile: int = 32
var snow: PackedByteArray = PackedByteArray()      # per ubin tergambar: 1 = pakai atlas bersalju
var frame_edge_snow: Array = []                     # [frame] -> [kiri, kanan, atas, bawah]


func setup(a: Texture2D, c: PackedByteArray, w: int, h: int, t: int, clean: Texture2D = null) -> void:
	atlas = a
	clean_atlas = clean
	cells = c
	cols = w
	rows = h
	tile = t
	_plan_snow()
	queue_redraw()


func filled(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < cols and y < rows and cells[y * cols + x] == 1


func mask_at(x: int, y: int) -> int:
	var m: int = 0
	if filled(x - 1, y - 1):
		m |= 1
	if filled(x, y - 1):
		m |= 2
	if filled(x - 1, y):
		m |= 4
	if filled(x, y):
		m |= 8
	return m


func _idx(x: int, y: int) -> int:
	return y * (cols + 1) + x


## Tepi mana saja dari tiap bingkai yang tersentuh bercak salju (selisih atlas bersalju vs bersih).
func _scan_frames() -> void:
	frame_edge_snow.clear()
	var a: Image = atlas.get_image()
	var b: Image = clean_atlas.get_image()
	for f: int in range(16):
		var ox: int = (f % 4) * tile
		var oy: int = (f / 4) * tile
		var e: Array[bool] = [false, false, false, false]
		for yy: int in range(tile):
			for xx: int in range(tile):
				var ca: Color = a.get_pixel(ox + xx, oy + yy)
				var cb: Color = b.get_pixel(ox + xx, oy + yy)
				if ca.a == 0.0 or absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) < 0.06:
					continue
				if xx < EDGE_PX:
					e[0] = true
				if xx >= tile - EDGE_PX:
					e[1] = true
				if yy < EDGE_PX:
					e[2] = true
				if yy >= tile - EDGE_PX:
					e[3] = true
		frame_edge_snow.append(e)


func _plan_snow() -> void:
	snow = PackedByteArray()
	snow.resize((cols + 1) * (rows + 1))
	snow.fill(0)
	if clean_atlas == null:
		snow.fill(1)
		return
	_scan_frames()
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 7
	n.frequency = 0.09
	var queue: Array[Vector2i] = []
	for y: int in range(rows + 1):
		for x: int in range(cols + 1):
			if mask_at(x, y) != 0 and n.get_noise_2d(x, y) >= SNOW_LEVEL:
				snow[_idx(x, y)] = 1
				queue.append(Vector2i(x, y))
	# sebarkan: bercak yang menyentuh tepi menarik tetangga ikut bersalju
	var guard: int = 0
	while not queue.is_empty() and guard < 100000:
		guard += 1
		var p: Vector2i = queue.pop_back()
		var fr: int = FRAME_BY_MASK[mask_at(p.x, p.y)]
		if fr < 0:
			continue
		var e: Array = frame_edge_snow[fr] as Array
		for d: int in range(4):
			if not bool(e[d]):
				continue
			var q: Vector2i = p + DIRS[d]
			if q.x < 0 or q.y < 0 or q.x > cols or q.y > rows:
				continue
			if mask_at(q.x, q.y) == 0 or snow[_idx(q.x, q.y)] == 1:
				continue
			snow[_idx(q.x, q.y)] = 1
			queue.append(q)


func _draw() -> void:
	if atlas == null:
		return
	var half: float = tile / 2.0
	for y: int in range(rows + 1):
		for x: int in range(cols + 1):
			var fr: int = FRAME_BY_MASK[mask_at(x, y)]
			if fr < 0:
				continue
			var tex: Texture2D = atlas if (clean_atlas == null or snow[_idx(x, y)] == 1) else clean_atlas
			draw_texture_rect_region(tex, Rect2(x * tile - half, y * tile - half, tile, tile),
				Rect2((fr % 4) * tile, (fr / 4) * tile, tile, tile))
