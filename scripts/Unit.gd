class_name Unit
extends Area2D

signal died(unit: Unit)

enum UnitType { MELEE, RANGED }

@export var unit_type: UnitType = UnitType.MELEE
@export var max_health: float = 100.0
@export var move_speed: float = 220.0
@export var team: int = 0
@export var attack_range: float = 160.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 1.0
@export var pushable: bool = true
@export var ai_enabled: bool = true

var health: float
var squad_id: int = 0
var active: bool = true
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _selected: bool = false
var _cooldown_left: float = 0.0
var _flash_time_left: float = 0.0
var _attack_moving: bool = false
var _attack_move_target: Vector2 = Vector2.ZERO
var _auto_engaging: bool = false

const FLASH_DURATION: float = 0.15
const FLASH_COLOR := Color(3.0, 3.0, 3.0, 1.0)
const SEPARATION_RADIUS: float = 42.0
const SEPARATION_SPEED: float = 80.0
const CIRCLE_SIDES := 20
const CIRCLE_RADIUS := 18.0
const RANGED_KITE_MIN_DIST: float = 140.0
const RANGED_KITE_BUFFER: float = 40.0
const PLAYER_AUTO_ENGAGE_RADIUS: float = 220.0
const BATTLEFIELD_MIN := Vector2(60.0, 60.0)
const BATTLEFIELD_MAX := Vector2(1220.0, 660.0)

const ProjectileScript := preload("res://scripts/Projectile.gd")

@onready var _body: Polygon2D = $Body
@onready var _hp_fill: Polygon2D = $HPBarFill
@onready var _squad_label: Label = $SquadLabel

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

const COLOR_PLAYER := Color(0.30, 0.55, 1.00)
const COLOR_PLAYER_SELECTED := Color(0.65, 0.85, 1.00)
const COLOR_ENEMY := Color(1.00, 0.35, 0.30)


func _ready() -> void:
	_apply_type()
	health = max_health
	add_to_group("units")
	_refresh_color()
	_refresh_squad_label()


func _apply_type() -> void:
	var s := UnitStats.RANGED if unit_type == UnitType.RANGED else UnitStats.MELEE
	max_health = s["health"]
	move_speed = s["speed"]
	attack_range = s["range"]
	attack_damage = s["damage"]
	attack_cooldown = s["cooldown"]
	if unit_type == UnitType.RANGED:
		_body.polygon = _make_circle_polygon(CIRCLE_RADIUS, CIRCLE_SIDES)


func _make_circle_polygon(radius: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _physics_process(delta: float) -> void:
	if not active:
		return
	_update_ai()
	_update_combat(delta)
	_update_movement(delta)
	_apply_separation(delta)
	_update_flash(delta)


func _apply_separation(delta: float) -> void:
	if not pushable:
		return
	var push := Vector2.ZERO
	for u in get_tree().get_nodes_in_group("units"):
		if u == self:
			continue
		var other := u as Unit
		if other.is_queued_for_deletion():
			continue
		var diff := global_position - other.global_position
		var dist := diff.length()
		if dist == 0.0:
			push += Vector2(randf() - 0.5, randf() - 0.5)
			continue
		if dist < SEPARATION_RADIUS:
			var overlap := SEPARATION_RADIUS - dist
			push += diff / dist * overlap
	if push == Vector2.ZERO:
		return
	global_position += push.limit_length(SEPARATION_SPEED * delta)


func _update_flash(delta: float) -> void:
	if _flash_time_left <= 0.0:
		return
	_flash_time_left -= delta
	if _flash_time_left <= 0.0:
		modulate = Color.WHITE
		return
	var t := _flash_time_left / FLASH_DURATION
	modulate = Color.WHITE.lerp(FLASH_COLOR, t)


func _update_ai() -> void:
	if team == TEAM_ENEMY:
		if not ai_enabled:
			return
		var target := _find_nearest_enemy()
		if target == null:
			return
		var dist := global_position.distance_to(target.global_position)
		if unit_type == UnitType.RANGED and dist < RANGED_KITE_MIN_DIST:
			var away := global_position - target.global_position
			if away.length() < 1.0:
				away = Vector2.RIGHT.rotated(randf() * TAU)
			var retreat_pos := target.global_position + away.normalized() * (RANGED_KITE_MIN_DIST + RANGED_KITE_BUFFER)
			retreat_pos = retreat_pos.clamp(BATTLEFIELD_MIN, BATTLEFIELD_MAX)
			_set_move_target(retreat_pos)
		elif dist > attack_range:
			_set_move_target(target.global_position)
		else:
			_has_target = false
		return
	if _attack_moving:
		var enemy := _find_nearest_enemy(attack_range)
		if enemy != null:
			_has_target = false
		elif global_position.distance_to(_attack_move_target) > 4.0:
			_set_move_target(_attack_move_target)
		else:
			_attack_moving = false
		return
	if _has_target and not _auto_engaging:
		return
	var seen := _find_nearest_enemy(PLAYER_AUTO_ENGAGE_RADIUS)
	if seen == null:
		if _auto_engaging:
			_auto_engaging = false
			_has_target = false
		return
	if global_position.distance_to(seen.global_position) > attack_range:
		_auto_engaging = true
		_set_move_target(seen.global_position)
	else:
		_auto_engaging = false
		_has_target = false


func _update_combat(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	var target := _pick_combat_target()
	if target != null and _cooldown_left <= 0.0:
		if unit_type == UnitType.RANGED:
			_spawn_projectile(target)
		else:
			target.take_damage(attack_damage)
		_cooldown_left = attack_cooldown


func _pick_combat_target() -> Unit:
	if team == TEAM_ENEMY:
		return _find_nearest_enemy(attack_range)
	if _has_target and not _attack_moving and not _auto_engaging:
		return null
	return _find_nearest_enemy(attack_range)


func _spawn_projectile(target: Unit) -> void:
	var proj := ProjectileScript.new()
	proj.target = target
	proj.damage = attack_damage
	proj.color = Color(0.7, 0.9, 1.0) if team == TEAM_PLAYER else Color(1.0, 0.6, 0.4)
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)


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
	_flash_time_left = FLASH_DURATION
	print("[Unit] %s took %.0f dmg: %.0f -> %.0f" % [name, amount, before, health])
	if health <= 0.0:
		print("[Unit] %s died" % name)
		queue_free()
		died.emit(self)


func _set_move_target(pos: Vector2) -> void:
	_target_pos = pos
	_has_target = true


func move_to(pos: Vector2) -> void:
	_attack_moving = false
	_auto_engaging = false
	_set_move_target(pos)


func attack_move_to(pos: Vector2) -> void:
	_attack_moving = true
	_auto_engaging = false
	_attack_move_target = pos
	_set_move_target(pos)


func stop_actions() -> void:
	_has_target = false
	_attack_moving = false
	_auto_engaging = false


func set_squad(id: int) -> void:
	squad_id = id
	if is_node_ready():
		_refresh_squad_label()


func _refresh_squad_label() -> void:
	if squad_id > 0:
		_squad_label.text = str(squad_id)
		_squad_label.visible = true
	else:
		_squad_label.visible = false


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
