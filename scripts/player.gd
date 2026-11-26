extends Node2D
## Karakter placeholder (posisi = kaki). Ganti dengan sprite nanti.

var color: Color = Color("#D8574F")
var facing: float = 1.0
var walking: bool = false
var t: float = 0.0


func _process(delta: float) -> void:
	if walking:
		t += delta
		queue_redraw()


func _draw() -> void:
	var bob: float = 0.0
	if walking:
		bob = absf(sin(t * 12.0)) * -1.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-4, -5 + bob, 3, 5), Color("#43251D"))
	draw_rect(Rect2(1, -5 - bob, 3, 5), Color("#43251D"))
	draw_rect(Rect2(-5, -15 + bob, 10, 11), color)
	draw_circle(Vector2(0, -19 + bob), 5.0, Color("#F5D0B0"))
	draw_rect(Rect2(-5, -25 + bob, 10, 4), Color("#43251D"))
	draw_rect(Rect2(-2.0 + facing * 1.5, -20 + bob, 1, 2), Color("#241912"))
	draw_rect(Rect2(1.0 + facing * 1.5, -20 + bob, 1, 2), Color("#241912"))
