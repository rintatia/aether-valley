extends Node2D
## Lightweight, reusable interaction feedback for world activities.

const TURNIP_TEXTURE: Texture2D = preload("res://assets/farming/turnip_crop.svg")

static func play_harvest(parent: Node, world_position: Vector2) -> void:
	var effect := Node2D.new()
	effect.name = "HarvestFeedback"
	parent.add_child(effect)
	effect.global_position = world_position

	var crop := Sprite2D.new()
	crop.texture = TURNIP_TEXTURE
	crop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crop.scale = Vector2(0.42, 0.42)
	crop.position = Vector2(0, -12)
	effect.add_child(crop)

	var label := Label.new()
	label.text = "+1 TURNIP"
	label.position = Vector2(-48, -82)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#fff0b8"))
	label.add_theme_color_override("font_shadow_color", Color("#4b4935"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	effect.add_child(label)

	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(crop, "position", Vector2(0, -76), 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(crop, "rotation", TAU, 0.62).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(crop, "scale", Vector2(0.58, 0.58), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(crop, "modulate:a", 0.0, 0.24).set_delay(0.48)
	tween.tween_property(label, "position", Vector2(-48, -122), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.58)
	tween.chain().tween_callback(effect.queue_free)

static func play_grass_cut(parent: Node, world_position: Vector2) -> void:
	var effect := Node2D.new()
	effect.name = "GrassCutFeedback"
	parent.add_child(effect)
	effect.global_position = world_position
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(7):
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(0, -15), Vector2(3, 0)])
		blade.color = Color("#9fce68") if i % 2 == 0 else Color("#d0df83")
		blade.position = Vector2(rng.randf_range(-8.0, 8.0), -8.0)
		effect.add_child(blade)
		var destination := blade.position + Vector2(rng.randf_range(-35.0, 35.0), rng.randf_range(-28.0, 8.0))
		var tween := effect.create_tween().set_parallel(true)
		tween.tween_property(blade, "position", destination, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(blade, "rotation", rng.randf_range(-2.8, 2.8), 0.42)
		tween.tween_property(blade, "modulate:a", 0.0, 0.2).set_delay(0.22)
	var label := Label.new()
	label.text = "+1 HAY"
	label.position = Vector2(-32, -58)
	label.add_theme_color_override("font_color", Color("#f4efb8"))
	label.add_theme_font_size_override("font_size", 16)
	effect.add_child(label)
	var label_tween := effect.create_tween().set_parallel(true)
	label_tween.tween_property(label, "position:y", -92.0, 0.65)
	label_tween.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.4)
	effect.create_tween().tween_interval(0.8).tween_callback(effect.queue_free)
