class_name ResultPanel
extends Control
# 전투 결과 오버레이. 무엇을 보여줄지와 버튼을 누른 뒤 어디로 갈지는 호출한 쪽이 정한다.

signal primary_pressed
signal secondary_pressed

@onready var _title: Label = $VBox/ResultTitle
@onready var _stats: Label = $VBox/ResultStats
@onready var _primary_button: Button = $VBox/PrimaryButton
@onready var _secondary_button: Button = $VBox/SecondaryButton


func _ready() -> void:
	visible = false
	_primary_button.pressed.connect(primary_pressed.emit)
	_secondary_button.pressed.connect(secondary_pressed.emit)


# secondary_text가 비어 있으면 두 번째 버튼을 숨긴다.
func show_result(title: String, stats: String, primary_text: String, secondary_text: String = "") -> void:
	_title.text = title
	_stats.text = stats
	_primary_button.text = primary_text
	_secondary_button.text = secondary_text
	_secondary_button.visible = secondary_text != ""
	visible = true
