extends Node2D
# 전투 씬 진행: 스테이지 로드 → 유닛 스폰 → 카운트다운 → 승패 판정 → 결과 표시.
# 선택/명령 입력은 SelectionController, 결과 오버레이는 ResultPanel,
# 캠페인 규칙(보상·손실·진행·세이브)은 GameState가 맡는다.

const COUNTDOWN_SECS: float = 3.0
const UnitScene := preload("res://scenes/Unit.tscn")

var _stage_index: int = 0
var _stage: Dictionary = {}
var _battle_over: bool = false
var _countdown_left: float = 0.0
var _initial_enemy_count: int = 0
var _initial_player_count: int = 0
var _dead_roster_ids: Array[int] = []
var _outcome: String = ""

@onready var _units: Node2D = $Units
@onready var _projectiles: Node2D = $Projectiles
@onready var _battlefield: Polygon2D = $Battlefield
@onready var _selection: SelectionController = $Selection
@onready var _result_panel: ResultPanel = $UI/ResultPanel
@onready var _selection_label: Label = $UI/SelectionCountLabel
@onready var _countdown_label: Label = $UI/CountdownLabel
@onready var _money_label: Label = $UI/MoneyLabel


func _ready() -> void:
	_selection.selection_changed.connect(_on_selection_changed)
	_result_panel.primary_pressed.connect(_on_primary_result_pressed)
	_result_panel.secondary_pressed.connect(_on_secondary_result_pressed)
	_on_selection_changed(0)
	_refresh_money()
	_load_stage(GameState.current_stage)


# --- 스테이지 준비 ---

func _load_stage(idx: int) -> void:
	_stage_index = idx
	_stage = Stages.get_stage(idx)
	print("[Main] load stage %d: %s" % [idx + 1, _stage["name"]])
	_apply_battlefield(_stage["battlefield"])
	_spawn_enemies()
	_spawn_players()
	print("[Main] spawned %d players (roster %d) vs %d enemies" % [
		_initial_player_count, GameState.roster.size(), _initial_enemy_count,
	])
	if _initial_player_count == 0:
		print("[Main] no deployed units, back to Prep")
		Scenes.go.call_deferred(get_tree(), Scenes.PREP)
		return
	_start_countdown()


func _apply_battlefield(rect: Rect2) -> void:
	_battlefield.polygon = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func _spawn_enemies() -> void:
	var counters: Dictionary = {}
	for spec in _stage["enemies"]:
		var type: String = spec["type"]
		counters[type] = counters.get(type, 0) + 1
		var enemy := _make_unit(Unit.TEAM_ENEMY, type, spec["pos"])
		enemy.name = "E_%s_%d" % [UnitTypes.get_def(type)["code"], counters[type]]
		_units.add_child(enemy)
		_initial_enemy_count += 1


func _spawn_players() -> void:
	GameState.clamp_deployment(Stages.deploy_cap(_stage))
	var deployed := GameState.deployed_units()
	var positions := Stages.assign_slots(_stage, deployed)
	for i in range(deployed.size()):
		var entry: Dictionary = deployed[i]
		var unit := _make_unit(Unit.TEAM_PLAYER, entry["type"], positions[i])
		unit.roster_id = entry["id"]
		unit.name = "P_%s_%d" % [UnitTypes.get_def(entry["type"])["code"], entry["id"]]
		if entry["squad"] > 0:
			_selection.restore_squad_member(unit, entry["squad"])
		_units.add_child(unit)
		_initial_player_count += 1


func _make_unit(team: int, type: String, pos: Vector2) -> Unit:
	var unit: Unit = UnitScene.instantiate()
	unit.team = team
	unit.type_id = type
	unit.position = pos
	unit.battlefield_rect = _stage["battlefield"]
	unit.projectile_parent = _projectiles
	unit.active = false
	unit.died.connect(_on_unit_died)
	return unit


# --- 카운트다운 ---

func _start_countdown() -> void:
	_countdown_left = COUNTDOWN_SECS
	_countdown_label.text = str(ceili(COUNTDOWN_SECS))
	_countdown_label.visible = true
	print("[Main] countdown start: %.1fs" % COUNTDOWN_SECS)


func _process(delta: float) -> void:
	if _countdown_left <= 0.0:
		return
	_countdown_left -= delta
	if _countdown_left > 0.0:
		_countdown_label.text = str(ceili(_countdown_left))
		return
	_countdown_label.visible = false
	for node in _units.get_children():
		(node as Unit).active = true
	_selection.enabled = true
	print("[Main] countdown done, battle start")


# --- 전투 중 이벤트 ---

func _on_selection_changed(count: int) -> void:
	_selection_label.text = "선택: %d" % count
	_selection_label.visible = count > 0


func _on_unit_died(unit: Unit) -> void:
	print("[Main] on_unit_died: %s" % unit.name)
	_selection.forget_unit(unit)
	if _battle_over:
		return
	if unit.roster_id >= 0 and not _dead_roster_ids.has(unit.roster_id):
		_dead_roster_ids.append(unit.roster_id)
	_check_end_state()


func _check_end_state() -> void:
	var players_alive := 0
	var enemies_alive := 0
	for node in _units.get_children():
		var unit := node as Unit
		if not unit.is_alive():
			continue
		if unit.team == Unit.TEAM_PLAYER:
			players_alive += 1
		else:
			enemies_alive += 1
	print("[Main] end-state check: players=%d enemies=%d" % [players_alive, enemies_alive])
	if players_alive > 0 and enemies_alive > 0:
		return
	var result := GameState.RESULT_LOSE
	if players_alive == 0 and enemies_alive == 0:
		result = GameState.RESULT_DRAW
	elif enemies_alive == 0:
		result = GameState.RESULT_WIN
	_finish_battle(result, players_alive, enemies_alive)


# --- 결과 ---

func _finish_battle(result: String, players_alive: int, enemies_alive: int) -> void:
	_battle_over = true
	_selection.enabled = false
	var kills := _initial_enemy_count - enemies_alive
	var losses := _initial_player_count - players_alive
	_outcome = GameState.conclude_battle(result, kills, losses, players_alive, _dead_roster_ids)
	_refresh_money()
	var secondary := "" if _result_goes_to_title() else "타이틀로"
	_result_panel.show_result(_result_title(result), _result_stats(kills, losses, players_alive), _primary_text(), secondary)
	print("[Main] BATTLE END stage=%d result=%s outcome=%s kills=%d losses=%d" % [
		_stage_index + 1, result, _outcome, kills, losses,
	])


func _result_goes_to_title() -> bool:
	return _outcome == GameState.OUTCOME_COMPLETE or _outcome == GameState.OUTCOME_GAME_OVER


func _result_title(result: String) -> String:
	match _outcome:
		GameState.OUTCOME_COMPLETE:
			return "완주!"
		GameState.OUTCOME_NEXT:
			return "스테이지 %d 클리어" % (_stage_index + 1)
		GameState.OUTCOME_GAME_OVER:
			return "게임 오버"
	return "무승부" if result == GameState.RESULT_DRAW else "패배"


func _primary_text() -> String:
	match _outcome:
		GameState.OUTCOME_NEXT:
			return "다음 스테이지"
		GameState.OUTCOME_RETRY:
			return "재정비"
	return "타이틀로"


func _result_stats(kills: int, losses: int, players_alive: int) -> String:
	var lines: PackedStringArray = ["처치 %d · 아군 생존 %d / %d" % [kills, players_alive, _initial_player_count]]
	if losses > 0:
		lines.append("전사 %d명 영구 손실 (남은 보유 유닛 %d)" % [losses, GameState.roster.size()])
	if GameState.last_reward > 0:
		lines.append("보상 %d G (기본 %d + 처치 %d×%d)" % [
			GameState.last_reward, Stages.reward(_stage_index), kills, GameState.KILL_BOUNTY,
		])
	if _outcome == GameState.OUTCOME_GAME_OVER:
		lines.append("남은 유닛도, 고용할 돈도 없습니다")
	return "\n".join(lines)


func _refresh_money() -> void:
	_money_label.text = "잔액: %d G" % GameState.money


func _on_primary_result_pressed() -> void:
	Scenes.go(get_tree(), Scenes.TITLE if _result_goes_to_title() else Scenes.PREP)


func _on_secondary_result_pressed() -> void:
	Scenes.go(get_tree(), Scenes.TITLE)
