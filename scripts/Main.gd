extends Node2D

var _selected_unit: Unit = null

@onready var _units: Node2D = $Units


func _ready() -> void:
	for u in _units.get_children():
		if u is Unit:
			(u as Unit).clicked.connect(_on_unit_clicked)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_deselect()
	elif event.button_index == MOUSE_BUTTON_RIGHT and _selected_unit != null:
		_selected_unit.move_to(get_global_mouse_position())


func _on_unit_clicked(unit: Unit) -> void:
	_select(unit)


func _select(unit: Unit) -> void:
	if _selected_unit == unit:
		return
	if _selected_unit != null:
		_selected_unit.set_selected(false)
	_selected_unit = unit
	_selected_unit.set_selected(true)


func _deselect() -> void:
	if _selected_unit != null:
		_selected_unit.set_selected(false)
		_selected_unit = null
