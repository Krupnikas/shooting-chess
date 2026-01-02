extends Node

# Enums
enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }
enum GamePhase { REINFORCE, SHOOTING, MOVING, GAME_OVER }

# Constants
const BOARD_SIZE = 8
const SQUARE_SIZE = 160
const BASE_HP = {
	PieceType.PAWN: 1,
	PieceType.KNIGHT: 3,
	PieceType.BISHOP: 3,
	PieceType.ROOK: 4,
	PieceType.QUEEN: 8,
	PieceType.KING: 8
}

# Board colors
const LIGHT_SQUARE = Color(0.93, 0.86, 0.71)  # Cream
const DARK_SQUARE = Color(0.55, 0.37, 0.23)   # Brown
const HIGHLIGHT_COLOR = Color(0.5, 0.8, 0.5, 0.7)  # Green highlight for valid moves
const SELECTED_COLOR = Color(0.8, 0.8, 0.3, 0.7)   # Yellow for selected piece

# Game state
var board: Array = []  # 8x8 array of Piece nodes or null
var current_player: PieceColor = PieceColor.WHITE
var game_phase: GamePhase = GamePhase.REINFORCE
var selected_piece = null
var valid_moves: Array[Vector2i] = []
var winner: PieceColor = PieceColor.WHITE
var is_processing_phase: bool = false

# Signals
signal piece_selected(piece)
signal piece_deselected()
signal piece_moved(piece, from_pos, to_pos)
signal piece_captured(piece)
signal piece_died(piece)
signal turn_changed(player)
signal phase_changed(phase)
signal game_over(winner)
signal reinforce_action(from_piece, to_piece)
signal shoot_action(from_piece, to_piece)
signal phase_animations_complete()

func _ready():
	initialize_board()

func gm_trace(_msg: String):
	pass  # Logging disabled

func initialize_board():
	board.clear()
	for row in range(BOARD_SIZE):
		var board_row = []
		for col in range(BOARD_SIZE):
			board_row.append(null)
		board.append(board_row)

func reset_game():
	current_player = PieceColor.WHITE
	game_phase = GamePhase.REINFORCE
	winner = PieceColor.WHITE
	is_processing_phase = false
	selected_piece = null
	valid_moves.clear()
	initialize_board()

func get_piece_at(pos: Vector2i):
	if is_valid_position(pos):
		return board[pos.y][pos.x]
	return null

func set_piece_at(pos: Vector2i, piece):
	if is_valid_position(pos):
		board[pos.y][pos.x] = piece

func remove_piece_at(pos: Vector2i):
	if is_valid_position(pos):
		board[pos.y][pos.x] = null

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func board_to_screen(board_pos: Vector2i) -> Vector2:
	return Vector2(board_pos.x * SQUARE_SIZE + SQUARE_SIZE / 2,
				   board_pos.y * SQUARE_SIZE + SQUARE_SIZE / 2)

func screen_to_board(screen_pos: Vector2) -> Vector2i:
	return Vector2i(int(screen_pos.x / SQUARE_SIZE), int(screen_pos.y / SQUARE_SIZE))

# ============ PIECE SELECTION & MOVEMENT ============

func select_piece(piece):
	if game_phase != GamePhase.MOVING:
		return

	if selected_piece == piece:
		deselect_piece()
		return

	if piece.color != current_player:
		return

	deselect_piece()
	selected_piece = piece
	valid_moves = get_valid_moves(piece)
	emit_signal("piece_selected", piece)

func deselect_piece():
	selected_piece = null
	valid_moves.clear()
	emit_signal("piece_deselected")

func try_move_to(target_pos: Vector2i) -> bool:
	if game_phase != GamePhase.MOVING:
		return false

	if selected_piece == null:
		return false

	if target_pos in valid_moves:
		execute_move(selected_piece, target_pos)
		return true
	return false

func execute_move(piece, target_pos: Vector2i):
	var from_pos = piece.board_position
	var captured_piece = get_piece_at(target_pos)
	var king_captured = false

	# Handle capture
	if captured_piece != null:
		king_captured = captured_piece.type == PieceType.KING
		emit_signal("piece_captured", captured_piece)
		remove_piece_at(target_pos)
		captured_piece.queue_free()

	# Update board state
	remove_piece_at(from_pos)
	set_piece_at(target_pos, piece)
	piece.board_position = target_pos
	piece.position = board_to_screen(target_pos)

	emit_signal("piece_moved", piece, from_pos, target_pos)
	deselect_piece()

	# Check if king was captured - game over
	if king_captured:
		game_phase = GamePhase.GAME_OVER
		winner = current_player
		emit_signal("game_over", winner)
		return

	advance_phase()  # Move to reinforce phase

# ============ TURN & PHASE MANAGEMENT ============

func start_turn():
	gm_trace("[GM] start_turn called for player: " + str(current_player))
	# Reset HP for all pieces of current player at start of their turn
	reset_player_hp(current_player)

	# Start with reinforce phase
	game_phase = GamePhase.REINFORCE
	gm_trace("[GM] Emitting phase_changed to REINFORCE")
	emit_signal("phase_changed", game_phase)
	gm_trace("[GM] start_turn done")

func reset_player_hp(color: PieceColor):
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece = board[row][col]
			if piece != null and piece.color == color:
				piece.reset_hp()

func process_reinforce_phase() -> Array:
	# Returns array of {from: piece, to: piece} for animations
	# HP is applied when projectile reaches target (in board.gd)
	var actions = []
	var player_pieces = get_pieces_of_color(current_player)

	for piece in player_pieces:
		var targets = get_friendly_targets(piece)
		for target in targets:
			actions.append({"from": piece, "to": target})

	return actions

func process_shooting_phase() -> Array:
	# Returns array of {from: piece, to: piece} for animations
	# HP is applied when projectile reaches target (in board.gd)
	var actions = []
	var player_pieces = get_pieces_of_color(current_player)

	for piece in player_pieces:
		var targets = get_enemy_targets(piece)
		for target in targets:
			actions.append({"from": piece, "to": target})

	return actions

func process_deaths() -> Array:
	# Check all pieces for death, return dead pieces
	var dead_pieces = []

	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece = board[row][col]
			if piece != null and piece.hp <= 0:
				dead_pieces.append(piece)

	return dead_pieces

func kill_piece(piece):
	emit_signal("piece_died", piece)
	remove_piece_at(piece.board_position)
	piece.queue_free()

func check_win_condition() -> bool:
	# Check if enemy king is dead
	var enemy_color = PieceColor.BLACK if current_player == PieceColor.WHITE else PieceColor.WHITE
	var enemy_king_alive = false

	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece = board[row][col]
			if piece != null and piece.type == PieceType.KING and piece.color == enemy_color:
				enemy_king_alive = true
				break

	if not enemy_king_alive:
		game_phase = GamePhase.GAME_OVER
		winner = current_player
		emit_signal("game_over", winner)
		return true

	return false

func advance_phase():
	gm_trace("[GM] advance_phase called, current phase: " + str(game_phase))
	match game_phase:
		GamePhase.REINFORCE:
			# After reinforce, go to shooting
			gm_trace("[GM] REINFORCE -> SHOOTING")
			game_phase = GamePhase.SHOOTING
			emit_signal("phase_changed", game_phase)
		GamePhase.SHOOTING:
			# After shooting, check for deaths and go to move phase
			gm_trace("[GM] SHOOTING -> checking win condition then MOVING")
			if check_win_condition():
				gm_trace("[GM] Win condition met!")
				return
			game_phase = GamePhase.MOVING
			emit_signal("phase_changed", game_phase)
		GamePhase.MOVING:
			# After move, end turn and switch player
			gm_trace("[GM] MOVING -> ending turn")
			end_turn()
	gm_trace("[GM] advance_phase done")

func end_turn():
	gm_trace("[GM] end_turn called")
	# Switch player
	if current_player == PieceColor.WHITE:
		current_player = PieceColor.BLACK
	else:
		current_player = PieceColor.WHITE

	gm_trace("[GM] Switched to player: " + str(current_player))
	emit_signal("turn_changed", current_player)

	# Start new turn with reinforce phase
	gm_trace("[GM] Starting new turn...")
	start_turn()

# ============ TARGET CALCULATION ============

func get_pieces_of_color(color: PieceColor) -> Array:
	var pieces = []
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece = board[row][col]
			if piece != null and piece.color == color:
				pieces.append(piece)
	return pieces

func get_attack_squares(piece) -> Array[Vector2i]:
	# Get all squares this piece can attack (for reinforce/shooting)
	# This is different from valid moves - pawns attack diagonally only
	var squares: Array[Vector2i] = []

	match piece.type:
		PieceType.PAWN:
			squares = get_pawn_attack_squares(piece)
		PieceType.KNIGHT:
			squares = get_knight_attack_squares(piece)
		PieceType.BISHOP:
			squares = get_sliding_attack_squares(piece, [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
		PieceType.ROOK:
			squares = get_sliding_attack_squares(piece, [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)])
		PieceType.QUEEN:
			squares = get_sliding_attack_squares(piece, [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			])
		PieceType.KING:
			squares = get_king_attack_squares(piece)

	return squares

func get_pawn_attack_squares(piece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	var pos = piece.board_position
	var direction = -1 if piece.color == PieceColor.WHITE else 1

	for dx in [-1, 1]:
		var attack_pos = Vector2i(pos.x + dx, pos.y + direction)
		if is_valid_position(attack_pos):
			squares.append(attack_pos)

	return squares

func get_knight_attack_squares(piece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	var pos = piece.board_position
	var offsets = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
	]

	for offset in offsets:
		var target_pos = pos + offset
		if is_valid_position(target_pos):
			squares.append(target_pos)

	return squares

func get_sliding_attack_squares(piece, directions: Array) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	var pos = piece.board_position

	for dir in directions:
		var current = pos + dir
		while is_valid_position(current):
			var target = get_piece_at(current)
			squares.append(current)
			if target != null:
				break  # Can't attack through pieces
			current = current + dir

	return squares

func get_king_attack_squares(piece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	var pos = piece.board_position

	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var target_pos = pos + Vector2i(dx, dy)
			if is_valid_position(target_pos):
				squares.append(target_pos)

	return squares

func get_friendly_targets(piece) -> Array:
	var targets = []
	var attack_squares = get_attack_squares(piece)

	for square in attack_squares:
		var target = get_piece_at(square)
		if target != null and target.color == piece.color and target != piece:
			targets.append(target)

	return targets

func get_enemy_targets(piece) -> Array:
	var targets = []
	var attack_squares = get_attack_squares(piece)

	for square in attack_squares:
		var target = get_piece_at(square)
		if target != null and target.color != piece.color:
			targets.append(target)

	return targets

# ============ MOVEMENT RULES ============

func get_valid_moves(piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []

	match piece.type:
		PieceType.PAWN:
			moves = get_pawn_moves(piece)
		PieceType.KNIGHT:
			moves = get_knight_moves(piece)
		PieceType.BISHOP:
			moves = get_bishop_moves(piece)
		PieceType.ROOK:
			moves = get_rook_moves(piece)
		PieceType.QUEEN:
			moves = get_queen_moves(piece)
		PieceType.KING:
			moves = get_king_moves(piece)

	return moves

func get_pawn_moves(piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos = piece.board_position
	var direction = -1 if piece.color == PieceColor.WHITE else 1
	var start_row = 6 if piece.color == PieceColor.WHITE else 1

	# Forward move
	var forward = Vector2i(pos.x, pos.y + direction)
	if is_valid_position(forward) and get_piece_at(forward) == null:
		moves.append(forward)

		# Double move from starting position
		if pos.y == start_row:
			var double_forward = Vector2i(pos.x, pos.y + direction * 2)
			if get_piece_at(double_forward) == null:
				moves.append(double_forward)

	# Diagonal captures
	for dx in [-1, 1]:
		var capture_pos = Vector2i(pos.x + dx, pos.y + direction)
		if is_valid_position(capture_pos):
			var target = get_piece_at(capture_pos)
			if target != null and target.color != piece.color:
				moves.append(capture_pos)

	return moves

func get_knight_moves(piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos = piece.board_position
	var offsets = [
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
	]

	for offset in offsets:
		var target_pos = pos + offset
		if is_valid_position(target_pos):
			var target = get_piece_at(target_pos)
			if target == null or target.color != piece.color:
				moves.append(target_pos)

	return moves

func get_bishop_moves(piece) -> Array[Vector2i]:
	return get_sliding_moves(piece, [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])

func get_rook_moves(piece) -> Array[Vector2i]:
	return get_sliding_moves(piece, [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)])

func get_queen_moves(piece) -> Array[Vector2i]:
	return get_sliding_moves(piece, [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	])

func get_sliding_moves(piece, directions: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos = piece.board_position

	for dir in directions:
		var current = pos + dir
		while is_valid_position(current):
			var target = get_piece_at(current)
			if target == null:
				moves.append(current)
			elif target.color != piece.color:
				moves.append(current)
				break
			else:
				break
			current = current + dir

	return moves

func get_king_moves(piece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos = piece.board_position

	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var target_pos = pos + Vector2i(dx, dy)
			if is_valid_position(target_pos):
				var target = get_piece_at(target_pos)
				if target == null or target.color != piece.color:
					moves.append(target_pos)

	return moves
