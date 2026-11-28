extends Node2D
## Pemain v7. Posisi = titik kaki. Bingkai dari Art ("chr_petani_<arah>").

const FPS: float = 8.0

var dir: String = "bawah"
var walking: bool = false
var t: float = 0.0
var spr: Sprite2D


func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # karakter pixel art tetap tajam
	spr.centered = false
	add_child(spr)
	_refresh()


func face(v: Vector2) -> void:
	if v.length() < 0.01:
		return
	var nd: String
	if absf(v.x) > absf(v.y):
		nd = "kanan" if v.x > 0.0 else "kiri"
	else:
		nd = "bawah" if v.y > 0.0 else "atas"
	if nd != dir:
		dir = nd
		_refresh()


func _process(delta: float) -> void:
	if walking:
		t += delta
	else:
		t = 0.0
	_refresh()


func _refresh() -> void:
	var key: String = "chr_petani_" + dir
	var n: int = int(Art.info(key).get("frames", 1))
	var i: int = int(t * FPS) % n if walking else 0
	spr.texture = Art.frame(key, i)
	var sz: Vector2i = Art.size_of(key)
	spr.position = Vector2(-sz.x / 2.0, -sz.y + sz.y / 6.0)
