extends Node2D
## Aether Valley v7 - kerangka kosong. Menunggu aset dari kreator.

func _ready() -> void:
	var l: Label = Label.new()
	l.text = "Aether Valley v7\nkerangka kosong - menunggu aset"
	l.add_theme_font_size_override("font_size", 40)
	l.position = Vector2(60, 60)
	add_child(l)
	if "--selftest" in OS.get_cmdline_user_args():
		print("SELFTEST OK")
		get_tree().quit(0)
