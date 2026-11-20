class_name Stages
extends RefCounted

# 스테이지 데이터. 아군은 GameState.roster의 출전 유닛이 player_<줄> 슬롯에 배치되고
# (줄 이름은 UnitTypes.ROWS), 슬롯 총 개수가 그 스테이지의 출전 상한이다.
# 적은 enemies에 타입과 위치로 직접 적는다.
const STAGES := [
	{
		"name": "1. 조우전",
		"battlefield": Rect2(40, 40, 1200, 640),
		"reward": 40,
		"player_front": [Vector2(320, 260), Vector2(320, 360), Vector2(320, 460), Vector2(320, 160)],
		"player_back": [Vector2(240, 310), Vector2(240, 410), Vector2(240, 210), Vector2(240, 510)],
		"enemies": [
			{"type": "melee", "pos": Vector2(960, 280)},
			{"type": "melee", "pos": Vector2(960, 400)},
			{"type": "ranged", "pos": Vector2(1040, 340)},
		],
	},
	{
		"name": "2. 넓은 평원",
		"battlefield": Rect2(20, 20, 1240, 680),
		"reward": 60,
		"player_front": [Vector2(280, 200), Vector2(280, 320), Vector2(280, 440), Vector2(280, 560)],
		"player_back": [Vector2(200, 260), Vector2(200, 380), Vector2(200, 500), Vector2(200, 140)],
		"enemies": [
			{"type": "melee", "pos": Vector2(1000, 220)},
			{"type": "melee", "pos": Vector2(1000, 340)},
			{"type": "melee", "pos": Vector2(1000, 460)},
			{"type": "ranged", "pos": Vector2(1080, 340)},
		],
	},
	{
		"name": "3. 좁은 회랑",
		"battlefield": Rect2(40, 180, 1200, 360),
		"reward": 90,
		"player_front": [Vector2(280, 280), Vector2(280, 360), Vector2(280, 440), Vector2(340, 360)],
		"player_back": [Vector2(200, 320), Vector2(200, 400), Vector2(200, 240), Vector2(200, 480)],
		"enemies": [
			{"type": "melee", "pos": Vector2(1000, 260)},
			{"type": "melee", "pos": Vector2(1000, 360)},
			{"type": "melee", "pos": Vector2(1000, 460)},
			{"type": "ranged", "pos": Vector2(1080, 300)},
			{"type": "ranged", "pos": Vector2(1080, 420)},
		],
	},
	{
		"name": "4. 포위",
		"battlefield": Rect2(40, 40, 1200, 640),
		"reward": 120,
		"player_front": [Vector2(600, 340), Vector2(660, 340), Vector2(720, 340), Vector2(660, 280)],
		"player_back": [Vector2(630, 400), Vector2(690, 400), Vector2(570, 400), Vector2(750, 400)],
		"enemies": [
			{"type": "melee", "pos": Vector2(200, 140)},
			{"type": "melee", "pos": Vector2(1120, 140)},
			{"type": "melee", "pos": Vector2(200, 560)},
			{"type": "melee", "pos": Vector2(1120, 560)},
			{"type": "ranged", "pos": Vector2(660, 100)},
			{"type": "ranged", "pos": Vector2(660, 620)},
		],
	},
	{
		"name": "5. 최후의 전선",
		"battlefield": Rect2(20, 20, 1240, 680),
		"reward": 160,
		"player_front": [Vector2(260, 260), Vector2(260, 360), Vector2(260, 460), Vector2(260, 160)],
		"player_back": [Vector2(180, 310), Vector2(180, 410), Vector2(180, 210), Vector2(180, 510)],
		"enemies": [
			{"type": "melee", "pos": Vector2(1000, 180)},
			{"type": "melee", "pos": Vector2(1000, 300)},
			{"type": "melee", "pos": Vector2(1000, 420)},
			{"type": "melee", "pos": Vector2(1000, 540)},
			{"type": "ranged", "pos": Vector2(1100, 220)},
			{"type": "ranged", "pos": Vector2(1100, 360)},
			{"type": "ranged", "pos": Vector2(1100, 500)},
		],
	},
]


static func count() -> int:
	return STAGES.size()


static func get_stage(idx: int) -> Dictionary:
	return STAGES[idx]


static func reward(idx: int) -> int:
	return int(STAGES[idx].get("reward", 0))


static func enemy_types(stage: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for spec in stage["enemies"]:
		out.append(spec["type"])
	return out


static func _row_slots(stage: Dictionary, row: String) -> Array:
	return stage.get("player_" + row, [])


static func deploy_cap(stage: Dictionary) -> int:
	var total := 0
	for row in UnitTypes.ROWS:
		total += _row_slots(stage, row).size()
	return total


# 출전 유닛(명단 항목) 순서대로 시작 위치를 돌려준다.
# 각 유닛은 타입이 선호하는 줄(UnitTypes의 row)을 먼저 채우고, 넘치면 남은 빈 슬롯을 쓴다.
static func assign_slots(stage: Dictionary, entries: Array[Dictionary]) -> Array[Vector2]:
	var free: Dictionary = {}
	for row in UnitTypes.ROWS:
		free[row] = _row_slots(stage, row).duplicate()
	var result: Array[Vector2] = []
	result.resize(entries.size())
	var pending: Array[int] = []
	for i in range(entries.size()):
		var preferred: Array = free[UnitTypes.get_def(entries[i]["type"])["row"]]
		if preferred.is_empty():
			pending.append(i)
		else:
			result[i] = preferred.pop_front()
	var leftover: Array = []
	for row in UnitTypes.ROWS:
		leftover.append_array(free[row])
	for i in pending:
		if leftover.is_empty():
			push_warning("[Stages] no slot left for unit #%d" % entries[i]["id"])
			result[i] = stage["battlefield"].get_center()
		else:
			result[i] = leftover.pop_front()
	return result
