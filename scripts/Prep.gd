extends Control

const UNIT_COLOR := Color(0.30, 0.55, 1.00)
const SQUAD_COLOR := Color(0.9, 0.85, 0.5)
const STATS_COLOR := Color(0.75, 0.8, 0.88)

@onready var _stage_label: Label = $Margin/VBox/StageLabel
@onready var _summary_label: Label = $Margin/VBox/SummaryLabel
@onready var _last_result_label: Label = $Margin/VBox/LastResultLabel
@onready var _money_label: Label = $MoneyLabel
@onready var _roster_title: Label = $Margin/VBox/Columns/RosterPanel/Pad/VBox/RosterTitle
@onready var _roster_list: VBoxContainer = $Margin/VBox/Columns/RosterPanel/Pad/VBox/Scroll/RosterList
@onready var _hire_list: VBoxContainer = $Margin/VBox/Columns/HirePanel/Pad/VBox/HireList
@onready var _battle_button: Button = $Margin/VBox/Buttons/BattleButton

var _stage: Dictionary = {}
var _deploy_cap: int = 0
var _hire_buttons: Dictionary = {}


func _ready() -> void:
	_apply_theme()
	var idx: int = GameState.current_stage
	_stage = Stages.STAGES[idx]
	_deploy_cap = Stages.deploy_cap(_stage)
	GameState.clamp_deployment(_deploy_cap)
	_stage_label.text = "스테이지 %d / %d" % [idx + 1, Stages.STAGES.size()]
	if GameState.last_result == "":
		_last_result_label.visible = false
	else:
		_last_result_label.text = _format_last_result()
		_last_result_label.visible = true
	_build_hire_list()
	_refresh()
	GameState.save()
	print("[Prep] stage %d ready (roster=%d deployed=%d/%d money=%d)" % [
		idx + 1, GameState.roster.size(), GameState.deployed_count(), _deploy_cap, GameState.money,
	])


# 코드로 만드는 목록 항목도 한글이 나오도록 씬 전체에 시스템 폰트를 기본값으로 건다.
func _apply_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "sans-serif"])
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 20
	theme = t


func _refresh() -> void:
	_money_label.text = "잔액: %d G" % GameState.money
	var reward: int = int(_stage.get("reward", 0))
	_summary_label.text = "%s\n%s\n승리 보상: %d G  (+처치당 %d G)" % [
		_stage["name"], _summarize_matchup(), reward, GameState.KILL_BOUNTY,
	]
	var deployed := GameState.deployed_count()
	_roster_title.text = "보유 유닛 %d  ·  출전 %d / %d" % [GameState.roster.size(), deployed, _deploy_cap]
	_rebuild_roster_list()
	for type in _hire_buttons:
		var price: int = UnitStats.HIRE[type]["price"]
		(_hire_buttons[type] as Button).disabled = GameState.money < price
	_battle_button.disabled = deployed == 0
	_battle_button.text = "전투 시작" if deployed > 0 else "출전 유닛 없음"


func _summarize_matchup() -> String:
	var player := {"melee": 0, "ranged": 0}
	for entry in GameState.deployed_units():
		player[entry["type"]] += 1
	var enemy := {"melee": 0, "ranged": 0}
	for spec in _stage["enemies"]:
		enemy[spec["type"]] += 1
	return "출전 %d (근접 %d · 원거리 %d) vs 적 %d (근접 %d · 원거리 %d)" % [
		player["melee"] + player["ranged"], player["melee"], player["ranged"],
		enemy["melee"] + enemy["ranged"], enemy["melee"], enemy["ranged"],
	]


func _rebuild_roster_list() -> void:
	for child in _roster_list.get_children():
		_roster_list.remove_child(child)
		child.queue_free()
	if GameState.roster.is_empty():
		var empty := Label.new()
		empty.text = "보유 유닛이 없습니다. 용병을 고용하세요."
		empty.add_theme_color_override("font_color", STATS_COLOR)
		_roster_list.add_child(empty)
		return
	for entry in GameState.roster:
		_roster_list.add_child(_make_roster_row(entry))


func _make_roster_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_make_icon(entry["type"]))
	var name_label := Label.new()
	name_label.text = "%s #%d" % [UnitStats.HIRE[entry["type"]]["label"], entry["id"]]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	if entry["squad"] > 0:
		var squad_label := Label.new()
		squad_label.text = "부대 %d" % entry["squad"]
		squad_label.add_theme_color_override("font_color", SQUAD_COLOR)
		row.add_child(squad_label)
	var check := CheckBox.new()
	check.text = "출전"
	check.set_pressed_no_signal(entry["deployed"])
	check.disabled = not entry["deployed"] and GameState.deployed_count() >= _deploy_cap
	check.toggled.connect(_on_deploy_toggled.bind(entry["id"]))
	row.add_child(check)
	return row


func _make_icon(type: String) -> Label:
	var icon := Label.new()
	icon.text = "●" if type == "ranged" else "■"
	icon.add_theme_color_override("font_color", UNIT_COLOR)
	icon.add_theme_font_size_override("font_size", 26)
	icon.custom_minimum_size = Vector2(30, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return icon


func _build_hire_list() -> void:
	for type in UnitStats.HIRE_ORDER:
		var info: Dictionary = UnitStats.HIRE[type]
		var stats: Dictionary = info["stats"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_make_icon(type))
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = info["label"]
		name_label.add_theme_font_size_override("font_size", 22)
		text_box.add_child(name_label)
		var stats_label := Label.new()
		stats_label.text = "체력 %d · 공격 %d · 사거리 %d\n이속 %d · 공격 간격 %.1f초" % [
			stats["health"], stats["damage"], stats["range"], stats["speed"], stats["cooldown"],
		]
		stats_label.add_theme_color_override("font_color", STATS_COLOR)
		stats_label.add_theme_font_size_override("font_size", 16)
		text_box.add_child(stats_label)
		row.add_child(text_box)
		var button := Button.new()
		button.text = "고용  %d G" % info["price"]
		button.custom_minimum_size = Vector2(150, 48)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_hire_pressed.bind(type))
		row.add_child(button)
		_hire_list.add_child(row)
		_hire_buttons[type] = button


func _on_hire_pressed(type: String) -> void:
	if GameState.hire(type, _deploy_cap):
		_refresh()


func _on_deploy_toggled(pressed: bool, id: int) -> void:
	GameState.set_deployed(id, pressed, _deploy_cap)
	# 눌린 체크박스 자신이 목록 재구성으로 사라지므로 시그널 처리가 끝난 뒤 갱신한다.
	_refresh.call_deferred()


func _format_last_result() -> String:
	match GameState.last_result:
		"win":
			return "직전 전투: 승리 (처치 %d · 생존 %d · 손실 %d · +%d G)" % [
				GameState.last_kills, GameState.last_survivors, GameState.last_player_losses, GameState.last_reward,
			]
		"lose":
			return "직전 전투: 패배 (처치 %d · 아군 손실 %d)" % [GameState.last_kills, GameState.last_player_losses]
		"draw":
			return "직전 전투: 무승부 (처치 %d · 아군 손실 %d)" % [GameState.last_kills, GameState.last_player_losses]
		_:
			return ""


func _on_battle_pressed() -> void:
	if GameState.deployed_count() == 0:
		return
	print("[Prep] battle -> Main (%d deployed)" % GameState.deployed_count())
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_title_pressed() -> void:
	print("[Prep] title")
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
