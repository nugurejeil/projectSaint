extends Node2D

var target: Unit = null
var damage: float = 20.0
var speed: float = 520.0
var color: Color = Color(1.0, 1.0, 0.3)

const HIT_RADIUS: float = 8.0
const DRAW_RADIUS: float = 5.0


func _ready() -> void:
	z_index = 5
	add_to_group("projectiles")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var step := speed * delta
	if dist <= HIT_RADIUS or dist <= step:
		target.take_damage(damage)
		queue_free()
		return
	global_position += to_target / dist * step


func _draw() -> void:
	draw_circle(Vector2.ZERO, DRAW_RADIUS, color)
