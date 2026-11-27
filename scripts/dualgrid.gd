extends Node2D
## Satu lapis tileset dual-grid 15-piece SpriteCook (atlas 4x4).
## Petak logis (x,y) menempati [x*T, (x+1)*T]; ubin yang digambar bergeser setengah petak.
## Agar alami:
## - tiap ubin TEPI punya 2 rupa: asli, atau versi cermin (bingkai lawan, dibalik kiri-kanan) -> pola tepi tidak berbaris
## - sisa salju hanya muncul berkelompok (noise frekuensi rendah); di luar itu pakai atlas bersih

const FRAME_BY_MASK: Array[int] = [-1, 15, 8, 9, 0, 11, 14, 7, 13, 4, 1, 10, 3, 2, 5, 6]
const SNOW_LEVEL: float = 0.18   # makin tinggi makin sedikit salju

var atlas: Texture2D
var clean_atlas: Texture2D
var cells: PackedByteArray = PackedByteArray()
var cols: int = 0
var rows: int = 0
var tile: int = 32
var snow_noise: FastNoiseLite


func setup(a: Texture2D, c: PackedByteArray, w: int, h: int, t: int, clean: Texture2D = null) -> void:
	atlas = a
	clean_atlas = clean
	cells = c
	cols = w
	rows = h
	tile = t
	snow_noise = FastNoiseLite.new()
	snow_noise.seed = 7
	snow_noise.frequency = 0.09
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


static func mirror_mask(m: int) -> int:
	# tukar kiri-kanan: TL<->TR (1<->2), BL<->BR (4<->8)
	return ((m & 1) << 1) | ((m & 2) >> 1) | ((m & 4) << 1) | ((m & 8) >> 1)


static func hash2(x: int, y: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _draw() -> void:
	if atlas == null:
		return
	var half: float = tile / 2.0
	for y: int in range(rows + 1):
		for x: int in range(cols + 1):
			var m: int = mask_at(x, y)
			if m == 0:
				continue
			var tex: Texture2D = atlas
			if clean_atlas != null and snow_noise.get_noise_2d(x, y) < SNOW_LEVEL:
				tex = clean_atlas
			# isi penuh (mask 15) tidak dicermin: ubin isi dirancang menyambung dengan orientasi aslinya
			var flip: bool = m != 15 and (hash2(x, y) & 1) == 1
			var fr: int = FRAME_BY_MASK[mirror_mask(m) if flip else m]
			var src: Rect2 = Rect2((fr % 4) * tile, (fr / 4) * tile, tile, tile)
			var px: float = x * tile - half
			var py: float = y * tile - half
			if flip:
				draw_set_transform(Vector2(px + tile, py), 0.0, Vector2(-1, 1))
				draw_texture_rect_region(tex, Rect2(0, 0, tile, tile), src)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect_region(tex, Rect2(px, py, tile, tile), src)
