extends Node

const SAVE_PATH := "user://save.json"

var current_stage: int = 0
var last_result: String = ""
var last_kills: int = 0
var last_player_losses: int = 0
var last_survivors: int = 0


func reset_campaign() -> void:
	current_stage = 0
	last_result = ""
	last_kills = 0
	last_player_losses = 0
	last_survivors = 0
	delete_save()
	print("[GameState] campaign reset")


func record_battle(result: String, kills: int, player_losses: int, survivors: int) -> void:
	last_result = result
	last_kills = kills
	last_player_losses = player_losses
	last_survivors = survivors
	print("[GameState] record: %s kills=%d losses=%d survivors=%d" % [result, kills, player_losses, survivors])


func advance_stage() -> void:
	current_stage += 1
	print("[GameState] advance -> stage %d" % (current_stage + 1))


func is_last_stage() -> bool:
	return current_stage + 1 >= Stages.STAGES.size()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[GameState] save open failed: %s" % FileAccess.get_open_error())
		return
	var payload := {"current_stage": current_stage}
	f.store_string(JSON.stringify(payload))
	print("[GameState] saved stage %d" % (current_stage + 1))


func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("[GameState] load open failed: %s" % FileAccess.get_open_error())
		return false
	var text := f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("current_stage"):
		push_warning("[GameState] invalid save payload, discarding")
		delete_save()
		return false
	var idx: int = int(parsed["current_stage"])
	if idx < 0 or idx >= Stages.STAGES.size():
		push_warning("[GameState] save stage %d out of range, discarding" % (idx + 1))
		delete_save()
		return false
	current_stage = idx
	last_result = ""
	last_kills = 0
	last_player_losses = 0
	last_survivors = 0
	print("[GameState] loaded stage %d" % (current_stage + 1))
	return true


func delete_save() -> void:
	if not has_save():
		return
	var da := DirAccess.open("user://")
	if da != null:
		da.remove("save.json")
	print("[GameState] save deleted")
