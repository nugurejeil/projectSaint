extends Control

@onready var _continue_button: Button = $VBox/ContinueButton


func _ready() -> void:
	_continue_button.visible = GameState.has_save()


func _on_start_pressed() -> void:
	GameState.reset_campaign()
	Scenes.go(get_tree(), Scenes.PREP)


func _on_continue_pressed() -> void:
	if not GameState.load_save():
		print("[Title] continue failed (no save)")
		_continue_button.visible = false
		return
	Scenes.go(get_tree(), Scenes.PREP)


func _on_quit_pressed() -> void:
	print("[Title] quit")
	get_tree().quit()
