extends Node

# AI Player using Stockfish for move generation
# Supports both native (desktop) and WASM (web) versions

signal move_ready(from_pos: Vector2i, to_pos: Vector2i)
signal ai_thinking(is_thinking: bool)

var is_enabled: bool = false
var ai_color: GameManager.PieceColor = GameManager.PieceColor.BLACK
var difficulty: int = 5  # 1-10 scale
var think_time_ms: int = 1000  # Time to think in milliseconds

# Difficulty names for display
const DIFFICULTY_NAMES = {
	1: "Beginner",
	2: "Very Easy",
	3: "Easy",
	4: "Easy+",
	5: "Medium",
	6: "Medium+",
	7: "Hard",
	8: "Hard+",
	9: "Expert",
	10: "Master"
}

var _stockfish_process: int = -1
var _stockfish_thread: Thread = null
var _is_thinking: bool = false
var _pending_move: Dictionary = {}

# For web: use JavaScript bridge
var _use_web_stockfish: bool = false

func _ready():
	# Detect if running in web browser
	_use_web_stockfish = OS.has_feature("web")

	# Connect to game signals
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.turn_changed.connect(_on_turn_changed)

func enable_ai(color: GameManager.PieceColor = GameManager.PieceColor.BLACK):
	ai_color = color
	is_enabled = true
	print("[AI] Enabled for color: ", "BLACK" if color == GameManager.PieceColor.BLACK else "WHITE")

func disable_ai():
	is_enabled = false
	print("[AI] Disabled")

func set_difficulty(level: int):
	difficulty = clampi(level, 1, 10)
	print("[AI] Difficulty set to: ", DIFFICULTY_NAMES[difficulty])

func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES.get(difficulty, "Medium")

func set_think_time(ms: int):
	think_time_ms = maxi(100, ms)

func _on_phase_changed(phase: GameManager.GamePhase):
	if not is_enabled:
		return

	# Only act during MOVING phase when it's AI's turn
	if phase == GameManager.GamePhase.MOVING and GameManager.current_player == ai_color:
		# Small delay before AI moves (feels more natural)
		await get_tree().create_timer(0.3).timeout
		_start_thinking()

func _on_turn_changed(_player: GameManager.PieceColor):
	pass  # phase_changed handles this

func _start_thinking():
	if _is_thinking:
		return

	_is_thinking = true
	emit_signal("ai_thinking", true)

	# Generate FEN from current board state
	var fen = _board_to_fen()
	print("[AI] Thinking... FEN: ", fen)

	if _use_web_stockfish:
		_think_web(fen)
	else:
		_think_native(fen)

func _think_native(fen: String):
	# For native builds, use a simple evaluation since bundling Stockfish is complex
	# Fall back to basic AI
	_think_basic()

func _think_web(fen: String):
	# For web builds, we'd use JavaScript interop with stockfish.js
	# For now, fall back to basic AI
	_think_basic()

func _think_basic():
	# Basic AI: evaluate all possible moves and pick the best one
	# This runs in the main thread but is fast enough

	var best_move = _find_best_move()

	if best_move.is_empty():
		print("[AI] No valid moves found!")
		_is_thinking = false
		emit_signal("ai_thinking", false)
		return

	# Small delay to simulate "thinking"
	await get_tree().create_timer(0.2).timeout

	_is_thinking = false
	emit_signal("ai_thinking", false)

	# Execute the move
	_execute_ai_move(best_move.from, best_move.to)

func _find_best_move() -> Dictionary:
	var pieces = GameManager.get_pieces_of_color(ai_color)
	var best_score = -999999
	var best_move = {}

	for piece in pieces:
		var moves = GameManager.get_valid_moves(piece)
		for move in moves:
			var score = _evaluate_move(piece, move)
			if score > best_score:
				best_score = score
				best_move = {"from": piece.board_position, "to": move, "piece": piece}

	return best_move

func _evaluate_move(piece, target_pos: Vector2i) -> float:
	var score: float = 0.0
	var from_pos = piece.board_position

	# Check if this is a capture
	var target_piece = GameManager.get_piece_at(target_pos)
	if target_piece != null:
		# Capturing is good! Value based on piece type
		score += _get_piece_value(target_piece.type) * 10

		# Capturing king is instant win
		if target_piece.type == GameManager.PieceType.KING:
			return 999999

	# Evaluate shooting potential after move
	var shooting_score = _evaluate_shooting_potential(piece, target_pos)
	score += shooting_score

	# Center control bonus (scaled by difficulty)
	var center_dist = abs(target_pos.x - 3.5) + abs(target_pos.y - 3.5)
	var center_weight = 0.3 + (difficulty * 0.07)  # 0.37 at 1, 1.0 at 10
	score += (7 - center_dist) * center_weight

	# Pawn advancement bonus
	if piece.type == GameManager.PieceType.PAWN:
		var advancement = 0
		if ai_color == GameManager.PieceColor.WHITE:
			advancement = from_pos.y - target_pos.y
		else:
			advancement = target_pos.y - from_pos.y
		score += advancement * 2

	# Protect king - penalty for moving king early (stronger at higher difficulty)
	if piece.type == GameManager.PieceType.KING:
		var king_penalty = 3 + (difficulty * 0.5)  # 3.5 to 8
		score -= king_penalty

	# Development bonus (knights and bishops)
	if piece.type in [GameManager.PieceType.KNIGHT, GameManager.PieceType.BISHOP]:
		var start_row = 0 if ai_color == GameManager.PieceColor.BLACK else 7
		if from_pos.y == start_row:
			var dev_bonus = 2 + (difficulty * 0.3)  # 2.3 to 5
			score += dev_bonus

	# Consider opponent's counter-attacks (scales with difficulty)
	var danger_score = _evaluate_danger(piece, target_pos)
	var danger_weight = difficulty * 0.15  # 0.15 at 1, 1.5 at 10
	score -= danger_score * danger_weight

	# Look ahead one move (scales with difficulty)
	var lookahead_bonus = _evaluate_lookahead(piece, target_pos)
	var lookahead_weight = difficulty * 0.1  # 0.1 at 1, 1.0 at 10
	score += lookahead_bonus * lookahead_weight

	# Add randomness based on difficulty (lower difficulty = more random)
	# Scale: difficulty 1 = lots of noise, difficulty 10 = almost none
	var randomness_factor = (11 - difficulty) * 1.5  # 15 at 1, 1.5 at 10
	score += randf() * randomness_factor

	# At lower difficulties, occasionally "miss" good opportunities
	var miss_chance = maxf(0, (5 - difficulty) * 0.1)  # 40% at 1, 0% at 5+
	if randf() < miss_chance:
		score *= 0.4  # Sometimes undervalue good moves

	return score

func _evaluate_danger(piece, target_pos: Vector2i) -> float:
	# Evaluate how exposed this piece would be after the move
	# Must simulate the move first to get accurate danger assessment
	var original_pos = piece.board_position
	var captured_piece = GameManager.get_piece_at(target_pos)

	# Simulate the move
	GameManager.remove_piece_at(original_pos)
	if captured_piece != null:
		GameManager.remove_piece_at(target_pos)
	GameManager.set_piece_at(target_pos, piece)
	piece.board_position = target_pos

	var danger: float = 0.0
	var enemy_color = GameManager.PieceColor.WHITE if ai_color == GameManager.PieceColor.BLACK else GameManager.PieceColor.BLACK
	var enemy_pieces = GameManager.get_pieces_of_color(enemy_color)

	for enemy in enemy_pieces:
		# Check if enemy can capture our piece at its new position
		var enemy_moves = GameManager.get_valid_moves(enemy)
		if target_pos in enemy_moves:
			danger += _get_piece_value(piece.type) * 2

		# Check if enemy can shoot our piece at its new position
		var enemy_targets = GameManager.get_enemy_targets(enemy)
		for target in enemy_targets:
			if target == piece:
				danger += 1.0

	# Restore original board state
	GameManager.remove_piece_at(target_pos)
	GameManager.set_piece_at(original_pos, piece)
	piece.board_position = original_pos
	if captured_piece != null:
		GameManager.set_piece_at(target_pos, captured_piece)

	return danger

func _evaluate_lookahead(piece, target_pos: Vector2i) -> float:
	# Simple one-move lookahead: what's the best move we'd have after this?
	var original_pos = piece.board_position
	var captured_piece = GameManager.get_piece_at(target_pos)

	# Simulate the move
	GameManager.remove_piece_at(original_pos)
	if captured_piece != null:
		GameManager.remove_piece_at(target_pos)
	GameManager.set_piece_at(target_pos, piece)
	piece.board_position = target_pos

	# Find best response move value
	var best_future_score: float = 0.0
	var our_pieces = GameManager.get_pieces_of_color(ai_color)
	for p in our_pieces:
		var moves = GameManager.get_valid_moves(p)
		for move in moves:
			var future_target = GameManager.get_piece_at(move)
			if future_target != null and future_target.color != ai_color:
				best_future_score = maxf(best_future_score, _get_piece_value(future_target.type) * 3)
			# Check shooting potential
			var shoot_score = _evaluate_shooting_potential(p, move) * 0.5
			best_future_score = maxf(best_future_score, shoot_score)

	# Restore original position
	GameManager.remove_piece_at(target_pos)
	GameManager.set_piece_at(original_pos, piece)
	piece.board_position = original_pos
	if captured_piece != null:
		GameManager.set_piece_at(target_pos, captured_piece)

	return best_future_score

func _evaluate_shooting_potential(piece, target_pos: Vector2i) -> float:
	# Temporarily move piece to evaluate shooting
	var original_pos = piece.board_position
	var original_board_piece = GameManager.get_piece_at(target_pos)

	# Simulate the move
	GameManager.remove_piece_at(original_pos)
	GameManager.set_piece_at(target_pos, piece)
	piece.board_position = target_pos

	var score: float = 0.0

	# Count enemy targets we can shoot
	var enemy_targets = GameManager.get_enemy_targets(piece)
	for target in enemy_targets:
		score += _get_piece_value(target.type) * 2
		if target.type == GameManager.PieceType.KING:
			score += 50  # Big bonus for threatening king

	# Count friendly targets we can heal (less valuable but still good)
	var friendly_targets = GameManager.get_friendly_targets(piece)
	score += friendly_targets.size() * 0.5

	# Restore original position
	GameManager.remove_piece_at(target_pos)
	GameManager.set_piece_at(original_pos, piece)
	piece.board_position = original_pos
	if original_board_piece != null:
		GameManager.set_piece_at(target_pos, original_board_piece)

	return score

func _get_piece_value(type: GameManager.PieceType) -> float:
	match type:
		GameManager.PieceType.PAWN:
			return 1.0
		GameManager.PieceType.KNIGHT:
			return 3.0
		GameManager.PieceType.BISHOP:
			return 3.2
		GameManager.PieceType.ROOK:
			return 5.0
		GameManager.PieceType.QUEEN:
			return 9.0
		GameManager.PieceType.KING:
			return 100.0
	return 0.0

func _execute_ai_move(from_pos: Vector2i, to_pos: Vector2i):
	print("[AI] Moving from ", from_pos, " to ", to_pos)

	var piece = GameManager.get_piece_at(from_pos)
	if piece == null:
		print("[AI] ERROR: No piece at from position!")
		return

	# Select and move
	GameManager.select_piece(piece)

	# Small delay so player can see what's happening
	await get_tree().create_timer(0.1).timeout

	var success = GameManager.try_move_to(to_pos)
	if not success:
		print("[AI] ERROR: Move failed!")

	emit_signal("move_ready", from_pos, to_pos)

# ============ FEN CONVERSION ============

func _board_to_fen() -> String:
	var fen = ""

	# Board position
	for row in range(GameManager.BOARD_SIZE):
		var empty_count = 0
		for col in range(GameManager.BOARD_SIZE):
			var piece = GameManager.get_piece_at(Vector2i(col, row))
			if piece == null:
				empty_count += 1
			else:
				if empty_count > 0:
					fen += str(empty_count)
					empty_count = 0
				fen += _piece_to_fen_char(piece)

		if empty_count > 0:
			fen += str(empty_count)

		if row < 7:
			fen += "/"

	# Active color
	fen += " "
	fen += "w" if GameManager.current_player == GameManager.PieceColor.WHITE else "b"

	# Castling (simplified - no castling in this game variant)
	fen += " -"

	# En passant (simplified - not tracking)
	fen += " -"

	# Halfmove clock and fullmove number (simplified)
	fen += " 0 1"

	return fen

func _piece_to_fen_char(piece) -> String:
	var char = ""
	match piece.type:
		GameManager.PieceType.PAWN:
			char = "p"
		GameManager.PieceType.KNIGHT:
			char = "n"
		GameManager.PieceType.BISHOP:
			char = "b"
		GameManager.PieceType.ROOK:
			char = "r"
		GameManager.PieceType.QUEEN:
			char = "q"
		GameManager.PieceType.KING:
			char = "k"

	if piece.color == GameManager.PieceColor.WHITE:
		char = char.to_upper()

	return char

func _fen_to_move(fen_move: String) -> Dictionary:
	# Convert UCI move like "e2e4" to board positions
	if fen_move.length() < 4:
		return {}

	var from_col = fen_move[0].unicode_at(0) - "a".unicode_at(0)
	var from_row = 8 - int(fen_move[1])
	var to_col = fen_move[2].unicode_at(0) - "a".unicode_at(0)
	var to_row = 8 - int(fen_move[3])

	return {
		"from": Vector2i(from_col, from_row),
		"to": Vector2i(to_col, to_row)
	}
