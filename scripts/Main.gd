extends Node2D

var _selected_units: Array[Unit] = []
var _game_over: bool = false
var _last_won: bool = false
var _stage_index: int = 0
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _squads: Dictionary = {}
var _attack_armed: bool = false
var _countdown_left: float = 0.0

const SQUAD_KEYS := {KEY_1: 1, KEY_2: 2, KEY_3: 3}

@onready var _units: Node2D = $Units
@onready var _result_label: Label = $UI/ResultLabel
@onready var _selection_label: Label = $UI/SelectionCountLabel
@onready var _countdown_label: Label = $UI/CountdownLabel
@onready var _drag_box: Node2D = $DragBox

const CLICK_DRAG_THRESHOLD: float = 5.0
const MULTI_MOVE_SPACING: float = 50.0
const COUNTDOWN_SECS: float = 3.0
const MoveMarkerScript := preload("res://scripts/MoveMarker.gd")
const UnitScene := preload("res://scenes/Unit.tscn")


func _ready() -> void:
	_load_stage(0)


func _load_stage(idx: int) -> void:
	_stage_index = idx
	var stage: Dictionary = Stages.STAGES[idx]
	print("[Main] load stage %d: %s" % [idx + 1, stage["name"]])
	_clear_battle()
	_spawn_stage_units(stage)
	_start_countdown()


func _clear_battle() -> void:
	for u in get_tree().get_nodes_in_group("units"):
		u.queue_free()
	for p in get_tree().get_nodes_in_group("projectiles"):
		p.queue_free()
	_selected_units.clear()
	_squads.clear()
	_attack_armed = false
	_dragging = false
	_drag_box.hide_rect()
	_game_over = false
	_result_label.visible = false
	_refresh_selection_ui()


func _spawn_stage_units(stage: Dictionary) -> void:
	var counters: Dictionary = {}
	for spec in stage["units"]:
		var u: Unit = UnitScene.instantiate()
		u.team = spec["team"]
		u.unit_type = Unit.UnitType.RANGED if spec["type"] == "ranged" else Unit.UnitType.MELEE
		u.position = spec["pos"]
		var key: String = "%d_%s" % [spec["team"], spec["type"]]
		counters[key] = counters.get(key, 0) + 1
		var prefix: String = "P" if spec["team"] == Unit.TEAM_PLAYER else "E"
		var type_ch: String = "R" if spec["type"] == "ranged" else "M"
		u.name = "%s_%s_%d" % [prefix, type_ch, counters[key]]
		u.active = false
		u.died.connect(_on_unit_died)
		_units.add_child(u)


func _start_countdown() -> void:
	_countdown_left = COUNTDOWN_SECS
	_countdown_label.text = str(int(ceil(COUNTDOWN_SECS)))
	_countdown_label.visible = true
	print("[Main] countdown start: %.1fs" % COUNTDOWN_SECS)


func _process(delta: float) -> void:
	if _countdown_left <= 0.0:
		return
	_countdown_left -= delta
	if _countdown_left <= 0.0:
		_countdown_label.visible = false
		for u in _units.get_children():
			if u is Unit:
				(u as Unit).active = true
		print("[Main] countdown done, battle start")
	else:
		_countdown_label.text = str(int(ceil(_countdown_left)))


func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			var next_idx := _stage_index
			if _last_won:
				next_idx = (_stage_index + 1) % Stages.STAGES.size()
			print("[Main] R restart: stage %d -> %d (won=%s)" % [_stage_index + 1, next_idx + 1, _last_won])
			_load_stage(next_idx)
		return
	if _countdown_left > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _attack_armed:
					_issue_movement(get_global_mouse_position(), true)
					_attack_armed = false
					return
				_begin_drag(get_global_mouse_position())
			else:
				_end_drag(get_global_mouse_position(), event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _attack_armed:
				_attack_armed = false
				print("[Main] attack armed canceled (RMB)")
				return
			_issue_movement(get_global_mouse_position(), false)
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
		print("[Main] attack armed canceled")


func _assign_squad(num: int) -> void:
	var alive: Array[Unit] = []
	for u in _selected_units:
		if is_instance_valid(u):
			alive.append(u)
	for u in get_tree().get_nodes_in_group("units"):
		var unit := u as Unit
		if unit.squad_id == num and not alive.has(unit):
			unit.set_squad(0)
	for u in alive:
		u.set_squad(num)
	_squads[num] = alive
	print("[Main] squad %d assigned: %d units" % [num, alive.size()])


func _select_squad(num: int) -> void:
	if not _squads.has(num):
		return
	var alive: Array[Unit] = []
	for u in _squads[num]:
		if is_instance_valid(u) and not (u as Node).is_queued_for_deletion():
			alive.append(u)
	_squads[num] = alive
	print("[Main] select squad %d: %d units" % [num, alive.size()])
	_set_selection(alive)


func _stop_selected() -> void:
	if _selected_units.is_empty():
		return
	var count := 0
	for u in _selected_units:
		if is_instance_valid(u):
			u.stop_actions()
			count += 1
	print("[Main] stop %d units" % count)


func _arm_attack_move() -> void:
	if _selected_units.is_empty():
		return
	_attack_armed = true
	print("[Main] attack armed (%d units)" % _selected_units.size())


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
	var top_left := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var size := Vector2(absf(b.x - a.x), absf(b.y - a.y))
	return Rect2(top_left, size)


func _handle_click(pos: Vector2, additive: bool) -> void:
	var clicked_unit := _unit_at_position(pos)
	if clicked_unit != null and clicked_unit.team == Unit.TEAM_PLAYER:
		if additive:
			_toggle_in_selection(clicked_unit)
		else:
			print("[Main] click selected %s" % clicked_unit.name)
			_set_selection([clicked_unit])
	elif not additive:
		_clear_selection()


func _unit_at_position(pos: Vector2) -> Unit:
	const HALF_UNIT := 20.0
	for u in get_tree().get_nodes_in_group("units"):
		var unit := u as Unit
		if absf(pos.x - unit.global_position.x) <= HALF_UNIT and absf(pos.y - unit.global_position.y) <= HALF_UNIT:
			return unit
	return null


func _select_units_in_rect(rect: Rect2, additive: bool) -> void:
	var found: Array[Unit] = []
	for u in get_tree().get_nodes_in_group("units"):
		var unit := u as Unit
		if unit.team != Unit.TEAM_PLAYER:
			continue
		if rect.has_point(unit.global_position):
			found.append(unit)
	if additive:
		var merged: Array[Unit] = []
		for u in _selected_units:
			if is_instance_valid(u):
				merged.append(u)
		for u in found:
			if not merged.has(u):
				merged.append(u)
		print("[Main] box added %d units (total %d) in %s" % [found.size(), merged.size(), rect])
		_set_selection(merged)
	else:
		print("[Main] box selected %d units in %s" % [found.size(), rect])
		_set_selection(found)


func _toggle_in_selection(unit: Unit) -> void:
	var current: Array[Unit] = []
	for u in _selected_units:
		if is_instance_valid(u):
			current.append(u)
	if current.has(unit):
		current.erase(unit)
		print("[Main] shift+click removed %s (now %d)" % [unit.name, current.size()])
	else:
		current.append(unit)
		print("[Main] shift+click added %s (now %d)" % [unit.name, current.size()])
	_set_selection(current)


func _set_selection(units: Array[Unit]) -> void:
	for u in _selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	_selected_units = units.duplicate()
	for u in _selected_units:
		u.set_selected(true)
	_refresh_selection_ui()


func _clear_selection() -> void:
	if _selected_units.is_empty():
		return
	print("[Main] cleared selection (%d units)" % _selected_units.size())
	for u in _selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	_selected_units.clear()
	_refresh_selection_ui()


func _refresh_selection_ui() -> void:
	var count := _selected_units.size()
	_selection_label.text = "선택: %d" % count
	_selection_label.visible = count > 0


func _issue_movement(target: Vector2, attack_move: bool) -> void:
	if _selected_units.is_empty():
		return
	_spawn_move_marker(target)
	var mode := "attack-move" if attack_move else "move"
	var count := _selected_units.size()
	if count == 1:
		_apply_move(_selected_units[0], target, attack_move)
		print("[Main] %s %s -> %s" % [mode, _selected_units[0].name, target])
		return
	var cols := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(cols))
	var center_offset := Vector2(float(cols - 1) * 0.5, float(rows - 1) * 0.5)
	for i in range(count):
		var col := i % cols
		var row := i / cols
		var offset := (Vector2(float(col), float(row)) - center_offset) * MULTI_MOVE_SPACING
		_apply_move(_selected_units[i], target + offset, attack_move)
	print("[Main] %s %d units -> %s (grid %dx%d)" % [mode, count, target, cols, rows])


func _apply_move(unit: Unit, pos: Vector2, attack_move: bool) -> void:
	if attack_move:
		unit.attack_move_to(pos)
	else:
		unit.move_to(pos)


func _spawn_move_marker(pos: Vector2) -> void:
	var marker: Node2D = MoveMarkerScript.new()
	marker.position = pos
	add_child(marker)


func _on_unit_died(unit: Unit) -> void:
	print("[Main] on_unit_died: %s" % unit.name)
	if _selected_units.has(unit):
		_selected_units.erase(unit)
		_refresh_selection_ui()
	for num in _squads.keys():
		if _squads[num].has(unit):
			_squads[num].erase(unit)
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
	var stage_num := _stage_index + 1
	var last_stage := _stage_index + 1 >= Stages.STAGES.size()
	if players_alive == 0 and enemies_alive == 0:
		_last_won = false
		_result_label.text = "무승부\n[R] 재도전"
	elif enemies_alive == 0:
		_last_won = true
		if last_stage:
			_result_label.text = "완주!\n[R] 처음부터"
		else:
			_result_label.text = "스테이지 %d 클리어!\n[R] 다음" % stage_num
	else:
		_last_won = false
		_result_label.text = "패배\n[R] 재도전"
	_result_label.visible = true
	print("[Main] GAME OVER stage=%d won=%s -> %s" % [stage_num, _last_won, _result_label.text])
