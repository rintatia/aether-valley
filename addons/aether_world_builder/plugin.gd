@tool
extends EditorPlugin

const CATALOG_PATH := "res://data/world_builder_catalog.json"
const ITEM_SCRIPT_PATH := "res://addons/aether_world_builder/world_builder_item.gd"

var dock: VBoxContainer
var category_picker: OptionButton
var item_list: ItemList
var preview: TextureRect
var details: Label
var collision_toggle: CheckBox
var add_button: Button
var _catalog: Array[Dictionary] = []
var _visible_items: Array[Dictionary] = []
var _selected_item: Dictionary = {}

func _enter_tree() -> void:
    _load_catalog()
    _build_dock()
    add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)

func _exit_tree() -> void:
    if dock:
        remove_control_from_docks(dock)
        dock.queue_free()

func _load_catalog() -> void:
    _catalog.clear()
    if not FileAccess.file_exists(CATALOG_PATH):
        push_warning("Aether World Builder: catalog not found at " + CATALOG_PATH)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    if parsed is Dictionary and parsed.get("items", []) is Array:
        for entry in parsed["items"]:
            if entry is Dictionary and entry.has("id") and entry.has("path"):
                _catalog.append(entry)

func _build_dock() -> void:
    dock = VBoxContainer.new()
    dock.name = "Aether World Builder"
    dock.custom_minimum_size = Vector2(250, 360)

    var heading := Label.new()
    heading.text = "AETHER VALLEY · WORLD BUILDER"
    heading.add_theme_font_size_override("font_size", 14)
    dock.add_child(heading)

    var intro := Label.new()
    intro.text = "Choose an item, add it to the open scene, then move and arrange it in the 2D viewport."
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dock.add_child(intro)

    category_picker = OptionButton.new()
    category_picker.add_item("All Categories")
    var categories: Array[String] = []
    for entry in _catalog:
        var category := str(entry.get("category", "Other"))
        if not categories.has(category):
            categories.append(category)
    categories.sort()
    for category in categories:
        category_picker.add_item(category)
    category_picker.item_selected.connect(_on_category_changed)
    dock.add_child(category_picker)

    item_list = ItemList.new()
    item_list.custom_minimum_size = Vector2(230, 150)
    item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    item_list.item_selected.connect(_on_item_selected)
    dock.add_child(item_list)

    preview = TextureRect.new()
    preview.custom_minimum_size = Vector2(128, 112)
    preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    dock.add_child(preview)

    details = Label.new()
    details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dock.add_child(details)

    collision_toggle = CheckBox.new()
    collision_toggle.text = "Create basic collision"
    collision_toggle.button_pressed = true
    dock.add_child(collision_toggle)

    add_button = Button.new()
    add_button.text = "ADD ITEM TO OPEN SCENE"
    add_button.disabled = true
    add_button.pressed.connect(_add_selected_item)
    dock.add_child(add_button)

    var note := Label.new()
    note.text = "Items are editable scene nodes. No fixed tile size is imposed."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dock.add_child(note)

    _refresh_items()

func _on_category_changed(_index: int) -> void:
    _refresh_items()

func _refresh_items() -> void:
    if not is_instance_valid(item_list):
        return
    item_list.clear()
    _visible_items.clear()
    var category := category_picker.get_item_text(category_picker.selected)
    for entry in _catalog:
        if category == "All Categories" or str(entry.get("category", "Other")) == category:
            _visible_items.append(entry)
            item_list.add_item(str(entry.get("name", entry.get("id", "Item"))))
    _selected_item.clear()
    preview.texture = null
    details.text = "Select an item to preview it."
    add_button.disabled = true

func _on_item_selected(index: int) -> void:
    if index < 0 or index >= _visible_items.size():
        return
    _selected_item = _visible_items[index]
    var path := str(_selected_item.get("path", ""))
    if ResourceLoader.exists(path):
        var resource: Resource = load(path)
        if resource is Texture2D:
            preview.texture = resource
    else:
        preview.texture = null
    details.text = "%s\nCategory: %s\nSource: %s" % [
        str(_selected_item.get("name", "Item")),
        str(_selected_item.get("category", "Other")),
        path
    ]
    add_button.disabled = false

func _add_selected_item() -> void:
    if _selected_item.is_empty():
        return
    var scene_root := EditorInterface.get_edited_scene_root()
    if scene_root == null:
        push_warning("Open a scene before adding a World Builder item.")
        return
    var asset_path := str(_selected_item.get("path", ""))
    if not ResourceLoader.exists(asset_path):
        push_warning("Missing asset: " + asset_path)
        return
    var texture := load(asset_path) as Texture2D
    if texture == null:
        push_warning("Asset is not a Texture2D: " + asset_path)
        return

    var item := Node2D.new()
    item.name = _make_node_name(str(_selected_item.get("name", "WorldItem")))
    item.set_script(load(ITEM_SCRIPT_PATH))
    item.set_meta("aether_item_id", str(_selected_item.get("id", "")))
    item.set_meta("aether_category", str(_selected_item.get("category", "Other")))
    item.set_meta("aether_asset_path", asset_path)
    item.set_meta("aether_collision", str(_selected_item.get("collision", "none")))
    item.set_meta("aether_collision_enabled", collision_toggle.button_pressed)

    var sprite := Sprite2D.new()
    sprite.name = "Artwork"
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale = Vector2.ONE * float(_selected_item.get("scale", 1.0))
    sprite.z_index = int(_selected_item.get("z_index", 10))
    item.add_child(sprite)
    sprite.owner = scene_root

    if collision_toggle.button_pressed:
        _add_collision(item, scene_root)

    scene_root.add_child(item)
    item.owner = scene_root
    item.position = Vector2.ZERO
    EditorInterface.get_selection().clear()
    EditorInterface.get_selection().add_node(item)
    EditorInterface.get_editor_main_screen().grab_focus()
    print("Aether World Builder: added ", item.name, " to ", scene_root.name)

func _add_collision(item: Node2D, scene_root: Node) -> void:
    var collision_kind := str(_selected_item.get("collision", "none"))
    if collision_kind == "none":
        return
    var body := StaticBody2D.new()
    body.name = "Collision"
    var shape_node := CollisionShape2D.new()
    shape_node.name = "CollisionShape2D"
    if collision_kind == "circle":
        var circle := CircleShape2D.new()
        circle.radius = float(_selected_item.get("radius", 16.0))
        shape_node.shape = circle
    else:
        var rectangle := RectangleShape2D.new()
        rectangle.size = Vector2(48, 32)
        shape_node.shape = rectangle
    body.add_child(shape_node)
    item.add_child(body)
    body.owner = scene_root
    shape_node.owner = scene_root

func _make_node_name(source: String) -> String:
    var safe := source.strip_edges().replace(" ", "_").replace("-", "_")
    return safe + "_" + str(Time.get_ticks_msec() % 100000)
