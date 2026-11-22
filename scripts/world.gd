extends Node2D

const TILE_W := 32.0
const TILE_H := 16.0
const GRID_ORIGIN := Vector2(640, 360)
const AUTOSAVE_HINT := "Progress saves automatically"
const VALLEY_TEXTURE: Texture2D = preload("res://assets/world/spring_valley_environment.svg")
const CHICKEN_TEXTURE: Texture2D = preload("res://assets/animals/chicken.svg")

var player: CharacterBody2D
var day := 1
var season_index := 0
var season_names := ["Spring", "Summer", "Autumn", "Winter", "Bloomveil", "Crimsonfall", "Frostveil", "Solstice of Embers", "Lunaris", "Starfall", "Tidal Bloom", "Veil of Whispers", "Crystalwake", "Astral Drift"]
var coins := 35
var inventory := {"Turnip Seeds": 8, "Turnip": 0, "Wood": 0, "Stone": 0, "Ore": 0, "Egg": 0, "Hay": 4}
var plots: Array[Dictionary] = []
var trees: Array[Dictionary] = []
var rocks: Array[Dictionary] = []
var chicken := {"fed": false, "egg_ready": false}
var active_tool := "Hoe"
var message := "Welcome to your new valley. Tend the soil and make it home."
var message_timer := 8.0
var _hud: Label
var _stats: Label
var _inventory_label: Label
var _tool_label: Label
var _last_day := 1

func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody2D
	_create_world_state()
	_build_hud()
	var saved := SaveService.load_game()
	if not saved.is_empty():
		_load_world_state(saved)
	_update_hud()
	queue_redraw()

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
	elif message_timer != -1.0:
		message = ""
		message_timer = -1.0
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tool_next"):
		_cycle_tool()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("advance_day"):
		_sleep()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		_show_inventory()
		get_viewport().set_input_as_handled()

func _create_world_state() -> void:
	plots.clear()
	for x in range(3):
		for y in range(2):
			plots.append({"id": "plot_%d_%d" % [x, y], "position": Vector2(520 + x * 58 + y * 29, 430 + y * 42 - x * 21), "state": "empty", "growth": 0, "watered": false})
	trees = [
		{"position": Vector2(730, 225), "hits": 0, "kind": "Oak"},
		{"position": Vector2(780, 255), "hits": 0, "kind": "Birch"},
		{"position": Vector2(1240, 360), "hits": 0, "kind": "Willow"}
	]
	rocks = [
		{"position": Vector2(390, 700), "hits": 0, "kind": "Copper Vein"},
		{"position": Vector2(1450, 760), "hits": 0, "kind": "Stone Outcrop"}
	]

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameHUD"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(390, 120)
	layer.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var title := Label.new()
	title.text = "AETHER VALLEY  /  HOMESTEAD"
	title.add_theme_font_size_override("font_size", 19)
	stack.add_child(title)
	_stats = Label.new()
	stack.add_child(_stats)
	_inventory_label = Label.new()
	stack.add_child(_inventory_label)
	_tool_label = Label.new()
	stack.add_child(_tool_label)
	_hud = Label.new()
	_hud.position = Vector2(18, 150)
	_hud.custom_minimum_size = Vector2(640, 64)
	_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_hud)
	var help := Label.new()
	help.text = "MOVE: WASD / D-PAD     ACT: E     TOOL: Q     SLEEP: F     INVENTORY: I"
	help.position = Vector2(18, 680)
	help.add_theme_font_size_override("font_size", 13)
	layer.add_child(help)
	var sleep_button := Button.new()
	sleep_button.text = "SLEEP  /  NEXT DAY"
	sleep_button.position = Vector2(450, 620)
	sleep_button.custom_minimum_size = Vector2(170, 42)
	sleep_button.pressed.connect(_sleep)
	layer.add_child(sleep_button)
	var bag_button := Button.new()
	bag_button.text = "BAG"
	bag_button.position = Vector2(630, 620)
	bag_button.custom_minimum_size = Vector2(90, 42)
	bag_button.pressed.connect(_show_inventory)
	layer.add_child(bag_button)
	var tool_button := Button.new()
	tool_button.text = "NEXT TOOL"
	tool_button.position = Vector2(730, 620)
	tool_button.custom_minimum_size = Vector2(120, 42)
	tool_button.pressed.connect(_cycle_tool)
	layer.add_child(tool_button)

func _update_hud() -> void:
	if not is_instance_valid(_stats):
		return
	_stats.text = "%s  ·  DAY %02d  ·  %d G" % [season_names[season_index].to_upper(), day, coins]
	_inventory_label.text = "SEEDS %d   TURNIP %d   WOOD %d   STONE %d   ORE %d   EGG %d" % [int(inventory["Turnip Seeds"]), int(inventory["Turnip"]), int(inventory["Wood"]), int(inventory["Stone"]), int(inventory["Ore"]), int(inventory["Egg"])]
	_tool_label.text = "TOOL: " + active_tool
	_hud.text = message

func _say(text: String, seconds := 3.5) -> void:
	message = text
	message_timer = seconds
	_update_hud()

func _cycle_tool() -> void:
	var tools := ["Hoe", "Watering Can", "Axe", "Pickaxe"]
	var index := tools.find(active_tool)
	active_tool = tools[(index + 1) % tools.size()]
	_say("Equipped " + active_tool, 1.5)

func _interact() -> void:
	if player == null:
		return
	var nearest_plot := -1
	var nearest_distance := 999999.0
	for i in range(plots.size()):
		var distance: float = player.global_position.distance_to(plots[i].position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_plot = i
	if nearest_plot >= 0 and nearest_distance < 66.0:
		_use_plot(nearest_plot)
		return
	var chicken_pos := Vector2(760, 430)
	if player.global_position.distance_to(chicken_pos) < 72.0:
		if chicken.egg_ready:
			chicken.egg_ready = false
			inventory["Egg"] = int(inventory["Egg"]) + 1
			_say("Collected a fresh egg.")
		elif not chicken.fed:
			if int(inventory["Hay"]) > 0:
				inventory["Hay"] = int(inventory["Hay"]) - 1
				chicken.fed = true
				_say("You fed the chicken. It clucks happily.")
			else:
				_say("The chicken needs hay.")
		else:
			_say("The chicken is content. Check back tomorrow.")
		_mark_saved()
		return
	var tree_index := _nearest_resource(trees)
	if tree_index >= 0 and active_tool == "Axe":
		trees[tree_index].hits = int(trees[tree_index].hits) + 1
		if int(trees[tree_index].hits) >= 3:
			inventory["Wood"] = int(inventory["Wood"]) + 3
			trees.remove_at(tree_index)
			_say("Tree felled: +3 Wood.")
		else:
			_say("Chop... (%d/3)" % int(trees[tree_index].hits))
		_mark_saved()
		return
	var rock_index := _nearest_resource(rocks)
	if rock_index >= 0 and active_tool == "Pickaxe":
		rocks[rock_index].hits = int(rocks[rock_index].hits) + 1
		if int(rocks[rock_index].hits) >= 3:
			if str(rocks[rock_index].kind) == "Copper Vein":
				inventory["Ore"] = int(inventory["Ore"]) + 2
				_say("Copper vein mined: +2 Ore.")
			else:
				inventory["Stone"] = int(inventory["Stone"]) + 3
				_say("Stone outcrop mined: +3 Stone.")
			rocks.remove_at(rock_index)
		else:
			_say("Mining... (%d/3)" % int(rocks[rock_index].hits))
		_mark_saved()
		return
	if player.global_position.distance_to(Vector2(650, 245)) < 85.0:
		_say("A quiet homestead. Press SLEEP to begin the next day.")
		return
	_say("Nothing to interact with nearby. Move closer to a plot, tree, rock, or chicken.")

func _nearest_resource(items: Array[Dictionary]) -> int:
	var best := -1
	var best_distance := 78.0
	for i in range(items.size()):
		var distance: float = player.global_position.distance_to(items[i].position)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best

func _use_plot(index: int) -> void:
	var plot := plots[index]
	var state := str(plot.state)
	if active_tool == "Hoe" and state == "empty":
		plot.state = "tilled"
		_say("Soil prepared. Equip seeds by interacting again.")
	elif active_tool == "Hoe" and state == "tilled":
		if int(inventory["Turnip Seeds"]) > 0:
			inventory["Turnip Seeds"] = int(inventory["Turnip Seeds"]) - 1
			plot.state = "planted"
			plot.growth = 0
			plot.watered = false
			_say("Turnip seeds planted. Water them each day.")
		else:
			_say("You are out of Turnip Seeds.")
	elif active_tool == "Watering Can" and state == "planted":
		plot.watered = true
		_say("Crop watered. It will grow when you sleep.")
	elif active_tool == "Hoe" and state == "ripe":
		inventory["Turnip"] = int(inventory["Turnip"]) + 1
		coins += 8
		plot.state = "empty"
		plot.growth = 0
		plot.watered = false
		_say("Harvested Turnip: +1 Turnip, +8 G.")
	else:
		_say("This plot is %s. Select the right tool or wait for growth." % state)
	_mark_saved()

func _sleep() -> void:
	day += 1
	if day > 28:
		day = 1
		season_index = (season_index + 1) % season_names.size()
	for plot in plots:
		if str(plot.state) == "planted" and bool(plot.watered):
			plot.growth = int(plot.growth) + 1
			plot.watered = false
			if int(plot.growth) >= 3:
				plot.state = "ripe"
		elif str(plot.state) == "planted":
			_say("An unwatered crop did not grow.", 2.0)
	var laid_egg := bool(chicken.fed)
	chicken.fed = false
	if laid_egg:
		chicken.egg_ready = true
		_say("Day %02d begins. Crops advance, and your fed chicken laid an egg." % day, 4.0)
	else:
		_say("Day %02d begins. Crops advance. Feed the chicken to receive an egg." % day, 4.0)
	_mark_saved()

func _show_inventory() -> void:
	var lines := ["BACKPACK"]
	for key in inventory.keys():
		lines.append("%s: %d" % [key, int(inventory[key])])
	lines.append("Coins: %d G" % coins)
	_say("   ·   ".join(PackedStringArray(lines)), 8.0)

func _mark_saved() -> void:
	SaveService.mark_dirty()
	_update_hud()
	queue_redraw()

func make_save_payload() -> Dictionary:
	return {
		"day": day,
		"season_index": season_index,
		"coins": coins,
		"inventory": inventory.duplicate(true),
		"plots": plots.duplicate(true),
		"trees": trees.duplicate(true),
		"rocks": rocks.duplicate(true),
		"chicken": chicken.duplicate(true),
		"player_position": {"x": player.global_position.x, "y": player.global_position.y} if player != null else {"x": 640.0, "y": 360.0}
	}

func _load_world_state(data: Dictionary) -> void:
	day = maxi(1, int(data.get("day", 1)))
	season_index = clampi(int(data.get("season_index", 0)), 0, season_names.size() - 1)
	coins = maxi(0, int(data.get("coins", 35)))
	var saved_inventory: Variant = data.get("inventory", {})
	if saved_inventory is Dictionary:
		for key in inventory.keys():
			inventory[key] = maxi(0, int(saved_inventory.get(key, inventory[key])))
	var saved_plots: Variant = data.get("plots", [])
	if saved_plots is Array and saved_plots.size() == plots.size():
		for i in range(saved_plots.size()):
			if saved_plots[i] is Dictionary:
				plots[i] = saved_plots[i]
	var saved_trees: Variant = data.get("trees", [])
	if saved_trees is Array:
		trees.clear()
		for entry in saved_trees:
			if entry is Dictionary:
				trees.append(entry)
	var saved_rocks: Variant = data.get("rocks", [])
	if saved_rocks is Array:
		rocks.clear()
		for entry in saved_rocks:
			if entry is Dictionary:
				rocks.append(entry)
	var saved_chicken: Variant = data.get("chicken", {})
	if saved_chicken is Dictionary:
		chicken = {"fed": bool(saved_chicken.get("fed", false)), "egg_ready": bool(saved_chicken.get("egg_ready", false))}
	var position_data: Variant = data.get("player_position", {})
	if player != null and position_data is Dictionary:
		player.global_position = Vector2(float(position_data.get("x", 640.0)), float(position_data.get("y", 360.0)))

func _draw() -> void:
	# Use the designed Spring Valley environment instead of the debug diamond field.
	draw_texture(VALLEY_TEXTURE, Vector2(-160, -140))
	_draw_plots()
	_draw_chicken()

func _draw_home() -> void:
	pass

func _draw_plots() -> void:
	for plot in plots:
		var p: Vector2 = plot.position
		var color := Color("#76543a")
		if str(plot.state) == "tilled":
			color = Color("#68452f")
		elif str(plot.state) == "planted":
			color = Color("#526f3d")
		elif str(plot.state) == "ripe":
			color = Color("#8b7b37")
		var points := PackedVector2Array([p + Vector2(0, -17), p + Vector2(29, 0), p + Vector2(0, 17), p + Vector2(-29, 0)])
		draw_colored_polygon(points, color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("#c8a77b"), 1.5)
		if str(plot.state) in ["planted", "ripe"]:
			var height := 8.0 + float(plot.get("growth", 0)) * 4.0
			draw_line(p + Vector2(0, 2), p + Vector2(0, -height), Color("#5b9a48"), 3.0)
			draw_circle(p + Vector2(-5, -height), 5.0, Color("#7ebc55"))
			draw_circle(p + Vector2(5, -height - 2), 5.0, Color("#9bcf61"))
		if bool(plot.watered):
			draw_circle(p + Vector2(20, -11), 3.0, Color("#79c9ed"))

func _draw_resources() -> void:
	pass

func _draw_chicken() -> void:
	var p := Vector2(760, 430)
	draw_texture_rect(CHICKEN_TEXTURE, Rect2(p - Vector2(42, 36), Vector2(84, 72)), false)
	if chicken.egg_ready:
		draw_circle(p + Vector2(-30, 26), 6.0, Color("#fff5dc"))
