extends Node2D

const PieceScene = preload("res://scenes/piece.tscn")
const ProjectileScene = preload("res://scenes/projectile.tscn")
const ExplosionScene = preload("res://scenes/explosion.tscn")

# ============ FEATURE FLAGS ============
const ENABLE_PROJECTILES = true  # Enable shooting phase
const ENABLE_HIGHLIGHTS = true  # Enable highlights
const ENABLE_TWEENS = true  # Controlled in piece.gd
const ENABLE_HEARTBEAT_LOG = false
const ENABLE_TRACE_LOG = false

@onready var squares_container = $Squares
@onready var highlights_container = $Highlights
@onready var pieces_container = $Pieces
@onready var projectiles_container = $Projectiles

var highlight_squares: Array = []
var active_projectiles: int = 0
var is_processing: bool = false
var is_shutting_down: bool = false

func _ready():
	print("[Board] _ready called, is_online_game=", NetworkManager.is_online_game())
	draw_board()
	setup_pieces()

	# Connect signals
	GameManager.piece_selected.connect(_on_piece_selected)
	GameManager.piece_deselected.connect(_on_piece_deselected)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)
	GameManager.piece_captured.connect(_on_piece_captured)

	# Connect network signals for online play
	NetworkManager.move_received.connect(_on_network_move_received)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)

	# Start the first turn
	await get_tree().create_timer(0.5).timeout
	print("[Board] Starting turn, current_player=", GameManager.current_player)
	GameManager.start_turn()

func _exit_tree():
	is_shutting_down = true
	active_projectiles = 0  # Force-clear to unblock any waits

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

# ============ LOGGING ============

var _log_file: FileAccess = null

func trace(msg: String):
	if ENABLE_TRACE_LOG:
		print("[%.1f] %s" % [Time.get_ticks_msec() / 1000.0, msg])

# ============ STATE MACHINE ============

enum ProcessState { IDLE, SPAWNING, WAITING_PROJECTILES, PROCESSING_DEATHS, DELAY }

var _state: ProcessState = ProcessState.IDLE
var _delay_timer: float = 0.0
var _next_state: ProcessState = ProcessState.IDLE
var _heartbeat_timer: float = 0.0

func _process(delta):
	if not ENABLE_PROJECTILES:
		return  # Skip all processing when projectiles disabled

	# Heartbeat every 2 seconds
	if ENABLE_HEARTBEAT_LOG:
		_heartbeat_timer += delta
		if _heartbeat_timer >= 2.0:
			_heartbeat_timer = 0.0
			print("[HEARTBEAT %.1f] state=%d proj=%d" % [Time.get_ticks_msec() / 1000.0, _state, active_projectiles])

	match _state:
		ProcessState.IDLE:
			pass  # Waiting for phase change
		ProcessState.SPAWNING:
			_do_spawn_projectiles()
		ProcessState.WAITING_PROJECTILES:
			if active_projectiles <= 0:
				_state = ProcessState.PROCESSING_DEATHS
		ProcessState.PROCESSING_DEATHS:
			_do_process_deaths()
			_start_delay(0.3, ProcessState.IDLE)
			call_deferred("_advance_to_next_phase")
		ProcessState.DELAY:
			_delay_timer -= delta
			if _delay_timer <= 0:
				_state = _next_state

func _start_delay(time: float, next: ProcessState):
	_delay_timer = time
	_next_state = next
	_state = ProcessState.DELAY

# ============ PHASE HANDLING ============

func _on_phase_changed(phase):
	match phase:
		GameManager.GamePhase.MOVING:
			is_processing = false
			_state = ProcessState.IDLE
		GameManager.GamePhase.SHOOTING:
			if ENABLE_PROJECTILES:
				is_processing = true
				_state = ProcessState.SPAWNING
			else:
				# Skip shooting phase
				call_deferred("_advance_to_next_phase")

func _do_spawn_projectiles():
	# Spawn projectiles for all current player's pieces
	# Pieces shoot in their attack pattern regardless of whether a target exists
	# - Sliding pieces (bishop, rook, queen): shoot in directions until hitting edge
	# - Targeted pieces (pawn, knight, king): shoot at specific cells
	# Projectile color matches the shooting piece's color
	# Same color hit = +1 HP (heal), different color hit = -1 HP (damage)
	var player_pieces = GameManager.get_pieces_of_color(GameManager.current_player)

	for piece in player_pieces:
		if not is_instance_valid(piece):
			continue

		var is_white_projectile = piece.color == GameManager.PieceColor.WHITE
		var attack_data = get_attack_data(piece)

		if attack_data["mode"] == "directional":
			# Sliding pieces: spawn directional projectiles
			for dir in attack_data["data"]:
				spawn_directional_projectile(piece, dir, is_white_projectile)
		else:
			# Targeted pieces: spawn projectiles to specific cells
			for target_cell in attack_data["data"]:
				spawn_targeted_projectile_to_cell(piece, target_cell, is_white_projectile)

	# Transition to waiting state
	if active_projectiles > 0:
		_state = ProcessState.WAITING_PROJECTILES
	else:
		# No projectiles, advance immediately
		_do_process_deaths()
		call_deferred("_advance_to_next_phase")
		_state = ProcessState.IDLE

func _do_process_deaths():
	var dead_pieces = GameManager.process_deaths()
	for piece in dead_pieces:
		if is_instance_valid(piece):
			# Spawn explosion for every piece death
			# King gets a huge explosion (3x), other pieces get small explosion (0.5x)
			var explosion_scale = 3.0 if piece.type == GameManager.PieceType.KING else 0.5
			spawn_explosion(piece.position, explosion_scale)
			GameManager.kill_piece(piece)

func spawn_explosion(pos: Vector2, scale_multiplier: float = 1.0):
	var explosion = ExplosionScene.instantiate()
	explosion.position = pos
	add_child(explosion)
	explosion.explode(scale_multiplier)

func _advance_to_next_phase():
	GameManager.advance_phase()

func get_attack_data(piece) -> Dictionary:
	# Returns attack data: either directions (for sliding pieces) or target cells (for pawn/knight)
	# Format: { "mode": "directional" or "targeted", "data": [...] }
	var sq = GameManager.SQUARE_SIZE
	var pos = piece.board_position

	match piece.type:
		GameManager.PieceType.PAWN:
			# Pawns attack specific cells diagonally forward
			var forward = -1 if piece.color == GameManager.PieceColor.WHITE else 1
			var targets = []
			for dx in [-1, 1]:
				var target_cell = Vector2i(pos.x + dx, pos.y + forward)
				if GameManager.is_valid_position(target_cell):
					targets.append(target_cell)
			return { "mode": "targeted", "data": targets }

		GameManager.PieceType.KNIGHT:
			# Knights attack specific L-shaped cells
			var offsets = [
				Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
				Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)
			]
			var targets = []
			for offset in offsets:
				var target_cell = pos + offset
				if GameManager.is_valid_position(target_cell):
					targets.append(target_cell)
			return { "mode": "targeted", "data": targets }

		GameManager.PieceType.BISHOP:
			return { "mode": "directional", "data": [
				Vector2(1, 1).normalized(),
				Vector2(1, -1).normalized(),
				Vector2(-1, 1).normalized(),
				Vector2(-1, -1).normalized()
			]}

		GameManager.PieceType.ROOK:
			return { "mode": "directional", "data": [
				Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)
			]}

		GameManager.PieceType.QUEEN:
			return { "mode": "directional", "data": [
				Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
				Vector2(1, 1).normalized(), Vector2(1, -1).normalized(),
				Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()
			]}

		GameManager.PieceType.KING:
			# King attacks adjacent cells (targeted, 1 cell range)
			var targets = []
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var target_cell = pos + Vector2i(dx, dy)
					if GameManager.is_valid_position(target_cell):
						targets.append(target_cell)
			return { "mode": "targeted", "data": targets }

	return { "mode": "directional", "data": [] }

func spawn_directional_projectile(from_piece, direction: Vector2, is_white_projectile: bool):
	if not is_instance_valid(from_piece):
		return

	var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE
	var bounds = Rect2(0, 0, board_size, board_size)

	var projectile = ProjectileScene.instantiate()
	projectile.setup_directional(from_piece.position, direction, is_white_projectile, bounds)
	projectile.set_source(from_piece)
	projectile.finished.connect(_on_projectile_finished)
	projectiles_container.add_child(projectile)
	active_projectiles += 1

func spawn_targeted_projectile_to_cell(from_piece, target_cell: Vector2i, is_white_projectile: bool):
	if not is_instance_valid(from_piece):
		return

	var board_size = GameManager.BOARD_SIZE * GameManager.SQUARE_SIZE
	var bounds = Rect2(0, 0, board_size, board_size)
	var target_pos = GameManager.board_to_screen(target_cell)

	var projectile = ProjectileScene.instantiate()
	projectile.setup_targeted(from_piece.position, target_pos, target_cell, is_white_projectile, bounds)
	projectile.set_source(from_piece)
	projectile.finished.connect(_on_projectile_finished)
	projectiles_container.add_child(projectile)
	active_projectiles += 1

func _on_projectile_finished(hit_piece, is_white_projectile: bool):
	active_projectiles -= 1
	# Apply HP change based on projectile color vs piece color
	# Same color = heal (+1 HP), different color = damage (-1 HP)
	if hit_piece != null and is_instance_valid(hit_piece):
		var piece_is_white = hit_piece.color == GameManager.PieceColor.WHITE
		if is_white_projectile == piece_is_white:
			hit_piece.heal(1)  # Same color = +1 HP
		else:
			hit_piece.take_damage(1)  # Different color = -1 HP

# ============ PIECE SELECTION & HIGHLIGHTING ============

func _on_piece_selected(_piece):
	if not is_inside_tree():
		return
	clear_highlights()
	show_highlights()

func _on_piece_deselected():
	if not is_inside_tree():
		return
	clear_highlights()

func show_highlights():
	if not ENABLE_HIGHLIGHTS:
		return
	if not is_instance_valid(highlights_container):
		return

	# Highlight selected piece
	if GameManager.selected_piece != null and is_instance_valid(GameManager.selected_piece):
		var selected_highlight = create_highlight(
			GameManager.selected_piece.board_position,
			GameManager.SELECTED_COLOR
		)
		if selected_highlight:
			highlight_squares.append(selected_highlight)

	# Highlight valid moves
	for move_pos in GameManager.valid_moves:
		var highlight = create_highlight(move_pos, GameManager.HIGHLIGHT_COLOR)
		if highlight:
			highlight_squares.append(highlight)

func create_highlight(board_pos: Vector2i, color: Color) -> ColorRect:
	if not is_instance_valid(highlights_container):
		return null

	var highlight = ColorRect.new()
	highlight.size = Vector2(GameManager.SQUARE_SIZE, GameManager.SQUARE_SIZE)
	highlight.position = Vector2(board_pos.x * GameManager.SQUARE_SIZE,
								  board_pos.y * GameManager.SQUARE_SIZE)
	highlight.color = color
	highlights_container.add_child(highlight)
	return highlight

func clear_highlights():
	for highlight in highlight_squares:
		if is_instance_valid(highlight):
			highlight.queue_free()
	highlight_squares.clear()

# ============ INPUT HANDLING ============

var cursor_pos: Vector2i = Vector2i(4, 6)  # Start at white's king position
var cursor_highlight: ColorRect = null

func _input(event):
	# Debug keyboard controls (always available)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:  # Restart game (only in offline games)
				if not NetworkManager.is_online_game():
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
				if _try_local_move(board_pos):
					return

			# Allow piece selection during any phase (except GAME_OVER)
			# In online games, only select own pieces
			var piece = GameManager.get_piece_at(board_pos)
			if piece != null:
				if NetworkManager.is_online_game() and piece.color != NetworkManager.get_local_color():
					# Can't select opponent's pieces in online game
					pass
				else:
					GameManager.select_piece(piece)
			else:
				GameManager.deselect_piece()

func handle_cursor_action():
	if _try_local_move(cursor_pos):
		return

	var piece = GameManager.get_piece_at(cursor_pos)
	if piece != null:
		if NetworkManager.is_online_game() and piece.color != NetworkManager.get_local_color():
			# Can't select opponent's pieces in online game
			pass
		else:
			GameManager.select_piece(piece)
	else:
		GameManager.deselect_piece()

func update_cursor():
	if cursor_highlight != null and is_instance_valid(cursor_highlight):
		cursor_highlight.queue_free()
	cursor_highlight = null

	if not is_instance_valid(highlights_container):
		return

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

func _on_piece_captured(piece):
	# Spawn explosion when any piece is captured
	# King gets a huge explosion (3x), other pieces get small explosion (0.5x)
	var explosion_scale = 3.0 if piece.type == GameManager.PieceType.KING else 0.5
	spawn_explosion(piece.position, explosion_scale)

func _on_game_over(winner):
	var winner_name = "White" if winner == GameManager.PieceColor.WHITE else "Black"
	print("Game Over! %s wins!" % winner_name)

func _on_peer_disconnected():
	print("[Board] Opponent disconnected!")
	# End the game - declare the remaining player as winner
	if NetworkManager.is_online_game() or NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		var local_color = NetworkManager.get_local_color()
		GameManager.end_game(local_color, "Opponent disconnected")

# ============ NETWORK PLAY ============

func is_local_turn() -> bool:
	# In offline play, always allow moves
	if not NetworkManager.is_online_game():
		return true
	# In online play, only allow moves when it's the local player's turn
	return GameManager.current_player == NetworkManager.get_local_color()

func _on_network_move_received(from_pos: Vector2i, to_pos: Vector2i):
	# Apply opponent's move
	print("[Network] Received move: ", from_pos, " -> ", to_pos)

	# Ignore moves if game is over
	if GameManager.game_phase == GameManager.GamePhase.GAME_OVER:
		print("[Network] Ignoring move - game is over")
		return

	# Validate the move source
	if not GameManager.is_valid_position(from_pos) or not GameManager.is_valid_position(to_pos):
		print("[Network] ERROR: Invalid position - from: ", from_pos, " to: ", to_pos)
		return

	var piece = GameManager.get_piece_at(from_pos)
	if piece == null:
		print("[Network] ERROR: No piece at ", from_pos)
		return

	if not is_instance_valid(piece):
		print("[Network] ERROR: Piece at ", from_pos, " is invalid")
		return

	GameManager.select_piece(piece)
	GameManager.try_move_to(to_pos)

func _try_local_move(board_pos: Vector2i) -> bool:
	# Check if it's our turn in online games
	if not is_local_turn():
		return false

	if GameManager.selected_piece == null:
		return false

	var from_pos = GameManager.selected_piece.board_position

	if GameManager.try_move_to(board_pos):
		# Send move to opponent in online games
		if NetworkManager.is_online_game():
			NetworkManager.send_move(from_pos, board_pos)
		return true
	return false
