extends CharacterBody2D

const PLAYER_TEXTURE: Texture2D = preload("res://assets/characters/player_idle.svg")

@export var move_speed := 185.0
var touch_direction := Vector2.ZERO
var facing := Vector2.DOWN

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	input_vector += touch_direction
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var projected := Vector2(input_vector.x - input_vector.y, (input_vector.x + input_vector.y) * 0.5)
	if projected.length() > 1.0:
		projected = projected.normalized()
	velocity = projected * move_speed
	if projected.length_squared() > 0.001:
		facing = projected.normalized()
		SaveService.mark_dirty()
	move_and_slide()

func _draw() -> void:
	# Use the imported character artwork rather than geometric debug primitives.
	draw_texture_rect(PLAYER_TEXTURE, Rect2(-36, -48, 72, 96), false)
