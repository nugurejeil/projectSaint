class_name UnitTypes
extends RefCounted
# 유닛 타입 정의의 단일 출처.
# 새 타입은 TYPES에 항목 하나, ORDER에 id 하나를 추가하면
# 전투(Unit) · 스테이지 배치(Stages) · 고용/명단 화면(Prep) · 세이브 검증(GameState)에 함께 반영된다.

const ROW_FRONT := "front"
const ROW_BACK := "back"
const ROWS := [ROW_FRONT, ROW_BACK]

const SHAPE_SQUARE := "square"
const SHAPE_CIRCLE := "circle"
const SHAPE_TRIANGLE := "triangle"

# 모양별 몸체 폴리곤(정다각형의 변 수·반지름)과 UI 목록용 글리프
const SHAPES := {
	SHAPE_SQUARE: {"sides": 4, "radius": 28.3, "angle": PI / 4.0, "icon": "■"},
	SHAPE_CIRCLE: {"sides": 20, "radius": 18.0, "angle": 0.0, "icon": "●"},
	SHAPE_TRIANGLE: {"sides": 3, "radius": 24.0, "angle": -PI / 2.0, "icon": "▲"},
}

# 화면에 나열하는 순서 (고용 목록, 편성 요약)
const ORDER := ["melee", "ranged", "sniper"]

# label       화면 표시 이름
# code        유닛 노드 이름·로그용 한 글자
# shape       몸체 모양
# row         시작 배치 때 선호하는 줄
# projectile  true면 투사체를 쏘고, false면 즉시 타격
# enemy_kites 적 AI일 때 근접당하면 거리를 벌림
# price       고용 가격 (0 이하면 고용 목록에 나오지 않음)
# player/enemy 진영별 수치
const TYPES := {
	"melee": {
		"label": "근접병",
		"code": "M",
		"shape": SHAPE_SQUARE,
		"row": ROW_FRONT,
		"projectile": false,
		"enemy_kites": false,
		"price": 50,
		"player": {"health": 180.0, "speed": 280.0, "range": 80.0, "damage": 32.0, "cooldown": 0.9},
		"enemy": {"health": 140.0, "speed": 260.0, "range": 70.0, "damage": 25.0, "cooldown": 1.0},
	},
	"ranged": {
		"label": "원거리병",
		"code": "R",
		"shape": SHAPE_CIRCLE,
		"row": ROW_BACK,
		"projectile": true,
		"enemy_kites": true,
		"price": 70,
		"player": {"health": 95.0, "speed": 200.0, "range": 300.0, "damage": 24.0, "cooldown": 1.2},
		"enemy": {"health": 70.0, "speed": 180.0, "range": 280.0, "damage": 18.0, "cooldown": 1.4},
	},
	# 사거리 최장 · 연사 최저 · 이속 최저. 원거리병을 사거리 밖에서 잡지만 근접병이 붙으면 약하다.
	"sniper": {
		"label": "저격병",
		"code": "S",
		"shape": SHAPE_TRIANGLE,
		"row": ROW_BACK,
		"projectile": true,
		"enemy_kites": true,
		"price": 90,
		"player": {"health": 70.0, "speed": 130.0, "range": 480.0, "damage": 60.0, "cooldown": 2.6},
		"enemy": {"health": 55.0, "speed": 110.0, "range": 460.0, "damage": 45.0, "cooldown": 2.8},
	},
}


static func exists(id: String) -> bool:
	return TYPES.has(id)


static func get_def(id: String) -> Dictionary:
	return TYPES[id]


static func stats(id: String, is_player: bool) -> Dictionary:
	return TYPES[id]["player" if is_player else "enemy"]


static func label(id: String) -> String:
	return TYPES[id]["label"]


static func price(id: String) -> int:
	return TYPES[id]["price"]


static func icon(id: String) -> String:
	return SHAPES[TYPES[id]["shape"]]["icon"]


static func body_polygon(id: String) -> PackedVector2Array:
	var shape: Dictionary = SHAPES[TYPES[id]["shape"]]
	var sides: int = shape["sides"]
	var pts := PackedVector2Array()
	for i in range(sides):
		var a: float = shape["angle"] + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * shape["radius"])
	return pts


static func hireable() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if price(id) > 0:
			out.append(id)
	return out


static func cheapest_price() -> int:
	var cheapest := -1
	for id in hireable():
		if cheapest < 0 or price(id) < cheapest:
			cheapest = price(id)
	return cheapest


# 타입 id 목록을 "근접병 3 · 원거리병 2" 형태로 요약한다.
static func summarize(type_ids: Array) -> String:
	var counts: Dictionary = {}
	for id in type_ids:
		counts[id] = counts.get(id, 0) + 1
	var parts: PackedStringArray = []
	for id in ORDER:
		if counts.has(id):
			parts.append("%s %d" % [label(id), counts[id]])
	return " · ".join(parts)
