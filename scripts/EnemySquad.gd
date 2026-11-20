class_name EnemySquad
extends Node
# 적 부대 하나. 교전 전까지는 대형을 유지한 채 함께 움직이고(공격형) 또는 제자리를 지키다가(방어형),
# 부대원 한 명이라도 적을 포착하거나 피격되면 부대 전체가 교전에 들어가 각자의 유닛 AI로 싸운다.
# 부대 구성과 행동 패턴은 스테이지 데이터(Stages)의 enemies[].squad / enemy_squads에서 온다.

const BEHAVIOR_ATTACK := "attack"  # 가장 가까운 아군을 향해 대형째 접근
const BEHAVIOR_DEFEND := "defend"  # 포착·피격 전까지 제자리 대기
const BEHAVIORS := [BEHAVIOR_ATTACK, BEHAVIOR_DEFEND]
# 사거리가 짧은 유닛도 이 거리 안에 아군이 들어오면 포착한 것으로 본다.
const AGGRO_RADIUS: float = 260.0

var behavior: String = BEHAVIOR_ATTACK

var _members: Array[Unit] = []
var _offsets: Dictionary = {}  # Unit -> 대형 중심으로부터의 위치
var _engaged: bool = false


func add_member(unit: Unit) -> void:
	_members.append(unit)
	unit.ai_enabled = false
	unit.died.connect(_on_member_died)
	unit.damaged.connect(_on_member_damaged)


func is_engaged() -> bool:
	return _engaged


func _physics_process(_delta: float) -> void:
	if _engaged or _members.is_empty() or not _members[0].active:
		return
	var foes := _foes()
	if foes.is_empty():
		return
	var spotter := _find_spotter(foes)
	if spotter != null:
		_engage("%s spotted a foe" % spotter.name)
	elif behavior == BEHAVIOR_ATTACK:
		_advance(foes)


func _foes() -> Array[Unit]:
	var out: Array[Unit] = []
	for node in get_tree().get_nodes_in_group(Unit.GROUP):
		var unit := node as Unit
		if unit.team != Unit.TEAM_ENEMY and unit.is_alive():
			out.append(unit)
	return out


func _find_spotter(foes: Array[Unit]) -> Unit:
	for member in _members:
		var radius := maxf(member.attack_range, AGGRO_RADIUS)
		for foe in foes:
			if member.global_position.distance_squared_to(foe.global_position) <= radius * radius:
				return member
	return null


func _center() -> Vector2:
	var sum := Vector2.ZERO
	for member in _members:
		sum += member.global_position
	return sum / float(_members.size())


# 가장 느린 부대원 속도에 맞춰, 처음 대형 그대로 가장 가까운 아군 쪽으로 이동한다.
func _advance(foes: Array[Unit]) -> void:
	var center := _center()
	if _offsets.is_empty():
		var slowest := INF
		for member in _members:
			_offsets[member] = member.global_position - center
			slowest = minf(slowest, member.move_speed)
		for member in _members:
			member.speed_limit = slowest
		print("[EnemySquad] %s advancing: %d units at speed %.0f" % [name, _members.size(), slowest])
	var goal := foes[0].global_position
	for foe in foes:
		if center.distance_squared_to(foe.global_position) < center.distance_squared_to(goal):
			goal = foe.global_position
	for member in _members:
		member.move_to(goal + _offsets[member])


func _engage(reason: String) -> void:
	_engaged = true
	set_physics_process(false)
	for member in _members:
		member.speed_limit = INF
		member.stop_actions()
		member.ai_enabled = true
	print("[EnemySquad] %s (%s) engaged: %s — %d units" % [name, behavior, reason, _members.size()])


func _on_member_damaged(unit: Unit) -> void:
	if not _engaged:
		_engage("%s was hit" % unit.name)


func _on_member_died(unit: Unit) -> void:
	_members.erase(unit)
	_offsets.erase(unit)
	if not _engaged and not _members.is_empty():
		_engage("%s was killed" % unit.name)
