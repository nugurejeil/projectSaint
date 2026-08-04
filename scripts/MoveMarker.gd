extends Node2D

const RADIUS: float = 18.0
const RING_WIDTH: float = 3.0
const COLOR := Color(1.0, 0.9, 0.3, 1.0)
const LIFETIME: float = 0.4
const EXPAND_TO: float = 1.8

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / LIFETIME
	if t >= 1.0:
		queue_free()
		return
	modulate.a = 1.0 - t
	scale = Vector2.ONE.lerp(Vector2(EXPAND_TO, EXPAND_TO), t)


func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, COLOR, RING_WIDTH)
