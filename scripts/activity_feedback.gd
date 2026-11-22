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
