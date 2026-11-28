extends Node2D
## Pemain v7. Posisi = titik kaki. Sprite karakter pilihan (cowok/cewek) dengan warna kustom.
## Animasi jalan: langkah memantul + sedikit berayun; menghadap kiri/kanan dengan membalik sprite.

var walking: bool = false
var t: float = 0.0
var facing_left: bool = false
var spr: Sprite2D
var shadow: Node2D


func _ready() -> void:
	shadow = Node2D.new()
	shadow.draw.connect(func() -> void:
		shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
		shadow.draw_circle(Vector2.ZERO, 15.0, Color(0.10, 0.16, 0.06, 0.28)))
	add_child(shadow)
	spr = Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	add_child(spr)
	refresh_look()


func refresh_look() -> void:
	spr.texture = Game.char_texture("kecil")
	spr.material = Game.char_material("kecil")
	var sz: Vector2 = spr.texture.get_size()
	spr.offset = Vector2(-sz.x / 2.0, -sz.y + 2.0)


func face(v: Vector2) -> void:
	if absf(v.x) > 0.3:
		facing_left = v.x < 0.0
		spr.flip_h = facing_left


func _process(delta: float) -> void:
	if walking:
		t += delta
		var ph: float = t * 11.0
		spr.position = Vector2(0, -absf(sin(ph)) * 3.0)
		spr.rotation = sin(ph) * 0.045
		spr.scale = Vector2(1.0 + absf(sin(ph)) * 0.02, 1.0 - absf(sin(ph)) * 0.02)
	else:
		t = 0.0
		# napas pelan saat diam
		var idle: float = sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		spr.position = Vector2.ZERO
		spr.rotation = 0.0
		spr.scale = Vector2(1.0, 1.0 + idle * 0.012)
