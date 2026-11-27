extends Node2D
## Satu lapis tileset dual-grid 15-piece SpriteCook (atlas 4x4).
## Petak logis (x,y) menempati persegi [x*T, (x+1)*T]; ubin yang digambar bergeser setengah petak.

const FRAME_BY_MASK: Array[int] = [-1, 15, 8, 9, 0, 11, 14, 7, 13, 4, 1, 10, 3, 2, 5, 6]

var atlas: Texture2D
var cells: PackedByteArray = PackedByteArray()
var cols: int = 0
var rows: int = 0
var tile: int = 32


func setup(a: Texture2D, c: PackedByteArray, w: int, h: int, t: int) -> void:
	atlas = a
	cells = c
	cols = w
	rows = h
	tile = t
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


func _draw() -> void:
	if atlas == null:
		return
	var h: float = tile / 2.0
	for y: int in range(rows + 1):
		for x: int in range(cols + 1):
			var fr: int = FRAME_BY_MASK[mask_at(x, y)]
			if fr < 0:
				continue
			draw_texture_rect_region(atlas, Rect2(x * tile - h, y * tile - h, tile, tile),
				Rect2((fr % 4) * tile, (fr / 4) * tile, tile, tile))
