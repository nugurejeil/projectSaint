extends Control

@onready var _stage_label: Label = $VBox/StageLabel
@onready var _summary_label: Label = $VBox/SummaryLabel
@onready var _last_result_label: Label = $VBox/LastResultLabel


func _ready() -> void:
	var idx: int = GameState.current_stage
	var stage: Dictionary = Stages.STAGES[idx]
	_stage_label.text = "스테이지 %d / %d" % [idx + 1, Stages.STAGES.size()]
	_summary_label.text = "%s\n%s" % [stage["name"], _summarize_units(stage)]
	if GameState.last_result == "":
		_last_result_label.visible = false
	else:
		_last_result_label.text = _format_last_result()
		_last_result_label.visible = true
	GameState.save()
	print("[Prep] stage %d ready" % (idx + 1))


func _summarize_units(stage: Dictionary) -> String:
	var counts := {"player_melee": 0, "player_ranged": 0, "enemy_melee": 0, "enemy_ranged": 0}
	for spec in stage["units"]:
		var key: String = ("player_" if spec["team"] == 0 else "enemy_") + spec["type"]
		counts[key] += 1
	var player_total: int = counts["player_melee"] + counts["player_ranged"]
	var enemy_total: int = counts["enemy_melee"] + counts["enemy_ranged"]
	return "아군 %d (근접 %d · 원거리 %d) vs 적 %d (근접 %d · 원거리 %d)" % [
		player_total, counts["player_melee"], counts["player_ranged"],
		enemy_total, counts["enemy_melee"], counts["enemy_ranged"],
	]


func _format_last_result() -> String:
	match GameState.last_result:
		"win":
			return "직전 전투: 승리 (처치 %d · 생존 %d)" % [GameState.last_kills, GameState.last_survivors]
		"lose":
			return "직전 전투: 패배 (처치 %d · 아군 손실 %d)" % [GameState.last_kills, GameState.last_player_losses]
		"draw":
			return "직전 전투: 무승부"
		_:
			return ""


func _on_battle_pressed() -> void:
	print("[Prep] battle -> Main")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_title_pressed() -> void:
	print("[Prep] title")
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
