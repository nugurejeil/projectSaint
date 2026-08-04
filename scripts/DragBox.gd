extends Node2D

var _visible_box: bool = false
var _rect: Rect2 = Rect2()

const FILL_COLOR := Color(0.4, 0.9, 1.0, 0.20)
const OUTLINE_COLOR := Color(0.4, 0.9, 1.0, 0.90)
const OUTLINE_WIDTH := 2.0


func show_rect(rect: Rect2) -> void:
	_visible_box = true
	_rect = rect
	queue_redraw()


func hide_rect() -> void:
	if not _visible_box:
		return
	_visible_box = false
	queue_redraw()


func _draw() -> void:
	if not _visible_box:
		return
	draw_rect(_rect, FILL_COLOR, true)
	draw_rect(_rect, OUTLINE_COLOR, false, OUTLINE_WIDTH)
