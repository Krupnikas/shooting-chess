extends Control

const PieceScene = preload("res://scenes/piece.tscn")

@onready var timer_label = $TimerLabel
@onready var info_label = $InfoLabel

var frame_count: int = 0
var board_container: Node2D = null

# Board offset to center it (1600 viewport - 1280 board) / 2 = 160
const BOARD_OFFSET = Vector2(160, 160)

# ============ TEST FLAGS - Enable one at a time ============
const TEST_BOARD_SQUARES = true  # Test drawing 64 ColorRects
const TEST_SIMPLE_LABELS = false  # Test simple label nodes
const TEST_REAL_PIECES = true  # Test real piece.tscn scene

func _ready():
	# Create a container for board elements so we can offset them
	board_container = Node2D.new()
	board_container.position = BOARD_OFFSET
	add_child(board_container)

	# Move labels to front
	move_child(timer_label, get_child_count() - 1)
	move_child(info_label, get_child_count() - 1)

	if TEST_BOARD_SQUARES:
		draw_test_board()
	if TEST_SIMPLE_LABELS:
		spawn_test_labels()
	if TEST_REAL_PIECES:
		spawn_real_pieces()

	update_info()

func _process(_delta):
	frame_count += 1
	if frame_count % 60 == 0:  # Update every second
		timer_label.text = "Time: " + str(frame_count / 60) + "s"

func update_info():
	info_label.text = "PNG Piece Test - Checking for freeze"

func draw_test_board():
	for row in range(8):
		for col in range(8):
			var square = ColorRect.new()
			square.size = Vector2(160, 160)
			square.position = Vector2(col * 160, row * 160)
			if (row + col) % 2 == 0:
				square.color = Color(0.93, 0.86, 0.71)  # Light
			else:
				square.color = Color(0.55, 0.37, 0.23)  # Dark
			board_container.add_child(square)

func spawn_test_labels():
	for row in [0, 1, 6, 7]:
		for col in range(8):
			var label = Label.new()
			label.text = "P"
			label.position = Vector2(col * 160 + 80, row * 160 + 80)
			board_container.add_child(label)

func spawn_real_pieces():
	# Create actual piece scenes with variety of types
	var piece_order = [
		GameManager.PieceType.ROOK,
		GameManager.PieceType.KNIGHT,
		GameManager.PieceType.BISHOP,
		GameManager.PieceType.QUEEN,
		GameManager.PieceType.KING,
		GameManager.PieceType.BISHOP,
		GameManager.PieceType.KNIGHT,
		GameManager.PieceType.ROOK
	]

	# Black back row
	for col in range(8):
		var piece = PieceScene.instantiate()
		piece.type = piece_order[col]
		piece.color = GameManager.PieceColor.BLACK
		piece.board_position = Vector2i(col, 0)
		piece.position = Vector2(col * 160 + 80, 0 * 160 + 80)
		board_container.add_child(piece)

	# Black pawns
	for col in range(8):
		var piece = PieceScene.instantiate()
		piece.type = GameManager.PieceType.PAWN
		piece.color = GameManager.PieceColor.BLACK
		piece.board_position = Vector2i(col, 1)
		piece.position = Vector2(col * 160 + 80, 1 * 160 + 80)
		board_container.add_child(piece)

	# White pawns
	for col in range(8):
		var piece = PieceScene.instantiate()
		piece.type = GameManager.PieceType.PAWN
		piece.color = GameManager.PieceColor.WHITE
		piece.board_position = Vector2i(col, 6)
		piece.position = Vector2(col * 160 + 80, 6 * 160 + 80)
		board_container.add_child(piece)

	# White back row
	for col in range(8):
		var piece = PieceScene.instantiate()
		piece.type = piece_order[col]
		piece.color = GameManager.PieceColor.WHITE
		piece.board_position = Vector2i(col, 7)
		piece.position = Vector2(col * 160 + 80, 7 * 160 + 80)
		board_container.add_child(piece)
