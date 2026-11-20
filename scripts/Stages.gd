class_name Stages
extends RefCounted

# 스테이지 데이터. 아군은 GameState.roster의 출전 유닛이 player_<줄> 슬롯에 배치되고
# (줄 이름은 UnitTypes.ROWS), 슬롯 총 개수가 그 스테이지의 출전 상한이다.
# 적은 enemies에 타입과 위치로 직접 적는다. 적 항목의 선택 키:
#   squad      같은 번호끼리 한 부대로 묶여 함께 움직인다 (EnemySquad). 없거나 0이면 개별 행동.
#   targeting  "weakest"면 사거리 안에서 체력이 가장 낮은 아군을 노린다 (기본은 가장 가까운 적).
# enemy_squads는 부대 번호별 행동 패턴: "attack"(대형째 접근) / "defend"(포착·피격 전까지 대기).
const DEFAULT_SQUAD_BEHAVIOR := "attack"

const STAGES := [
	{
		"name": "1. 조우전",
		"battlefield": Rect2(40, 40, 1200, 640),
		"reward": 40,
		"player_front": [Vector2(320, 360), Vector2(320, 260), Vector2(320, 460), Vector2(320, 160), Vector2(320, 560)],
		"player_back": [Vector2(240, 360), Vector2(240, 260), Vector2(240, 460), Vector2(240, 160), Vector2(240, 560)],
		"enemy_squads": {1: "attack"},
		"enemies": [
			{"type": "melee", "pos": Vector2(960, 280), "squad": 1},
			{"type": "melee", "pos": Vector2(960, 400), "squad": 1},
			{"type": "ranged", "pos": Vector2(1040, 340), "squad": 1},
		],
	},
	{
		"name": "2. 넓은 평원",
		"battlefield": Rect2(20, 20, 1240, 680),
		"reward": 60,
		"player_front": [Vector2(280, 360), Vector2(280, 240), Vector2(280, 480), Vector2(280, 120), Vector2(280, 600)],
		"player_back": [Vector2(200, 360), Vector2(200, 240), Vector2(200, 480), Vector2(200, 120), Vector2(200, 600)],
		"enemy_squads": {1: "attack"},
		"enemies": [
			{"type": "melee", "pos": Vector2(1000, 220), "squad": 1},
			{"type": "melee", "pos": Vector2(1000, 340), "squad": 1},
			{"type": "melee", "pos": Vector2(1000, 460), "squad": 1},
			{"type": "ranged", "pos": Vector2(1080, 340), "squad": 1},
		],
	},
	{
		"name": "3. 좁은 회랑",
		"battlefield": Rect2(40, 180, 1200, 360),
		"reward": 90,
		"player_front": [Vector2(280, 360), Vector2(280, 300), Vector2(280, 420), Vector2(280, 240), Vector2(280, 480)],
		"player_back": [Vector2(200, 360), Vector2(200, 300), Vector2(200, 420), Vector2(200, 240), Vector2(200, 480)],
		"enemy_squads": {1: "attack", 2: "defend"},
		"enemies": [
			{"type": "melee", "pos": Vector2(960, 260), "squad": 1},
			{"type": "melee", "pos": Vector2(960, 360), "squad": 1},
			{"type": "melee", "pos": Vector2(960, 460), "squad": 1},
			{"type": "ranged", "pos": Vector2(1100, 300), "squad": 2},
			{"type": "ranged", "pos": Vector2(1100, 420), "squad": 2},
			{"type": "sniper", "pos": Vector2(1180, 360), "squad": 2, "targeting": "weakest"},
		],
	},
	{
		"name": "4. 포위",
		"battlefield": Rect2(40, 40, 1200, 640),
		"reward": 120,
		"player_front": [Vector2(660, 340), Vector2(600, 340), Vector2(720, 340), Vector2(540, 340), Vector2(780, 340)],
		"player_back": [Vector2(660, 400), Vector2(600, 400), Vector2(720, 400), Vector2(540, 400), Vector2(780, 400)],
		"enemy_squads": {1: "attack", 2: "attack", 3: "defend", 4: "defend"},
		"enemies": [
			{"type": "melee", "pos": Vector2(140, 310), "squad": 1},
			{"type": "melee", "pos": Vector2(140, 410), "squad": 1},
			{"type": "melee", "pos": Vector2(1140, 310), "squad": 2},
			{"type": "melee", "pos": Vector2(1140, 410), "squad": 2},
			{"type": "ranged", "pos": Vector2(620, 90), "squad": 3},
			{"type": "sniper", "pos": Vector2(700, 90), "squad": 3, "targeting": "weakest"},
			{"type": "ranged", "pos": Vector2(700, 630), "squad": 4},
			{"type": "sniper", "pos": Vector2(620, 630), "squad": 4, "targeting": "weakest"},
		],
	},
	{
		"name": "5. 최후의 전선",
		"battlefield": Rect2(20, 20, 1240, 680),
		"reward": 160,
		"player_front": [Vector2(260, 360), Vector2(260, 260), Vector2(260, 460), Vector2(260, 160), Vector2(260, 560)],
		"player_back": [Vector2(180, 360), Vector2(180, 260), Vector2(180, 460), Vector2(180, 160), Vector2(180, 560)],
		"enemy_squads": {1: "attack", 2: "defend"},
		"enemies": [
			{"type": "melee", "pos": Vector2(940, 210), "squad": 1},
			{"type": "melee", "pos": Vector2(940, 310), "squad": 1},
			{"type": "melee", "pos": Vector2(940, 410), "squad": 1},
			{"type": "melee", "pos": Vector2(940, 510), "squad": 1},
			{"type": "ranged", "pos": Vector2(1020, 290), "squad": 1},
			{"type": "ranged", "pos": Vector2(1020, 430), "squad": 1},
			{"type": "melee", "pos": Vector2(1100, 360), "squad": 2},
			{"type": "ranged", "pos": Vector2(1160, 360), "squad": 2},
			{"type": "sniper", "pos": Vector2(1200, 260), "squad": 2, "targeting": "weakest"},
			{"type": "sniper", "pos": Vector2(1200, 460), "squad": 2, "targeting": "weakest"},
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


static func enemy_squad_behavior(stage: Dictionary, squad_id: int) -> String:
	var behavior: String = stage.get("enemy_squads", {}).get(squad_id, DEFAULT_SQUAD_BEHAVIOR)
	if not EnemySquad.BEHAVIORS.has(behavior):
		push_warning("[Stages] unknown squad behavior '%s', using %s" % [behavior, DEFAULT_SQUAD_BEHAVIOR])
		return DEFAULT_SQUAD_BEHAVIOR
	return behavior


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
