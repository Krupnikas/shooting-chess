extends Node2D

@onready var menu_button = $UI/MenuButton

func _ready():
	menu_button.pressed.connect(_on_menu_button_pressed)

func _on_menu_button_pressed():
	# Reset game state before going back to menu
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
