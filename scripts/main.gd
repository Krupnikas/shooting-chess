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
	# Flip board for black player in online games or AI games
	var should_flip = false
	if NetworkManager.is_online_game():
		should_flip = NetworkManager.get_local_color() == GameManager.PieceColor.BLACK
	else:
		should_flip = GameManager.player_color == GameManager.PieceColor.BLACK

	if should_flip:
		is_flipped = true
		# Rotate the entire board container (includes board, pieces, health bars)
		var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE
		board_container.rotation = PI  # 180 degrees
		board_container.pivot_offset = Vector2(board_size / 2, board_size / 2)

func _create_coordinate_labels():
	var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE
	var label_offset = 24  # Distance from board edge
	var font_size = 20

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
			i * GameManager.SQUARE_SIZE + GameManager.SQUARE_SIZE / 2 - 8,
			board_size + label_offset - 16
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
			-label_offset - 4,
			i * GameManager.SQUARE_SIZE + GameManager.SQUARE_SIZE / 2 - 12
		)
		board_container.add_child(label)
		rank_labels.append(label)

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
