extends CharacterBody2D

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
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.5, 0.55))
	draw_circle(Vector2.ZERO, 9.0, Color(0.04, 0.06, 0.05, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := PackedVector2Array()
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		body.append(Vector2(cos(angle) * 8.0, 1.0 + sin(angle) * 11.0))
	draw_colored_polygon(body, Color("#6b4c91"))
	draw_circle(Vector2(0, -11), 8, Color("#f0c9a5"))
	draw_rect(Rect2(-8, -19, 16, 5), Color("#563b32"))
	draw_rect(Rect2(-6, -12, 3, 2), Color("#332a2a"))
	draw_rect(Rect2(3, -12, 3, 2), Color("#332a2a"))
