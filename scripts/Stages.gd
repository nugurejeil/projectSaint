class_name Stages
extends RefCounted

const STAGES := [
	{
		"name": "1. 쉬움 (5 vs 4)",
		"units": [
			{"team": 0, "type": "melee", "pos": Vector2(400, 200)},
			{"team": 0, "type": "melee", "pos": Vector2(400, 300)},
			{"team": 0, "type": "melee", "pos": Vector2(400, 400)},
			{"team": 0, "type": "ranged", "pos": Vector2(400, 500)},
			{"team": 0, "type": "ranged", "pos": Vector2(400, 600)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 220)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 340)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 460)},
			{"team": 1, "type": "ranged", "pos": Vector2(880, 580)},
		],
	},
	{
		"name": "2. 어려움 (5 vs 6)",
		"units": [
			{"team": 0, "type": "melee", "pos": Vector2(400, 200)},
			{"team": 0, "type": "melee", "pos": Vector2(400, 300)},
			{"team": 0, "type": "melee", "pos": Vector2(400, 400)},
			{"team": 0, "type": "ranged", "pos": Vector2(400, 500)},
			{"team": 0, "type": "ranged", "pos": Vector2(400, 600)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 180)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 280)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 380)},
			{"team": 1, "type": "melee", "pos": Vector2(880, 480)},
			{"team": 1, "type": "ranged", "pos": Vector2(880, 130)},
			{"team": 1, "type": "ranged", "pos": Vector2(880, 620)},
		],
	},
]
