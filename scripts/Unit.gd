class_name Unit
extends Area2D

signal clicked(unit: Unit)
signal died(unit: Unit)

@export var max_health: float = 100.0
@export var move_speed: float = 220.0
@export var team: int = 0
@export var attack_range: float = 160.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 1.0

var health: float
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _selected: bool = false
var _cooldown_left: float = 0.0

@onready var _body: Polygon2D = $Body
@onready var _hp_fill: Polygon2D = $HPBarFill

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

const COLOR_PLAYER := Color(0.30, 0.55, 1.00)
const COLOR_PLAYER_SELECTED := Color(0.65, 0.85, 1.00)
const COLOR_ENEMY := Color(1.00, 0.35, 0.30)


func _ready() -> void:
	health = max_health
	add_to_group("units")
	input_event.connect(_on_input_event)
	_refresh_color()


func _physics_process(delta: float) -> void:
	_update_ai()
	_update_combat(delta)
	_update_movement(delta)


func _update_ai() -> void:
	if team != TEAM_ENEMY:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	if global_position.distance_to(target.global_position) > attack_range:
		move_to(target.global_position)
	else:
		_has_target = false


func _update_combat(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	var target := _find_nearest_enemy(attack_range)
	if target != null and _cooldown_left <= 0.0:
		target.take_damage(attack_damage)
		_cooldown_left = attack_cooldown


func _update_movement(delta: float) -> void:
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


func _find_nearest_enemy(max_range: float = INF) -> Unit:
	var max_range_sq := max_range * max_range
	var closest: Unit = null
	var closest_dist_sq := max_range_sq
	for u in get_tree().get_nodes_in_group("units"):
		if u == self or (u as Unit).team == team:
			continue
		var d := global_position.distance_squared_to((u as Unit).global_position)
		if d <= closest_dist_sq:
			closest_dist_sq = d
			closest = u
	return closest


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	var before := health
	health -= amount
	_hp_fill.scale.x = clampf(health / max_health, 0.0, 1.0)
	print("[Unit] %s took %.0f dmg: %.0f -> %.0f" % [name, amount, before, health])
	if health <= 0.0:
		print("[Unit] %s died" % name)
		queue_free()
		died.emit(self)


func move_to(pos: Vector2) -> void:
	_target_pos = pos
	_has_target = true


func set_selected(v: bool) -> void:
	if _selected == v:
		return
	_selected = v
	_refresh_color()


func _refresh_color() -> void:
	if team == TEAM_ENEMY:
		_body.color = COLOR_ENEMY
	else:
		_body.color = COLOR_PLAYER_SELECTED if _selected else COLOR_PLAYER


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		get_viewport().set_input_as_handled()
