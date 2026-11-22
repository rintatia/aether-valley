@tool
extends Node2D

@export var item_id := ""
@export var category := "Other"
@export var asset_path := ""
@export var collision_enabled := true

func _ready() -> void:
    if Engine.is_editor_hint():
        _sync_metadata()

func _sync_metadata() -> void:
    if has_meta("aether_item_id"):
        item_id = str(get_meta("aether_item_id"))
    if has_meta("aether_category"):
        category = str(get_meta("aether_category"))
    if has_meta("aether_asset_path"):
        asset_path = str(get_meta("aether_asset_path"))
    if has_meta("aether_collision_enabled"):
        collision_enabled = bool(get_meta("aether_collision_enabled"))
