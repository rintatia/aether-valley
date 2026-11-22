extends CharacterBody2D

@export var move_speed: float = 190.0
var touch_direction: Vector2 = Vector2.ZERO
var last_facing: Vector2 = Vector2.DOWN

func _ready() -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	input_vector += touch_direction
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var screen_direction := Vector2(input_vector.x - input_vector.y, (input_vector.x + input_vector.y) * 0.5)
	if screen_direction.length() > 1.0:
		screen_direction = screen_direction.normalized()
	velocity = screen_direction * move_speed
	if screen_direction.length_squared() > 0.001:
		last_facing = screen_direction.normalized()
	move_and_slide()
	if screen_direction.length_squared() > 0.001:
		SaveService.mark_dirty()

func _draw() -> void:
	draw_set_transform(Vector2(0, 9), 0.0, Vector2(1.4, 0.5))
	draw_circle(Vector2.ZERO, 7.0, Color(0.04, 0.06, 0.05, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 8.0, Color(0.72, 0.78, 0.82))
	draw_circle(Vector2(0, -7), 6.0, Color(0.91, 0.82, 0.68))
	draw_rect(Rect2(-5, -1, 10, 12), Color(0.35, 0.25, 0.48))

func get_save_position() -> Vector2:
	return global_position
