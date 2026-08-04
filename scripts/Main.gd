extends Node2D

var _selected_units: Array[Unit] = []
var _game_over: bool = false
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

@onready var _units: Node2D = $Units
@onready var _result_label: Label = $UI/ResultLabel
@onready var _drag_box: Node2D = $DragBox

const CLICK_DRAG_THRESHOLD: float = 5.0
const MULTI_MOVE_SPACING: float = 50.0
const MoveMarkerScript := preload("res://scripts/MoveMarker.gd")


func _ready() -> void:
	for u in _units.get_children():
		if u is Unit:
			(u as Unit).died.connect(_on_unit_died)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(get_global_mouse_position())
			else:
				_end_drag(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move_command(get_global_mouse_position())
	elif event is InputEventMouseMotion and _dragging:
		_drag_box.show_rect(_make_rect(_drag_start, get_global_mouse_position()))


func _begin_drag(pos: Vector2) -> void:
	_dragging = true
	_drag_start = pos
	_drag_box.show_rect(Rect2(pos, Vector2.ZERO))


func _end_drag(pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	_drag_box.hide_rect()
	if (pos - _drag_start).length() < CLICK_DRAG_THRESHOLD:
		_handle_click(pos)
	else:
		_select_units_in_rect(_make_rect(_drag_start, pos))


func _make_rect(a: Vector2, b: Vector2) -> Rect2:
	var top_left := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var size := Vector2(absf(b.x - a.x), absf(b.y - a.y))
	return Rect2(top_left, size)


func _handle_click(pos: Vector2) -> void:
	var clicked_unit := _unit_at_position(pos)
	if clicked_unit != null and clicked_unit.team == Unit.TEAM_PLAYER:
		print("[Main] click selected %s" % clicked_unit.name)
		_set_selection([clicked_unit])
	else:
		_clear_selection()


func _unit_at_position(pos: Vector2) -> Unit:
	const HALF_UNIT := 20.0
	for u in get_tree().get_nodes_in_group("units"):
		var unit := u as Unit
		if absf(pos.x - unit.global_position.x) <= HALF_UNIT and absf(pos.y - unit.global_position.y) <= HALF_UNIT:
			return unit
	return null


func _select_units_in_rect(rect: Rect2) -> void:
	var found: Array[Unit] = []
	for u in get_tree().get_nodes_in_group("units"):
		var unit := u as Unit
		if unit.team != Unit.TEAM_PLAYER:
			continue
		if rect.has_point(unit.global_position):
			found.append(unit)
	print("[Main] box selected %d units in %s" % [found.size(), rect])
	_set_selection(found)


func _set_selection(units: Array[Unit]) -> void:
	for u in _selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	_selected_units = units
	for u in _selected_units:
		u.set_selected(true)


func _clear_selection() -> void:
	if _selected_units.is_empty():
		return
	print("[Main] cleared selection (%d units)" % _selected_units.size())
	for u in _selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	_selected_units.clear()


func _issue_move_command(target: Vector2) -> void:
	if _selected_units.is_empty():
		return
	_spawn_move_marker(target)
	var count := _selected_units.size()
	if count == 1:
		_selected_units[0].move_to(target)
		print("[Main] move %s -> %s" % [_selected_units[0].name, target])
		return
	var cols := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(cols))
	var center_offset := Vector2(float(cols - 1) * 0.5, float(rows - 1) * 0.5)
	for i in range(count):
		var col := i % cols
		var row := i / cols
		var offset := (Vector2(float(col), float(row)) - center_offset) * MULTI_MOVE_SPACING
		_selected_units[i].move_to(target + offset)
	print("[Main] move %d units -> %s (grid %dx%d)" % [count, target, cols, rows])


func _spawn_move_marker(pos: Vector2) -> void:
	var marker: Node2D = MoveMarkerScript.new()
	marker.position = pos
	add_child(marker)


func _on_unit_died(unit: Unit) -> void:
	print("[Main] on_unit_died: %s" % unit.name)
	_selected_units.erase(unit)
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
