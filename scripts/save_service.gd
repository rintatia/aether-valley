extends Node

signal save_completed(success: bool, message: String)

const SAVE_DIR := "user://saves"
const SAVE_PATH := SAVE_DIR + "/slot_01.json"
const TEMP_PATH := SAVE_DIR + "/slot_01.tmp"
const BACKUP_PATH := SAVE_DIR + "/slot_01.bak"
const PREVIOUS_BACKUP_PATH := SAVE_DIR + "/slot_01.bak_prev"
const SAVE_SCHEMA := 1
const AUTOSAVE_INTERVAL_SECONDS := 30.0

var _dirty := true
var _elapsed := 0.0
var _world: Node
var last_error := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.focus_exited.connect(_on_app_pause)
	get_tree().root.close_requested.connect(_on_app_pause)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_world_save()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= AUTOSAVE_INTERVAL_SECONDS:
		_elapsed = 0.0
		if _dirty:
			_request_world_save()

func mark_dirty() -> void:
	_dirty = true

func _request_world_save() -> void:
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().current_scene
	if _world == null or not _world.has_method("make_save_payload"):
		return
	save_game(_world.make_save_payload())

func _on_app_pause() -> void:
	_request_world_save()

func save_game(data: Dictionary) -> bool:
	var dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return _fail("Cannot create save directory (error %d)." % dir_error)
	var envelope := {"schema_version": SAVE_SCHEMA, "saved_at_unix": int(Time.get_unix_time_from_system()), "data": data}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot open temporary save (error %d)." % FileAccess.get_open_error())
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove_file(TEMP_PATH)
		return _fail("Temporary save write failed (error %d)." % write_error)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_PATH))
	if not (parsed is Dictionary) or int(parsed.get("schema_version", 0)) != SAVE_SCHEMA:
		_remove_file(TEMP_PATH)
		return _fail("Temporary save verification failed.")
	_remove_file(PREVIOUS_BACKUP_PATH)
	var had_backup := FileAccess.file_exists(BACKUP_PATH)
	if had_backup:
		var rotate_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(PREVIOUS_BACKUP_PATH))
		if rotate_error != OK:
			_remove_file(TEMP_PATH)
			return _fail("Could not rotate previous backup (error %d)." % rotate_error)
	if FileAccess.file_exists(SAVE_PATH):
		var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
		if backup_error != OK:
			if had_backup and FileAccess.file_exists(PREVIOUS_BACKUP_PATH):
				DirAccess.rename_absolute(ProjectSettings.globalize_path(PREVIOUS_BACKUP_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
			_remove_file(TEMP_PATH)
			return _fail("Could not preserve current save (error %d)." % backup_error)
	var commit_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if commit_error != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
		if had_backup and FileAccess.file_exists(PREVIOUS_BACKUP_PATH):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(PREVIOUS_BACKUP_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
		return _fail("Could not commit new save (error %d)." % commit_error)
	_remove_file(PREVIOUS_BACKUP_PATH)
	_dirty = false
	last_error = ""
	save_completed.emit(true, "Saved locally")
	return true

func load_game() -> Dictionary:
	var primary := _read_payload(SAVE_PATH)
	if not primary.is_empty():
		return primary
	var backup := _read_payload(BACKUP_PATH)
	if not backup.is_empty():
		push_warning("Primary save invalid; recovered previous verified backup.")
		return backup
	var previous_backup := _read_payload(PREVIOUS_BACKUP_PATH)
	if not previous_backup.is_empty():
		push_warning("Primary and current backup unavailable; recovered older verified backup.")
		return previous_backup
	return {}

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}
	var version := int(parsed.get("schema_version", 0))
	if version < 1 or version > SAVE_SCHEMA:
		return {}
	var payload: Variant = parsed.get("data", null)
	if not (payload is Dictionary):
		return {}
	return payload

func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> bool:
	last_error = message
	push_error("SaveService: " + message)
	save_completed.emit(false, message)
	return false
