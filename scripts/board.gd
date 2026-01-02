extends Node2D

const PieceScene = preload("res://scenes/piece.tscn")
const ProjectileScene = preload("res://scenes/projectile.tscn")

@onready var squares_container = $Squares
@onready var highlights_container = $Highlights
@onready var pieces_container = $Pieces
@onready var projectiles_container = $Projectiles

var highlight_squares: Array = []
var active_projectiles: int = 0
var is_processing: bool = false

func _ready():
	draw_board()
	setup_pieces()

	# Connect signals
	GameManager.piece_selected.connect(_on_piece_selected)
	GameManager.piece_deselected.connect(_on_piece_deselected)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)

	# Start the first turn
	await get_tree().create_timer(0.5).timeout
	GameManager.start_turn()

func draw_board():
	for row in range(GameManager.BOARD_SIZE):
		for col in range(GameManager.BOARD_SIZE):
			var square = ColorRect.new()
			square.size = Vector2(GameManager.SQUARE_SIZE, GameManager.SQUARE_SIZE)
			square.position = Vector2(col * GameManager.SQUARE_SIZE, row * GameManager.SQUARE_SIZE)

			if (row + col) % 2 == 0:
				square.color = GameManager.LIGHT_SQUARE
			else:
				square.color = GameManager.DARK_SQUARE

			squares_container.add_child(square)

func setup_pieces():
	# Black pieces (top, rows 0-1)
	setup_back_row(0, GameManager.PieceColor.BLACK)
	setup_pawn_row(1, GameManager.PieceColor.BLACK)

	# White pieces (bottom, rows 6-7)
	setup_pawn_row(6, GameManager.PieceColor.WHITE)
	setup_back_row(7, GameManager.PieceColor.WHITE)

func setup_back_row(row: int, color: GameManager.PieceColor):
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

	for col in range(8):
		spawn_piece(piece_order[col], color, Vector2i(col, row))

func setup_pawn_row(row: int, color: GameManager.PieceColor):
	for col in range(8):
		spawn_piece(GameManager.PieceType.PAWN, color, Vector2i(col, row))

func spawn_piece(type: GameManager.PieceType, color: GameManager.PieceColor, board_pos: Vector2i):
	var piece = PieceScene.instantiate()
	piece.type = type
	piece.color = color
	piece.board_position = board_pos
	piece.position = GameManager.board_to_screen(board_pos)

	pieces_container.add_child(piece)
	GameManager.set_piece_at(board_pos, piece)

# ============ PHASE HANDLING ============

func _on_phase_changed(phase):
	match phase:
		GameManager.GamePhase.MOVING:
			is_processing = false
		GameManager.GamePhase.REINFORCE:
			is_processing = true
			process_reinforce_phase()
		GameManager.GamePhase.SHOOTING:
			is_processing = true
			process_shooting_phase()

func process_reinforce_phase():
	var actions = GameManager.process_reinforce_phase()

	if actions.size() == 0:
		# No reinforcements, advance immediately
		await get_tree().create_timer(0.3).timeout
		call_deferred("_advance_to_next_phase")
		return

	# Spawn projectiles for all reinforce actions
	for action in actions:
		spawn_projectile(action.from, action.to, true)

	# Wait for all projectiles to finish
	await wait_for_projectiles()

	await get_tree().create_timer(0.2).timeout
	call_deferred("_advance_to_next_phase")

func process_shooting_phase():
	var actions = GameManager.process_shooting_phase()

	if actions.size() == 0:
		# No shooting, advance immediately (ends turn)
		await get_tree().create_timer(0.3).timeout
		await process_deaths()
		call_deferred("_advance_to_next_phase")
		return

	# Spawn projectiles for all shoot actions
	for action in actions:
		spawn_projectile(action.from, action.to, false)

	# Wait for all projectiles to finish
	await wait_for_projectiles()

	# Process deaths after shooting
	await get_tree().create_timer(0.2).timeout
	await process_deaths()

	await get_tree().create_timer(0.3).timeout
	call_deferred("_advance_to_next_phase")

func _advance_to_next_phase():
	GameManager.advance_phase()

func process_deaths():
	var dead_pieces = GameManager.process_deaths()

	if dead_pieces.size() == 0:
		return

	# Start all death animations in parallel
	var tweens = []
	for piece in dead_pieces:
		if not is_instance_valid(piece):
			continue
		var tween = create_tween()
		tween.tween_property(piece, "modulate:a", 0.0, 0.3)
		tweens.append({"tween": tween, "piece": piece})

	# Wait for animations (with timeout)
	await get_tree().create_timer(0.35).timeout

	# Kill all dead pieces
	for data in tweens:
		if is_instance_valid(data.piece):
			GameManager.kill_piece(data.piece)

func spawn_projectile(from_piece, to_piece, is_reinforce: bool):
	# Safety check - don't spawn if pieces are invalid
	if not is_instance_valid(from_piece) or not is_instance_valid(to_piece):
		return

	var projectile = ProjectileScene.instantiate()
	projectile.setup(from_piece.position, to_piece.position, is_reinforce)
	projectile.finished.connect(_on_projectile_finished.bind(to_piece, is_reinforce))
	projectiles_container.add_child(projectile)
	active_projectiles += 1

func _on_projectile_finished(target_piece, is_reinforce: bool):
	active_projectiles -= 1
	# Apply HP change when projectile reaches target
	if is_instance_valid(target_piece):
		if is_reinforce:
			target_piece.heal(1)
		else:
			target_piece.take_damage(1)

func wait_for_projectiles():
	var timeout = 0
	while active_projectiles > 0 and timeout < 100:  # Max 5 second timeout
		await get_tree().create_timer(0.05).timeout
		timeout += 1
	# Reset counter if timed out (safety)
	active_projectiles = 0

# ============ PIECE SELECTION & HIGHLIGHTING ============

func _on_piece_selected(_piece):
	clear_highlights()
	show_highlights()

func _on_piece_deselected():
	clear_highlights()

func show_highlights():
	# Highlight selected piece
	if GameManager.selected_piece != null:
		var selected_highlight = create_highlight(
			GameManager.selected_piece.board_position,
			GameManager.SELECTED_COLOR
		)
		highlight_squares.append(selected_highlight)

	# Highlight valid moves
	for move_pos in GameManager.valid_moves:
		var highlight = create_highlight(move_pos, GameManager.HIGHLIGHT_COLOR)
		highlight_squares.append(highlight)

func create_highlight(board_pos: Vector2i, color: Color) -> ColorRect:
	var highlight = ColorRect.new()
	highlight.size = Vector2(GameManager.SQUARE_SIZE, GameManager.SQUARE_SIZE)
	highlight.position = Vector2(board_pos.x * GameManager.SQUARE_SIZE,
								  board_pos.y * GameManager.SQUARE_SIZE)
	highlight.color = color
	highlights_container.add_child(highlight)
	return highlight

func clear_highlights():
	for highlight in highlight_squares:
		highlight.queue_free()
	highlight_squares.clear()

# ============ INPUT HANDLING ============

var cursor_pos: Vector2i = Vector2i(4, 6)  # Start at white's king position
var cursor_highlight: ColorRect = null

func _input(event):
	# Debug keyboard controls (always available)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:  # Restart game
				restart_game()
				return
			KEY_P:  # Print game state
				print_game_state()
				return
			KEY_ESCAPE:
				GameManager.deselect_piece()
				return

	# Keyboard controls for moving cursor
	if event is InputEventKey and event.pressed and GameManager.game_phase == GameManager.GamePhase.MOVING:
		var moved = false
		match event.keycode:
			KEY_UP, KEY_W:
				cursor_pos.y = max(0, cursor_pos.y - 1)
				moved = true
			KEY_DOWN, KEY_S:
				cursor_pos.y = min(7, cursor_pos.y + 1)
				moved = true
			KEY_LEFT, KEY_A:
				cursor_pos.x = max(0, cursor_pos.x - 1)
				moved = true
			KEY_RIGHT, KEY_D:
				cursor_pos.x = min(7, cursor_pos.x + 1)
				moved = true
			KEY_SPACE, KEY_ENTER:
				handle_cursor_action()
				return

		if moved:
			update_cursor()
			return

	if GameManager.game_phase == GameManager.GamePhase.GAME_OVER:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Convert global mouse position to local board position
		var local_pos = get_global_transform().affine_inverse() * event.position
		var board_pos = GameManager.screen_to_board(local_pos)

		if GameManager.is_valid_position(board_pos):
			cursor_pos = board_pos
			update_cursor()

			# Try to move if we have a piece selected (only during MOVING phase)
			if GameManager.game_phase == GameManager.GamePhase.MOVING:
				if GameManager.selected_piece != null:
					if GameManager.try_move_to(board_pos):
						return

			# Allow piece selection during any phase (except GAME_OVER)
			var piece = GameManager.get_piece_at(board_pos)
			if piece != null:
				GameManager.select_piece(piece)
			else:
				GameManager.deselect_piece()

func handle_cursor_action():
	if GameManager.selected_piece != null:
		if GameManager.try_move_to(cursor_pos):
			return

	var piece = GameManager.get_piece_at(cursor_pos)
	if piece != null:
		GameManager.select_piece(piece)
	else:
		GameManager.deselect_piece()

func update_cursor():
	if cursor_highlight != null:
		cursor_highlight.queue_free()

	cursor_highlight = ColorRect.new()
	cursor_highlight.size = Vector2(GameManager.SQUARE_SIZE, GameManager.SQUARE_SIZE)
	cursor_highlight.position = Vector2(cursor_pos.x * GameManager.SQUARE_SIZE,
										cursor_pos.y * GameManager.SQUARE_SIZE)
	cursor_highlight.color = Color(1.0, 1.0, 1.0, 0.3)  # White semi-transparent
	highlights_container.add_child(cursor_highlight)

func restart_game():
	# Clear all pieces
	for child in pieces_container.get_children():
		child.queue_free()

	# Clear projectiles
	for child in projectiles_container.get_children():
		child.queue_free()

	# Reset game state
	GameManager.reset_game()
	is_processing = false
	active_projectiles = 0

	# Setup pieces again
	await get_tree().create_timer(0.1).timeout
	setup_pieces()
	await get_tree().create_timer(0.3).timeout
	GameManager.start_turn()
	print("Game restarted!")

func print_game_state():
	print("=== Game State ===")
	print("Current player: ", "WHITE" if GameManager.current_player == GameManager.PieceColor.WHITE else "BLACK")
	print("Phase: ", GameManager.game_phase)
	print("Board:")
	for row in range(8):
		var row_str = ""
		for col in range(8):
			var piece = GameManager.get_piece_at(Vector2i(col, row))
			if piece == null:
				row_str += ". "
			else:
				var symbol = "P" if piece.type == GameManager.PieceType.PAWN else \
							 "N" if piece.type == GameManager.PieceType.KNIGHT else \
							 "B" if piece.type == GameManager.PieceType.BISHOP else \
							 "R" if piece.type == GameManager.PieceType.ROOK else \
							 "Q" if piece.type == GameManager.PieceType.QUEEN else "K"
				if piece.color == GameManager.PieceColor.BLACK:
					symbol = symbol.to_lower()
				row_str += symbol + " "
		print(row_str)
	print("==================")

# ============ GAME OVER ============

func _on_game_over(winner):
	var winner_name = "White" if winner == GameManager.PieceColor.WHITE else "Black"
	print("Game Over! %s wins!" % winner_name)
