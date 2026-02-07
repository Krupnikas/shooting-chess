extends Node

# Move record structure
class MoveRecord:
	var turn_number: int
	var player: GameManager.PieceColor
	var piece_type: GameManager.PieceType
	var from_pos: Vector2i
	var to_pos: Vector2i
	var captured: bool
	var is_castling_kingside: bool
	var is_castling_queenside: bool

	func _init(turn: int, color: GameManager.PieceColor, type: GameManager.PieceType,
			   from: Vector2i, to: Vector2i, was_capture: bool = false,
			   castling_k: bool = false, castling_q: bool = false):
		turn_number = turn
		player = color
		piece_type = type
		from_pos = from
		to_pos = to
		captured = was_capture
		is_castling_kingside = castling_k
		is_castling_queenside = castling_q

	func to_notation() -> String:
		# Castling notation
		if is_castling_kingside:
			return "O-O"
		if is_castling_queenside:
			return "O-O-O"

		var piece_letter = get_piece_letter(piece_type)
		var from_square = pos_to_square(from_pos)
		var to_square = pos_to_square(to_pos)
		var capture_symbol = "x" if captured else "-"

		return piece_letter + from_square + capture_symbol + to_square

	func get_piece_letter(type: GameManager.PieceType) -> String:
		match type:
			GameManager.PieceType.KING:
				return "K"
			GameManager.PieceType.QUEEN:
				return "Q"
			GameManager.PieceType.ROOK:
				return "R"
			GameManager.PieceType.BISHOP:
				return "B"
			GameManager.PieceType.KNIGHT:
				return "N"
			GameManager.PieceType.PAWN:
				return ""
		return ""

	func pos_to_square(pos: Vector2i) -> String:
		var file = char(ord('a') + pos.x)
		var rank = str(8 - pos.y)
		return file + rank

# Move history
var move_history: Array[MoveRecord] = []
var current_turn: int = 1
var last_captured: bool = false

signal move_logged(record: MoveRecord)
signal history_cleared()

func _ready():
	# Connect to GameManager signals
	GameManager.piece_moved.connect(_on_piece_moved)
	GameManager.piece_captured.connect(_on_piece_captured)
	GameManager.turn_changed.connect(_on_turn_changed)

func clear_history():
	move_history.clear()
	current_turn = 1
	last_captured = false
	emit_signal("history_cleared")

func _on_piece_captured(_piece):
	last_captured = true

func _on_piece_moved(piece, from_pos: Vector2i, to_pos: Vector2i):
	# Detect castling
	var is_castling_k = false
	var is_castling_q = false
	if piece.type == GameManager.PieceType.KING:
		if to_pos.x - from_pos.x == 2:
			is_castling_k = true
		elif from_pos.x - to_pos.x == 2:
			is_castling_q = true

	var record = MoveRecord.new(
		current_turn,
		piece.color,
		piece.type,
		from_pos,
		to_pos,
		last_captured,
		is_castling_k,
		is_castling_q
	)

	move_history.append(record)
	last_captured = false
	emit_signal("move_logged", record)

func _on_turn_changed(player: GameManager.PieceColor):
	# Increment turn number when it's white's turn again
	if player == GameManager.PieceColor.WHITE:
		current_turn += 1

func get_history_text() -> String:
	var text = ""
	var i = 0
	while i < move_history.size():
		var white_move = move_history[i]
		var turn_num = white_move.turn_number
		text += str(turn_num) + ". " + white_move.to_notation()

		# Check if there's a black move
		if i + 1 < move_history.size():
			var black_move = move_history[i + 1]
			if black_move.player == GameManager.PieceColor.BLACK:
				text += "  " + black_move.to_notation()
				i += 1

		text += "\n"
		i += 1

	return text

func get_formatted_moves() -> Array[Dictionary]:
	# Returns array of {turn: int, white: String, black: String}
	var formatted: Array[Dictionary] = []
	var i = 0

	while i < move_history.size():
		var entry = {"turn": 0, "white": "", "black": ""}
		var move = move_history[i]
		entry["turn"] = move.turn_number

		if move.player == GameManager.PieceColor.WHITE:
			entry["white"] = move.to_notation()
			# Check for black's move
			if i + 1 < move_history.size() and move_history[i + 1].player == GameManager.PieceColor.BLACK:
				entry["black"] = move_history[i + 1].to_notation()
				i += 1
		else:
			# Black moved first (shouldn't happen normally)
			entry["black"] = move.to_notation()

		formatted.append(entry)
		i += 1

	return formatted
