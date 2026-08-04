extends Node2D

var _selected_unit: Unit = null
var _game_over: bool = false

@onready var _units: Node2D = $Units
@onready var _result_label: Label = $UI/ResultLabel


func _ready() -> void:
	for u in _units.get_children():
		if u is Unit:
			var unit := u as Unit
			unit.clicked.connect(_on_unit_clicked)
			unit.died.connect(_on_unit_died)


func _on_unit_died(unit: Unit) -> void:
	print("[Main] on_unit_died: %s" % unit.name)
	if _selected_unit == unit:
		_selected_unit = null
	_check_end_state()


func _check_end_state() -> void:
	if _game_over:
		return
	var players_alive := 0
	var enemies_alive := 0
	for u in get_tree().get_nodes_in_group("units"):
		var unit := u as Unit
		if unit.is_queued_for_deletion():
			continue
		if unit.team == Unit.TEAM_PLAYER:
			players_alive += 1
		else:
			enemies_alive += 1
	print("[Main] end-state check: players=%d enemies=%d" % [players_alive, enemies_alive])
	if players_alive > 0 and enemies_alive > 0:
		return
	_game_over = true
	if players_alive == 0 and enemies_alive == 0:
		_result_label.text = "무승부"
	elif enemies_alive == 0:
		_result_label.text = "승리"
	else:
		_result_label.text = "패배"
	_result_label.visible = true
	print("[Main] GAME OVER -> %s (label visible=%s, text=%s)" % [_result_label.text, _result_label.visible, _result_label.text])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_deselect()
	elif event.button_index == MOUSE_BUTTON_RIGHT and _selected_unit != null:
		var target := get_global_mouse_position()
		_selected_unit.move_to(target)
		print("[Main] move %s -> %s" % [_selected_unit.name, target])


func _on_unit_clicked(unit: Unit) -> void:
	if unit.team != Unit.TEAM_PLAYER:
		print("[Main] click on non-player unit %s (team=%d) ignored" % [unit.name, unit.team])
		return
	_select(unit)


func _select(unit: Unit) -> void:
	if _selected_unit == unit:
		return
	if _selected_unit != null:
		_selected_unit.set_selected(false)
	_selected_unit = unit
	_selected_unit.set_selected(true)
	print("[Main] selected %s" % unit.name)


func _deselect() -> void:
	if _selected_unit != null:
		print("[Main] deselected %s" % _selected_unit.name)
		_selected_unit.set_selected(false)
		_selected_unit = null
