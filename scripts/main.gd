extends Node2D

@onready var menu_button = $UI/MenuButton
@onready var board_container = $BoardContainer
@onready var board = $BoardContainer/Board

# Board coordinate labels
var file_labels: Array = []  # a-h (columns)
var rank_labels: Array = []  # 1-8 (rows)
var is_flipped: bool = false

func _ready():
	menu_button.pressed.connect(_on_menu_button_pressed)
	get_tree().root.size_changed.connect(_on_viewport_size_changed)

	# Check if board should be flipped for black player
	_setup_board_orientation()

	# Create coordinate labels
	_create_coordinate_labels()

	# Defer centering to ensure viewport is fully initialized (important for web)
	call_deferred("_center_board")
	# Also center after a short delay for web export
	get_tree().create_timer(0.1).timeout.connect(_center_board)

func _setup_board_orientation():
	# Board flip is set before scene load (in menu.gd or online_lobby.gd)
	# Just sync the local is_flipped flag for coordinate labels
	is_flipped = GameManager.is_board_flipped

func _create_coordinate_labels():
	var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE
	var square_size = GameManager.SQUARE_SIZE
	var label_offset = square_size * 0.15  # Distance from board edge (proportional)
	var font_size = int(square_size * 0.125)  # Font size proportional to square size
	var half_char_width = font_size * 0.4  # Approximate half character width
	var half_char_height = font_size * 0.6  # Approximate half character height

	# File labels (a-h) - bottom of board
	var files = ["a", "b", "c", "d", "e", "f", "g", "h"]
	if is_flipped:
		files.reverse()

	for i in range(8):
		var label = Label.new()
		label.text = files[i]
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(
			i * square_size + square_size / 2 - half_char_width,
			board_size + label_offset - half_char_height
		)
		board_container.add_child(label)
		file_labels.append(label)

	# Rank labels (1-8) - left of board
	var ranks = ["8", "7", "6", "5", "4", "3", "2", "1"]
	if is_flipped:
		ranks.reverse()

	for i in range(8):
		var label = Label.new()
		label.text = ranks[i]
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(
			-label_offset - half_char_width,
			i * square_size + square_size / 2 - half_char_height
		)
		board_container.add_child(label)
		rank_labels.append(label)

func _on_viewport_size_changed():
	_center_board()

func _center_board():
	var viewport_size = get_viewport().get_visible_rect().size
	var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE  # 1280

	# Calculate scale to fit board within viewport (with padding for labels and UI)
	var padding = 100  # Space for coordinate labels and menu button
	var available_width = viewport_size.x - padding
	var available_height = viewport_size.y - padding - 150  # Extra space for bottom UI

	var scale_x = available_width / board_size
	var scale_y = available_height / board_size
	var board_scale = min(scale_x, scale_y, 1.0)  # Don't scale up, only down

	board_container.scale = Vector2(board_scale, board_scale)

	var scaled_board_size = board_size * board_scale
	var x_offset = (viewport_size.x - scaled_board_size) / 2
	var y_offset = (viewport_size.y - scaled_board_size - 100) / 2 + 80  # Offset for menu button

	board_container.position.x = x_offset
	board_container.position.y = y_offset

func _on_menu_button_pressed():
	# Reset game state before going back to menu
	GameManager.reset_game()
	# Disconnect from online game if connected
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
