extends CanvasLayer

const BUTTON_SIZE := Vector2(58, 58)
const MARGIN := 26.0
const GAP := 8.0
var _buttons: Array[Button] = []

func _ready() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var up := _make_button(overlay, "▲", "move_up")
	var down := _make_button(overlay, "▼", "move_down")
	var left := _make_button(overlay, "◀", "move_left")
	var right := _make_button(overlay, "▶", "move_right")
	var interact := _make_button(overlay, "ACT", "interact")
	up.name = "MoveUp"
	down.name = "MoveDown"
	left.name = "MoveLeft"
	right.name = "MoveRight"
	interact.name = "Interact"
	call_deferred("_layout_buttons")
	overlay.resized.connect(_layout_buttons)
	get_tree().root.focus_exited.connect(_release_all)
	if not OS.has_feature("mobile") and DisplayServer.window_get_size().x >= 900:
		for button in _buttons:
			button.visible = false

func _make_button(parent: Control, caption: String, action: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = BUTTON_SIZE
	button.size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.modulate = Color(1, 1, 1, 0.82)
	button.button_down.connect(_press_action.bind(action))
	button.button_up.connect(_release_action.bind(action))
	parent.add_child(button)
	_buttons.append(button)
	return button

func _layout_buttons() -> void:
	var view_size := get_viewport().get_visible_rect().size
	if _buttons.size() != 5:
		return
	var bottom := view_size.y - MARGIN - BUTTON_SIZE.y
	var left := MARGIN
	_buttons[0].position = Vector2(left + BUTTON_SIZE.x + GAP, bottom - BUTTON_SIZE.y - GAP)
	_buttons[1].position = Vector2(left + BUTTON_SIZE.x + GAP, bottom)
	_buttons[2].position = Vector2(left, bottom)
	_buttons[3].position = Vector2(left + 2.0 * (BUTTON_SIZE.x + GAP), bottom)
	_buttons[4].position = Vector2(view_size.x - MARGIN - BUTTON_SIZE.x * 1.45, bottom - 8.0)
	_buttons[4].size = BUTTON_SIZE * 1.45

func _press_action(action: String) -> void:
	Input.action_press(action)

func _release_action(action: String) -> void:
	Input.action_release(action)

func _release_all() -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "interact"]:
		Input.action_release(action)

func _exit_tree() -> void:
	_release_all()
