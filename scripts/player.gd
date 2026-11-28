extends Node2D
## Pemain v7. Posisi = titik kaki. Sprite karakter pilihan (cowok/cewek) dengan warna kustom.
## Animasi jalan: langkah memantul + sedikit berayun; menghadap kiri/kanan dengan membalik sprite.

var walking: bool = false
var t: float = 0.0
var facing_left: bool = false
var spr: Sprite2D
var shadow: Node2D
var tool_spr: Sprite2D
var tool_tw: Tween


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


## Alat muncul di tangan lalu diayun/ditusuk/dimiringkan sesuai jenisnya, kemudian hilang.
func use_tool(tex: Texture2D, kind: String) -> void:
	if tool_spr == null:
		tool_spr = Sprite2D.new()
		tool_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(tool_spr)
	if tool_tw != null and tool_tw.is_valid():
		tool_tw.kill()
	var dir: float = -1.0 if facing_left else 1.0
	tool_spr.texture = tex
	tool_spr.scale = Vector2(dir * 30.0 / 256.0, 30.0 / 256.0)
	tool_spr.position = Vector2(dir * 9.0, -16.0)
	tool_spr.modulate.a = 1.0
	tool_spr.visible = true
	tool_tw = create_tween()
	match kind:
		"penyiram":
			tool_spr.rotation = 0.0
			tool_tw.tween_property(tool_spr, "rotation", dir * 0.75, 0.18).set_ease(Tween.EASE_OUT)
			tool_tw.tween_interval(0.3)
			tool_tw.tween_property(tool_spr, "rotation", 0.0, 0.15)
		"tombak", "pancing":
			tool_spr.rotation = dir * 0.6
			tool_tw.tween_property(tool_spr, "position:x", dir * 20.0, 0.10).set_ease(Tween.EASE_OUT)
			tool_tw.tween_property(tool_spr, "position:x", dir * 9.0, 0.16)
			tool_tw.tween_interval(0.1)
		_:
			# ayunan dari atas belakang ke bawah depan (cangkul, sekop, arit, sabit, jaring)
			tool_spr.rotation = -dir * 1.1
			tool_tw.tween_property(tool_spr, "rotation", dir * 0.9, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tool_tw.parallel().tween_property(tool_spr, "position:y", -8.0, 0.16)
			tool_tw.tween_interval(0.15)
	tool_tw.tween_property(tool_spr, "modulate:a", 0.0, 0.12)
	tool_tw.tween_callback(func() -> void: tool_spr.visible = false)
	var hop: Tween = create_tween()
	hop.tween_property(spr, "scale", Vector2(1.04, 0.96), 0.08)
	hop.tween_property(spr, "scale", Vector2.ONE, 0.12)
