class_name SelectionController
extends Node2D
# 아군 유닛 선택 · 부대 지정 · 이동/정지/어택무브 명령 입력을 담당한다.
# 전투 진행(Main)과는 enabled, restore_squad_member(), forget_unit(), selection_changed로만 연결된다.

signal selection_changed(count: int)

const SQUAD_KEYS := {KEY_1: 1, KEY_2: 2, KEY_3: 3}
const CLICK_DRAG_THRESHOLD: float = 5.0
const MULTI_MOVE_SPACING: float = 50.0
const MoveMarkerScript := preload("res://scripts/MoveMarker.gd")

# false면 입력을 받지 않는다 (카운트다운 중, 전투 종료 후).
var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled:
			_cancel_pending_input()

var _selected: Array[Unit] = []
var _squads: Dictionary = {}  # 부대 번호 -> Array[Unit]
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _attack_armed: bool = false

@onready var _drag_box: Node2D = $DragBox


# --- Main이 호출하는 API ---

# 세이브된 부대 지정을 스폰 시점에 복원한다.
func restore_squad_member(unit: Unit, num: int) -> void:
	unit.set_squad(num)
	_squad(num).append(unit)


# 죽은 유닛을 선택과 부대에서 뺀다.
func forget_unit(unit: Unit) -> void:
	if _selected.has(unit):
		_selected.erase(unit)
		selection_changed.emit(_selected.size())
	for num in _squads:
		_squads[num].erase(unit)


# --- 입력 ---

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging:
		_drag_box.show_rect(_make_rect(_drag_start, get_global_mouse_position()))


func _handle_key(event: InputEventKey) -> void:
	if SQUAD_KEYS.has(event.keycode):
		var num: int = SQUAD_KEYS[event.keycode]
		if event.ctrl_pressed or event.meta_pressed:
			_assign_squad(num)
		else:
			_select_squad(num)
	elif event.keycode == KEY_S:
		_stop_selected()
	elif event.keycode == KEY_A:
		_arm_attack_move()
	elif event.keycode == KEY_ESCAPE and _attack_armed:
		_attack_armed = false
		print("[Selection] attack armed canceled")


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := get_global_mouse_position()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_end_drag(pos, event.shift_pressed)
		elif _attack_armed:
			_attack_armed = false
			_issue_movement(pos, true)
		else:
			_begin_drag(pos)
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _attack_armed:
			_attack_armed = false
			print("[Selection] attack armed canceled (RMB)")
		else:
			_issue_movement(pos, false)


func _cancel_pending_input() -> void:
	_attack_armed = false
	_dragging = false
	if is_node_ready():
		_drag_box.hide_rect()


# --- 드래그 / 클릭 선택 ---

func _begin_drag(pos: Vector2) -> void:
	_dragging = true
	_drag_start = pos
	_drag_box.show_rect(Rect2(pos, Vector2.ZERO))


func _end_drag(pos: Vector2, additive: bool) -> void:
	if not _dragging:
		return
	_dragging = false
	_drag_box.hide_rect()
	if (pos - _drag_start).length() < CLICK_DRAG_THRESHOLD:
		_handle_click(pos, additive)
	else:
		_select_units_in_rect(_make_rect(_drag_start, pos), additive)


func _make_rect(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(a, b - a).abs()


func _handle_click(pos: Vector2, additive: bool) -> void:
	var clicked := _player_unit_at(pos)
	if clicked == null:
		if not additive:
			_set_selection([])
	elif additive:
		_toggle_in_selection(clicked)
	else:
		print("[Selection] click selected %s" % clicked.name)
		_set_selection([clicked])


func _player_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		var unit := node as Unit
		if unit.team == Unit.TEAM_PLAYER and unit.is_alive():
			out.append(unit)
	return out


func _player_unit_at(pos: Vector2) -> Unit:
	for unit in _player_units():
		if unit.contains_point(pos):
			return unit
	return null


func _select_units_in_rect(rect: Rect2, additive: bool) -> void:
	var picked: Array[Unit] = _alive(_selected) if additive else ([] as Array[Unit])
	var found := 0
	for unit in _player_units():
		if rect.has_point(unit.global_position):
			found += 1
			if not picked.has(unit):
				picked.append(unit)
	print("[Selection] box %s %d units (total %d) in %s" % ["added" if additive else "selected", found, picked.size(), rect])
	_set_selection(picked)


func _toggle_in_selection(unit: Unit) -> void:
	var current := _alive(_selected)
	if current.has(unit):
		current.erase(unit)
		print("[Selection] shift+click removed %s (now %d)" % [unit.name, current.size()])
	else:
		current.append(unit)
		print("[Selection] shift+click added %s (now %d)" % [unit.name, current.size()])
	_set_selection(current)


func _set_selection(units: Array[Unit]) -> void:
	for unit in _alive(_selected):
		unit.set_selected(false)
	_selected = units.duplicate()
	for unit in _selected:
		unit.set_selected(true)
	selection_changed.emit(_selected.size())


func _alive(units: Array) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit in units:
		if is_instance_valid(unit) and unit.is_alive():
			out.append(unit)
	return out


# --- 부대 ---

func _squad(num: int) -> Array[Unit]:
	if not _squads.has(num):
		var members: Array[Unit] = []
		_squads[num] = members
	return _squads[num]


func _assign_squad(num: int) -> void:
	var members := _alive(_selected)
	for unit in _squad(num):
		if is_instance_valid(unit) and not members.has(unit):
			_set_unit_squad(unit, 0)
	# 한 유닛은 한 부대에만 속한다.
	for other in _squads:
		if other != num:
			for unit in members:
				_squads[other].erase(unit)
	for unit in members:
		_set_unit_squad(unit, num)
	_squads[num] = members
	print("[Selection] squad %d assigned: %d units" % [num, members.size()])


func _set_unit_squad(unit: Unit, num: int) -> void:
	unit.set_squad(num)
	if unit.roster_id >= 0:
		GameState.set_unit_squad(unit.roster_id, num)


func _select_squad(num: int) -> void:
	if not _squads.has(num):
		return
	var members := _alive(_squads[num])
	_squads[num] = members
	print("[Selection] select squad %d: %d units" % [num, members.size()])
	_set_selection(members)


# --- 명령 ---

func _stop_selected() -> void:
	var units := _alive(_selected)
	if units.is_empty():
		return
	for unit in units:
		unit.stop_actions()
	print("[Selection] stop %d units" % units.size())


func _arm_attack_move() -> void:
	if _selected.is_empty():
		return
	_attack_armed = true
	print("[Selection] attack armed (%d units)" % _selected.size())


func _issue_movement(target: Vector2, attack_move: bool) -> void:
	var units := _alive(_selected)
	if units.is_empty():
		return
	_spawn_move_marker(target)
	var count := units.size()
	var cols := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(cols))
	var center := Vector2(float(cols - 1), float(rows - 1)) * 0.5
	for i in range(count):
		var cell := Vector2(float(i % cols), float(i / cols))
		var pos := target + (cell - center) * MULTI_MOVE_SPACING
		if attack_move:
			units[i].attack_move_to(pos)
		else:
			units[i].move_to(pos)
	print("[Selection] %s %d units -> %s (grid %dx%d)" % [
		"attack-move" if attack_move else "move", count, target, cols, rows,
	])


func _spawn_move_marker(pos: Vector2) -> void:
	var marker: Node2D = MoveMarkerScript.new()
	marker.position = to_local(pos)
	add_child(marker)
