class_name Unit
extends Area2D

signal clicked(unit: Unit)

@export var max_health: float = 100.0
@export var move_speed: float = 220.0
@export var team: int = 0

var health: float
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _selected: bool = false

@onready var _body: Polygon2D = $Body

const COLOR_PLAYER := Color(0.30, 0.55, 1.00)
const COLOR_PLAYER_SELECTED := Color(0.65, 0.85, 1.00)


func _ready() -> void:
	health = max_health
	input_event.connect(_on_input_event)
	_refresh_color()


func _physics_process(delta: float) -> void:
	if not _has_target:
		return
	var to_target := _target_pos - global_position
	var dist := to_target.length()
	var step := move_speed * delta
	if dist <= step:
		global_position = _target_pos
		_has_target = false
	else:
		global_position += to_target / dist * step


func move_to(pos: Vector2) -> void:
	_target_pos = pos
	_has_target = true


func set_selected(v: bool) -> void:
	if _selected == v:
		return
	_selected = v
	_refresh_color()


func _refresh_color() -> void:
	_body.color = COLOR_PLAYER_SELECTED if _selected else COLOR_PLAYER


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		get_viewport().set_input_as_handled()
