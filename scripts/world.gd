extends Node2D

const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const GRID_RADIUS := 18
const GRID_ORIGIN := Vector2(640.0, 360.0)
var _last_grid_center := Vector2i(2147483647, 2147483647)
var day: int = 1
var active_season_id: String = "spring"
var season_names: Dictionary = {}
var player: CharacterBody2D

func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody2D
	_load_season_catalog()
	var saved: Dictionary = SaveService.load_game()
	if not saved.is_empty():
		day = maxi(1, int(saved.get("day", 1)))
		active_season_id = str(saved.get("season_id", "spring"))
		if player != null and saved.get("player_position") is Dictionary:
			var position_data: Dictionary = saved["player_position"]
			player.global_position = Vector2(float(position_data.get("x", 640.0)), float(position_data.get("y", 360.0)))
	_update_season_label()

func _process(_delta: float) -> void:
	if player == null:
		return
	var local_position := player.global_position - GRID_ORIGIN
	var grid_position := _screen_to_grid(local_position)
	var center := Vector2i(roundi(grid_position.x), roundi(grid_position.y))
	if center != _last_grid_center:
		_last_grid_center = center
		queue_redraw()

func _draw() -> void:
	var grid_center := _last_grid_center
	if grid_center.x == 2147483647:
		grid_center = Vector2i.ZERO
	for gx in range(grid_center.x - GRID_RADIUS, grid_center.x + GRID_RADIUS + 1):
		for gy in range(grid_center.y - GRID_RADIUS, grid_center.y + GRID_RADIUS + 1):
			var center := GRID_ORIGIN + _grid_to_screen(Vector2(gx, gy))
			var points := PackedVector2Array([center + Vector2(0, -TILE_HALF_HEIGHT), center + Vector2(TILE_HALF_WIDTH, 0), center + Vector2(0, TILE_HALF_HEIGHT), center + Vector2(-TILE_HALF_WIDTH, 0)])
			draw_colored_polygon(points, Color(0.19, 0.27, 0.23, 1.0))
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color(0.27, 0.36, 0.30, 0.8), 1.0)

func _grid_to_screen(grid: Vector2) -> Vector2:
	return Vector2((grid.x - grid.y) * TILE_HALF_WIDTH, (grid.x + grid.y) * TILE_HALF_HEIGHT)

func _screen_to_grid(screen: Vector2) -> Vector2:
	return Vector2(screen.x / (2.0 * TILE_HALF_WIDTH) + screen.y / (2.0 * TILE_HALF_HEIGHT), screen.y / (2.0 * TILE_HALF_HEIGHT) - screen.x / (2.0 * TILE_HALF_WIDTH))

func _load_season_catalog() -> void:
	var file := FileAccess.open("res://data/seasons.json", FileAccess.READ)
	if file == null:
		push_error("Season catalog missing: res://data/seasons.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Array) or parsed.is_empty():
		push_error("Season catalog must be a non-empty array of season definitions.")
		return
	for entry in parsed:
		if not (entry is Dictionary) or not entry.has("id") or not entry.has("name"):
			push_error("Invalid season definition: every entry needs a stable id and name.")
			continue
		var season_id := str(entry.id)
		if season_names.has(season_id):
			push_error("Duplicate season id: " + season_id)
			continue
		season_names[season_id] = str(entry.name)

func _update_season_label() -> void:
	var label := get_node_or_null("HUD/Header/Info/SeasonLabel") as Label
	if label != null:
		label.text = "%s · VALLEY REGION · DAY %02d" % [str(season_names.get(active_season_id, "Unknown Season")).to_upper(), day]

func make_save_payload() -> Dictionary:
	return {"day": day, "season_id": active_season_id, "player_position": {"x": player.global_position.x, "y": player.global_position.y} if player != null else {"x": 640.0, "y": 360.0}}
