extends Node2D

@onready var menu_button = $UI/MenuButton
@onready var board_container = $BoardContainer

func _ready():
	menu_button.pressed.connect(_on_menu_button_pressed)
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	# Defer centering to ensure viewport is fully initialized (important for web)
	call_deferred("_center_board")
	# Also center after a short delay for web export
	get_tree().create_timer(0.1).timeout.connect(_center_board)

func _on_viewport_size_changed():
	_center_board()

func _center_board():
	var viewport_size = get_viewport().get_visible_rect().size
	var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE  # 1280
	var x_offset = (viewport_size.x - board_size) / 2
	var y_offset = (viewport_size.y - board_size) / 2
	board_container.position.x = x_offset
	board_container.position.y = y_offset

func _on_menu_button_pressed():
	# Reset game state before going back to menu
	GameManager.reset_game()
	# Disconnect from online game if connected
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
