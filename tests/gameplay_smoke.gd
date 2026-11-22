extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	assert(packed != null, "Main scene must load")
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame
	assert(world.get("plots").size() == 6, "Homestead must start with six farm plots")
	assert(int(world.get("inventory")["Turnip Seeds"]) == 8, "Starter seed inventory missing")

	world.set("active_tool", "Hoe")
	world.call("_use_plot", 0)
	assert(str(world.get("plots")[0]["state"]) == "tilled", "Hoe must till empty soil")
	world.call("_use_plot", 0)
	assert(str(world.get("plots")[0]["state"]) == "planted", "Seeds must plant in tilled soil")

	world.set("active_tool", "Watering Can")
	for cycle in range(3):
		world.call("_use_plot", 0)
		assert(bool(world.get("plots")[0]["watered"]), "Watering can must water planted crops")
		world.call("_sleep")
	assert(str(world.get("plots")[0]["state"]) == "ripe", "Three watered days must mature a turnip")

	world.set("active_tool", "Hoe")
	world.call("_use_plot", 0)
	assert(str(world.get("plots")[0]["state"]) == "empty", "Harvest must clear the plot")
	assert(int(world.get("inventory")["Turnip"]) == 1, "Harvest must add a turnip")
	assert(int(world.get("coins")) == 43, "Harvest must award eight coins")

	var payload: Dictionary = world.call("make_save_payload")
	assert(payload.has("inventory") and payload.has("plots") and payload.has("player_position"), "Save payload must include gameplay progress")

	world.get("player").global_position = Vector2(355, 300)
	world.set("active_tool", "Axe")
	world.call("_interact")
	world.call("_interact")
	world.call("_interact")
	assert(int(world.get("inventory")["Wood"]) == 3, "Three axe strikes must yield wood")

	world.get("player").global_position = Vector2(760, 430)
	world.call("_interact")
	assert(int(world.get("inventory")["Hay"]) == 3, "Chicken feeding must consume hay")
	world.call("_sleep")
	world.call("_interact")
	assert(int(world.get("inventory")["Egg"]) == 1, "Fed chicken must lay a collectible egg")

	world.queue_free()
	await process_frame
	print("GAMEPLAY SMOKE: PASS — farming, crop growth, harvest, coins, save payload, woodcutting, livestock and eggs")
	quit(0)
