extends Node2D
## Pemain v7. Posisi = titik kaki.
## Male & female: animasi bingkai (diam, jalan, ngantuk, cangkul, siram, panen, tebang, tambang, serang, pancing)
## dari assets/karakter_v7/anim_cewek (pixel art 178 px, digambar 0.5x). Animasi dipakai apa adanya (dengan alat
## bawaannya); alat kita TIDAK digambar selama animasi agar tidak campur aduk.
## (anim_cowok / anim_cewek). Bila folder animasi tidak ada: sprite tunggal dengan langkah memantul.

var ANIM_DIR: String = "res://assets/karakter_v7/anim_cewek/"
## alat -> animasi yang dipakai
const TOOL_ANIM: Dictionary = {"cangkul": "cangkul", "sekop": "cangkul", "penyiram": "siram", "arit": "panen",
	"pisau": "panen", "kapak": "tebang", "beliung": "tambang", "pedang": "serang", "jaring": "serang", "pancing": "pancing"}

var walking: bool = false
var t: float = 0.0
var facing_left: bool = false
var spr: Sprite2D
var shadow: Node2D
var tool_spr: Sprite2D
var hand_spr: Sprite2D          # tangan di atas alat (jari menggenggam gagang)
var tool_tw: Tween
var hold_anim: bool = false     # untuk tangkapan layar: bingkai dibekukan

# mode animasi bingkai
var animated: bool = false
var anim: Dictionary = {}
var alat: Dictionary = {}
var tex_cache: Dictionary = {}
var cur_anim: String = ""
var anim_t: float = 0.0
var acting: String = ""          # animasi aksi yang sedang diputar sekali ("" = tidak ada)
var act_tool: String = ""


func _ready() -> void:
	shadow = Node2D.new()
	shadow.draw.connect(func() -> void:
		shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
		shadow.draw_circle(Vector2.ZERO, 15.0, Color(0.10, 0.16, 0.06, 0.28)))
	add_child(shadow)
	spr = Sprite2D.new()
	spr.centered = false
	add_child(spr)
	tool_spr = Sprite2D.new()
	tool_spr.centered = false
	tool_spr.visible = false
	add_child(tool_spr)
	hand_spr = Sprite2D.new()
	hand_spr.centered = false
	hand_spr.hframes = 8
	hand_spr.visible = false
	add_child(hand_spr)
	refresh_look()


func refresh_look() -> void:
	ANIM_DIR = "res://assets/karakter_v7/anim_%s/" % Game.gender
	tex_cache.clear()
	animated = ResourceLoader.exists(ANIM_DIR + "anim.json")
	spr.rotation = 0.0
	spr.position = Vector2.ZERO
	spr.scale = Vector2.ONE
	if animated:
		anim = Art.load_json(ANIM_DIR + "anim.json")
		spr.material = null
		spr.hframes = 8
		var k: Array = anim["kaki"] as Array
		spr.offset = Vector2(-float(k[0]), -float(k[1]))
		var s: float = float(anim["skala"])
		spr.scale = Vector2(s, s)
		hand_spr.offset = spr.offset
		hand_spr.scale = spr.scale
		cur_anim = ""
		_set_anim("diam")
		return
	spr.hframes = 1
	spr.frame = 0
	spr.texture = Game.char_texture("kecil")
	spr.material = Game.char_material("kecil")
	var sz: Vector2 = spr.texture.get_size()
	spr.offset = Vector2(-sz.x / 2.0, -sz.y + 2.0)


func face(v: Vector2) -> void:
	if absf(v.x) > 0.3:
		facing_left = v.x < 0.0
		spr.flip_h = facing_left


func _tex(name: String) -> Texture2D:
	if not tex_cache.has(name):
		tex_cache[name] = load(ANIM_DIR + name + ".png")
	return tex_cache[name] as Texture2D


func _set_anim(name: String) -> void:
	if name == cur_anim:
		return
	cur_anim = name
	anim_t = 0.0
	spr.texture = _tex(name)
	spr.frame = 0


func _process(delta: float) -> void:
	if animated:
		_process_anim(delta)
		return
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


func _process_anim(delta: float) -> void:
	if acting != "" and walking:
		_end_act()   # berjalan membatalkan aksi
	var sleepy: bool = Game.minute >= 22.0 * 60.0 or Game.minute < 5.0 * 60.0
	var want: String = acting if acting != "" else ("jalan" if walking else ("ngantuk" if sleepy else "diam"))
	_set_anim(want)
	if not hold_anim:
		anim_t += delta
	var fps: float = float((anim["fps"] as Dictionary).get(cur_anim, 10))
	var f: int = int(anim_t * fps)
	if acting != "":
		if f >= 8:
			_end_act()
			_set_anim("diam")
			f = 0
	else:
		f = f % 8
	spr.frame = f
	_place_tool(f)


func _end_act() -> void:
	acting = ""
	act_tool = ""
	tool_spr.visible = false
	hand_spr.visible = false


## Alat kita di tangan pada bingkai f: titik genggam alat -> titik genggam pose, diputar ke arah pose.
func _place_tool(f: int) -> void:
	if acting == "" or act_tool == "" or not alat.has(act_tool):
		tool_spr.visible = false
		hand_spr.visible = false
		return
	var poses: Array = (anim["pose"] as Dictionary).get(cur_anim, []) as Array
	if f >= poses.size() or poses[f] == null:
		tool_spr.visible = false
		hand_spr.visible = false
		return
	var p: Dictionary = poses[f] as Dictionary
	var a: Dictionary = alat[act_tool] as Dictionary
	var g: Vector2 = _v(a["g"])
	var h: Vector2 = _v(a["h"])
	var pg: Vector2 = _v(p["g"])
	var pt: Vector2 = _v(p["t"])
	var k: Vector2 = _v(anim["kaki"])
	var sk: float = float(anim["skala"])
	var length: float = float(p["l"]) if float(p["l"]) > 0.0 else float(a["l"])
	var s: float = length * sk / maxf(g.distance_to(h), 1.0)
	var rot: float = (pt - pg).angle() - (h - g).angle()
	var dir: float = -1.0 if facing_left else 1.0
	tool_spr.centered = false
	tool_spr.flip_h = bool(a.get("cermin", false))
	tool_spr.offset = -g
	tool_spr.position = Vector2((pg.x - k.x) * sk * dir, (pg.y - k.y) * sk)
	tool_spr.rotation = rot * dir
	tool_spr.scale = Vector2(s * dir, s)
	tool_spr.modulate.a = 1.0
	tool_spr.visible = true
	tool_spr.z_index = -1 if bool(p.get("b", false)) else 0
	# tangan digambar di atas alat -> jari menutupi gagang, tampak benar-benar menggenggam
	var ht: String = ANIM_DIR + cur_anim + "_tangan.png"
	hand_spr.visible = not bool(p.get("b", false)) and ResourceLoader.exists(ht)
	if hand_spr.visible:
		hand_spr.texture = _tex(cur_anim + "_tangan")
		hand_spr.frame = f
		hand_spr.flip_h = facing_left


func _v(x: Variant) -> Vector2:
	var arr: Array = x as Array
	return Vector2(float(arr[0]), float(arr[1]))


## Alat dipakai: animasi aksi (dengan alat bawaannya). Tanpa animasi: alat kita diayun sederhana.
func use_tool(tex: Texture2D, kind: String) -> void:
	if animated:
		acting = str(TOOL_ANIM.get(kind, "serang"))
		act_tool = ""   # alat kita tidak digambar; animasi sudah membawa alatnya sendiri
		if tex != null:
			tool_spr.texture = tex
		cur_anim = ""
		_set_anim(acting)
		return
	if tex == null:
		return
	if tool_tw != null and tool_tw.is_valid():
		tool_tw.kill()
	var dir: float = -1.0 if facing_left else 1.0
	tool_spr.texture = tex
	tool_spr.centered = true
	tool_spr.offset = Vector2.ZERO
	tool_spr.flip_h = false
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
			tool_spr.rotation = -dir * 1.1
			tool_tw.tween_property(tool_spr, "rotation", dir * 0.9, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tool_tw.parallel().tween_property(tool_spr, "position:y", -8.0, 0.16)
			tool_tw.tween_interval(0.15)
	tool_tw.tween_property(tool_spr, "modulate:a", 0.0, 0.12)
	tool_tw.tween_callback(func() -> void: tool_spr.visible = false)
