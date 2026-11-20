class_name UnitStats
extends RefCounted

const MELEE := {
	"health": 140.0,
	"speed": 260.0,
	"range": 70.0,
	"damage": 25.0,
	"cooldown": 1.0,
}

const RANGED := {
	"health": 70.0,
	"speed": 180.0,
	"range": 280.0,
	"damage": 18.0,
	"cooldown": 1.4,
}

const PLAYER_MELEE := {
	"health": 180.0,
	"speed": 280.0,
	"range": 80.0,
	"damage": 32.0,
	"cooldown": 0.9,
}

const PLAYER_RANGED := {
	"health": 95.0,
	"speed": 200.0,
	"range": 300.0,
	"damage": 24.0,
	"cooldown": 1.2,
}

# 고용 가능한 용병. 준비 화면 목록 순서는 HIRE_ORDER를 따른다.
const HIRE_ORDER := ["melee", "ranged"]

const HIRE := {
	"melee": {"label": "근접병", "price": 50, "stats": PLAYER_MELEE},
	"ranged": {"label": "원거리병", "price": 70, "stats": PLAYER_RANGED},
}
