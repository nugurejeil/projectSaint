class_name Unit
extends Area2D
# 전투 유닛 하나. 수치와 행동 특성은 UnitTypes에서 type_id로 읽어 온다.

signal died(unit: Unit)

const GROUP := "units"
const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const HALF_SIZE: float = 20.0

const FLASH_DURATION: float = 0.15
const FLASH_COLOR := Color(3.0, 3.0, 3.0, 1.0)
const SEPARATION_RADIUS: float = 42.0
const SEPARATION_SPEED: float = 80.0
const CIRCLE_SIDES := 20
const CIRCLE_RADIUS := 18.0
const RANGED_KITE_MIN_DIST: float = 140.0
const RANGED_KITE_BUFFER: float = 40.0
const PLAYER_AUTO_ENGAGE_RADIUS: float = 220.0
const ARRIVE_EPSILON: float = 4.0

const COLOR_PLAYER := Color(0.30, 0.55, 1.00)
const COLOR_PLAYER_SELECTED := Color(0.65, 0.85, 1.00)
const COLOR_ENEMY := Color(1.00, 0.35, 0.30)
const PROJECTILE_COLOR_PLAYER := Color(0.7, 0.9, 1.0)
const PROJECTILE_COLOR_ENEMY := Color(1.0, 0.6, 0.4)

const ProjectileScript := preload("res://scripts/Projectile.gd")

# 스폰하는 쪽(Main)이 add_child 전에 채우는 값
var type_id: String = "melee"
var team: int = TEAM_PLAYER
var roster_id: int = -1
var battlefield_rect: Rect2 = Rect2(40, 40, 1200, 640)
var projectile_parent: Node = null
var pushable: bool = true
var ai_enabled: bool = true
var active: bool = true

var squad_id: int = 0
var max_health: float = 100.0
var health: float = 100.0
var move_speed: float = 220.0
var attack_range: float = 160.0
var attack_damage: float = 20.0
var attack_cooldown: float = 1.0

var _uses_projectile: bool = false
var _enemy_kites: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _selected: bool = false
var _cooldown_left: float = 0.0
var _flash_time_left: float = 0.0
var _attack_moving: bool = false
var _attack_move_target: Vector2 = Vector2.ZERO
var _auto_engaging: bool = false

@onready var _body: Polygon2D = $Body
@onready var _hp_fill: Polygon2D = $HPBarFill
@onready var _squad_label: Label = $SquadLabel


func _ready() -> void:
	_apply_type()
	health = max_health
	add_to_group(GROUP)
	_refresh_color()
	_refresh_squad_label()


func _apply_type() -> void:
	var def: Dictionary = UnitTypes.get_def(type_id)
	var s: Dictionary = UnitTypes.stats(type_id, team == TEAM_PLAYER)
	max_health = s["health"]
	move_speed = s["speed"]
	attack_range = s["range"]
	attack_damage = s["damage"]
	attack_cooldown = s["cooldown"]
	_uses_projectile = def["projectile"]
	_enemy_kites = def["enemy_kites"]
	if def["shape"] == UnitTypes.SHAPE_CIRCLE:
		_body.polygon = _make_circle_polygon(CIRCLE_RADIUS, CIRCLE_SIDES)


func _make_circle_polygon(radius: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func is_alive() -> bool:
	return health > 0.0 and not is_queued_for_deletion()


func _physics_process(delta: float) -> void:
	if not active:
		return
	if team == TEAM_ENEMY:
		_update_enemy_ai()
	else:
		_update_player_ai()
	_update_combat(delta)
	_update_movement(delta)
	_apply_separation(delta)
	_update_flash(delta)


# --- AI ---

func _update_enemy_ai() -> void:
	if not ai_enabled:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	if _enemy_kites and dist < RANGED_KITE_MIN_DIST:
		_set_move_target(_kite_position(target))
	elif dist > attack_range:
		_set_move_target(target.global_position)
	else:
		_has_target = false


func _kite_position(threat: Unit) -> Vector2:
	var away := global_position - threat.global_position
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var retreat_pos := threat.global_position + away.normalized() * (RANGED_KITE_MIN_DIST + RANGED_KITE_BUFFER)
	var inset := Vector2(HALF_SIZE, HALF_SIZE)
	return retreat_pos.clamp(battlefield_rect.position + inset, battlefield_rect.end - inset)


func _update_player_ai() -> void:
	if _attack_moving:
		if _find_nearest_enemy(attack_range) != null:
			_has_target = false
		elif global_position.distance_to(_attack_move_target) > ARRIVE_EPSILON:
			_set_move_target(_attack_move_target)
		else:
			_attack_moving = false
		return
	# 일반 이동 명령 중에는 교전하지 않고 끝까지 이동한다.
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


# --- 전투 ---

func _update_combat(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _cooldown_left > 0.0:
		return
	var target := _pick_combat_target()
	if target == null:
		return
	if _uses_projectile:
		_spawn_projectile(target)
	else:
		target.take_damage(attack_damage)
	_cooldown_left = attack_cooldown


func _pick_combat_target() -> Unit:
	if team == TEAM_PLAYER and _has_target and not _attack_moving and not _auto_engaging:
		return null
	return _find_nearest_enemy(attack_range)


func _spawn_projectile(target: Unit) -> void:
	var parent: Node = projectile_parent if is_instance_valid(projectile_parent) else get_parent()
	if parent == null:
		return
	var proj := ProjectileScript.new()
	proj.target = target
	proj.damage = attack_damage
	proj.color = PROJECTILE_COLOR_PLAYER if team == TEAM_PLAYER else PROJECTILE_COLOR_ENEMY
	proj.position = global_position
	parent.add_child(proj)


func _find_nearest_enemy(max_range: float = INF) -> Unit:
	var closest: Unit = null
	var closest_dist_sq := max_range * max_range
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit
		if other == self or other.team == team or not other.is_alive():
			continue
		var d := global_position.distance_squared_to(other.global_position)
		if d <= closest_dist_sq:
			closest_dist_sq = d
			closest = other
	return closest


func take_damage(amount: float) -> void:
	if not is_alive():
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


# --- 이동 ---

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


func _apply_separation(delta: float) -> void:
	if not pushable:
		return
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Unit
		if other == self or not other.is_alive():
			continue
		var diff := global_position - other.global_position
		var dist := diff.length()
		if dist == 0.0:
			push += Vector2(randf() - 0.5, randf() - 0.5)
		elif dist < SEPARATION_RADIUS:
			push += diff / dist * (SEPARATION_RADIUS - dist)
	if push != Vector2.ZERO:
		global_position += push.limit_length(SEPARATION_SPEED * delta)


func _set_move_target(pos: Vector2) -> void:
	_target_pos = pos
	_has_target = true


# --- 명령 (SelectionController가 호출) ---

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


func contains_point(pos: Vector2) -> bool:
	return absf(pos.x - global_position.x) <= HALF_SIZE and absf(pos.y - global_position.y) <= HALF_SIZE


# --- 표시 ---

func set_squad(id: int) -> void:
	squad_id = id
	if is_node_ready():
		_refresh_squad_label()


func set_selected(v: bool) -> void:
	if _selected == v:
		return
	_selected = v
	_refresh_color()


func _refresh_squad_label() -> void:
	_squad_label.visible = squad_id > 0
	if squad_id > 0:
		_squad_label.text = str(squad_id)


func _refresh_color() -> void:
	if team == TEAM_ENEMY:
		_body.color = COLOR_ENEMY
	else:
		_body.color = COLOR_PLAYER_SELECTED if _selected else COLOR_PLAYER


func _update_flash(delta: float) -> void:
	if _flash_time_left <= 0.0:
		return
	_flash_time_left -= delta
	if _flash_time_left <= 0.0:
		modulate = Color.WHITE
		return
	modulate = Color.WHITE.lerp(FLASH_COLOR, _flash_time_left / FLASH_DURATION)
