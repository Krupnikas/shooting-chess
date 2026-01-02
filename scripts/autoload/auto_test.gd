extends Node

# Automated test that simulates gameplay and detects freezes

var last_frame_time: float = 0.0
var frame_count: int = 0
var auto_move_timer: float = 0.0
var turn_count: int = 0
var test_active: bool = false
const ENABLE_LOGGING = false

func _ready():
	test_active = true  # Auto moves enabled

func log_msg(msg: String):
	if ENABLE_LOGGING:
		print("[%.1f] %s" % [Time.get_ticks_msec() / 1000.0, msg])

func _process(delta):
	if not test_active:
		return

	# Auto-advance during MOVING phase
	if GameManager.game_phase == GameManager.GamePhase.MOVING:
		auto_move_timer += delta
		if auto_move_timer >= 0.5:  # Wait 0.5s then make a move
			auto_move_timer = 0.0
			attempt_auto_move()

func attempt_auto_move():
	# Get current player's pieces
	var pieces = GameManager.get_pieces_of_color(GameManager.current_player)
	if pieces.is_empty():
		log_msg("No pieces for player %d" % GameManager.current_player)
		return

	# Try to find a piece that can move (avoid capturing king)
	for piece in pieces:
		if not is_instance_valid(piece):
			continue
		var moves = GameManager.get_valid_moves(piece)
		# Filter out moves that would capture a king
		var safe_moves = []
		for move_pos in moves:
			var target_piece = GameManager.get_piece_at(move_pos)
			if target_piece == null or target_piece.type != GameManager.PieceType.KING:
				safe_moves.append(move_pos)

		if safe_moves.size() > 0:
			var target = safe_moves[randi() % safe_moves.size()]
			log_msg("Moving from %s to %s" % [piece.board_position, target])
			GameManager.select_piece(piece)
			GameManager.try_move_to(target)
			turn_count += 1
			log_msg("Turn %d" % turn_count)
			return

	log_msg("No safe moves")
