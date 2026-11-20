extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION: int = 1
const STARTING_MONEY: int = 100
const KILL_BOUNTY: int = 5
const STARTING_ROSTER := ["melee", "melee", "melee", "ranged", "ranged"]

const RESULT_WIN := "win"
const RESULT_LOSE := "lose"
const RESULT_DRAW := "draw"

# conclude_battle()이 돌려주는 캠페인 진행 결과
const OUTCOME_NEXT := "next"            # 승리, 다음 스테이지로
const OUTCOME_COMPLETE := "complete"    # 마지막 스테이지 승리
const OUTCOME_RETRY := "retry"          # 패배/무승부, 남은 전력으로 재정비
const OUTCOME_GAME_OVER := "game_over"  # 유닛도 고용할 돈도 없음

var current_stage: int = 0
var money: int = STARTING_MONEY
# 보유 유닛 명단. 항목: {"id": int, "type": "melee"|"ranged", "squad": int, "deployed": bool}
var roster: Array[Dictionary] = []
var last_result: String = ""
var last_kills: int = 0
var last_player_losses: int = 0
var last_survivors: int = 0
var last_reward: int = 0

var _next_unit_id: int = 1


func _ready() -> void:
	_reset_roster()


func reset_campaign() -> void:
	current_stage = 0
	money = STARTING_MONEY
	_reset_roster()
	_clear_last_result()
	delete_save()
	print("[GameState] campaign reset (money=%d roster=%d)" % [money, roster.size()])


func _reset_roster() -> void:
	roster.clear()
	_next_unit_id = 1
	for type in STARTING_ROSTER:
		_add_unit(type, true)


func _clear_last_result() -> void:
	last_result = ""
	last_kills = 0
	last_player_losses = 0
	last_survivors = 0
	last_reward = 0


func _add_unit(type: String, deployed: bool) -> Dictionary:
	var entry := {"id": _next_unit_id, "type": type, "squad": 0, "deployed": deployed}
	_next_unit_id += 1
	roster.append(entry)
	return entry


# --- 명단 조회/조작 ---

func find_unit(id: int) -> Dictionary:
	for entry in roster:
		if entry["id"] == id:
			return entry
	return {}


func deployed_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in roster:
		if entry["deployed"]:
			out.append(entry)
	return out


func deployed_count() -> int:
	return deployed_units().size()


func set_deployed(id: int, value: bool, deploy_cap: int) -> bool:
	var entry := find_unit(id)
	if entry.is_empty():
		return false
	if value and not entry["deployed"] and deployed_count() >= deploy_cap:
		print("[GameState] deploy refused for #%d: cap %d reached" % [id, deploy_cap])
		return false
	entry["deployed"] = value
	print("[GameState] unit #%d deployed=%s (%d/%d)" % [id, value, deployed_count(), deploy_cap])
	save()
	return true


func clamp_deployment(deploy_cap: int) -> void:
	var count := 0
	for entry in roster:
		if not entry["deployed"]:
			continue
		count += 1
		if count > deploy_cap:
			entry["deployed"] = false
			print("[GameState] unit #%d benched (over cap %d)" % [entry["id"], deploy_cap])


func set_unit_squad(id: int, squad: int) -> void:
	var entry := find_unit(id)
	if not entry.is_empty():
		entry["squad"] = squad


func hire(type: String, deploy_cap: int) -> bool:
	if not UnitTypes.exists(type) or UnitTypes.price(type) <= 0:
		return false
	var price := UnitTypes.price(type)
	if money < price:
		print("[GameState] hire %s refused: money %d < price %d" % [type, money, price])
		return false
	money -= price
	var entry := _add_unit(type, deployed_count() < deploy_cap)
	print("[GameState] hired %s #%d for %d G (money=%d roster=%d deployed=%s)" % [
		type, entry["id"], price, money, roster.size(), entry["deployed"],
	])
	save()
	return true


# 보유 유닛이 없고 새로 고용할 돈도 없으면 캠페인을 이어갈 수 없다.
func is_game_over() -> bool:
	return roster.is_empty() and money < UnitTypes.cheapest_price()


# --- 전투 결과 ---

func battle_reward(stage_idx: int, kills: int) -> int:
	return Stages.reward(stage_idx) + kills * KILL_BOUNTY


# 전투 한 판의 결과를 캠페인에 반영한다: 보상 지급, 전사자 명단 제거, 스테이지 진행, 세이브.
# 결과 화면에서 어디로 나가든 손실·보상이 되돌려지지 않도록 여기서 바로 저장까지 끝낸다.
func conclude_battle(result: String, kills: int, player_losses: int, survivors: int, dead_ids: Array[int]) -> String:
	var reward := battle_reward(current_stage, kills) if result == RESULT_WIN else 0
	last_result = result
	last_kills = kills
	last_player_losses = player_losses
	last_survivors = survivors
	last_reward = reward
	money += reward
	_remove_units(dead_ids)
	var outcome: String
	if result == RESULT_WIN:
		if is_last_stage():
			delete_save()
			outcome = OUTCOME_COMPLETE
		else:
			advance_stage()
			save()
			outcome = OUTCOME_NEXT
	elif is_game_over():
		delete_save()
		outcome = OUTCOME_GAME_OVER
	else:
		save()
		outcome = OUTCOME_RETRY
	print("[GameState] battle concluded: %s -> %s kills=%d losses=%d survivors=%d reward=%d money=%d roster=%d (lost ids %s)" % [
		result, outcome, kills, player_losses, survivors, reward, money, roster.size(), dead_ids,
	])
	return outcome


func _remove_units(ids: Array[int]) -> void:
	if ids.is_empty():
		return
	var kept: Array[Dictionary] = []
	for entry in roster:
		if not ids.has(entry["id"]):
			kept.append(entry)
	roster = kept


func advance_stage() -> void:
	current_stage += 1
	print("[GameState] advance -> stage %d" % (current_stage + 1))


func is_last_stage() -> bool:
	return current_stage + 1 >= Stages.count()


# --- 세이브/로드 ---

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[GameState] save open failed: %s" % FileAccess.get_open_error())
		return
	var payload := {
		"version": SAVE_VERSION,
		"current_stage": current_stage,
		"money": money,
		"roster": roster,
		"next_unit_id": _next_unit_id,
	}
	f.store_string(JSON.stringify(payload))
	print("[GameState] saved stage %d (money=%d roster=%d)" % [current_stage + 1, money, roster.size()])


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
	if idx < 0 or idx >= Stages.count():
		push_warning("[GameState] save stage %d out of range, discarding" % (idx + 1))
		delete_save()
		return false
	current_stage = idx
	money = int(parsed.get("money", STARTING_MONEY))
	if parsed.get("roster") is Array:
		_load_roster(parsed["roster"], int(parsed.get("next_unit_id", 1)))
	else:
		# 명단 도입 이전 세이브: 기본 편성으로 시작
		_reset_roster()
	_clear_last_result()
	print("[GameState] loaded stage %d (money=%d roster=%d)" % [current_stage + 1, money, roster.size()])
	return true


func _load_roster(raw: Array, next_id: int) -> void:
	roster.clear()
	var max_id := 0
	for item in raw:
		if not (item is Dictionary) or not UnitTypes.exists(str(item.get("type", ""))):
			push_warning("[GameState] skipping invalid roster entry: %s" % [item])
			continue
		var id := int(item.get("id", 0))
		if id <= 0 or not find_unit(id).is_empty():
			push_warning("[GameState] skipping roster entry with bad id: %s" % [item])
			continue
		roster.append({
			"id": id,
			"type": String(item["type"]),
			"squad": int(item.get("squad", 0)),
			"deployed": bool(item.get("deployed", false)),
		})
		max_id = maxi(max_id, id)
	_next_unit_id = maxi(next_id, max_id + 1)


func delete_save() -> void:
	if not has_save():
		return
	var da := DirAccess.open("user://")
	if da != null:
		da.remove("save.json")
	print("[GameState] save deleted")
