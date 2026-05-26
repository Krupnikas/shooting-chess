extends Node2D

const PieceScene = preload("res://scenes/piece.tscn")
const ProjectileScene = preload("res://scenes/projectile.tscn")
const ExplosionScene = preload("res://scenes/explosion.tscn")

const SQUARE_SIZE = 96
const BOARD_COLS = 4
const BOARD_ROWS = 5

const LIGHT_SQUARE = Color(0.93, 0.86, 0.71)
const DARK_SQUARE = Color(0.55, 0.37, 0.23)
const HIGHLIGHT_COLOR = Color(0.5, 0.8, 0.5, 0.7)
const SELECTED_COLOR = Color(0.8, 0.8, 0.3, 0.7)

@onready var squares_container = $Squares
@onready var highlights_container = $Highlights
@onready var pieces_container = $Pieces
@onready var projectiles_container = $Projectiles

var is_animating: bool = false
var current_step: int = 0
var pieces: Dictionary = {}
var active_projectiles: int = 0
var animation_id: int = 0  # Unique ID to track animation cycles

signal step_animation_complete

func _ready():
	draw_board()

func draw_board():
	for child in squares_container.get_children():
		child.queue_free()

	for row in range(BOARD_ROWS):
		for col in range(BOARD_COLS):
			var square = ColorRect.new()
			square.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
			square.position = Vector2(col * SQUARE_SIZE, row * SQUARE_SIZE)
			square.color = LIGHT_SQUARE if (row + col) % 2 == 0 else DARK_SQUARE
			squares_container.add_child(square)

func play_step(step: int):
	current_step = step
	is_animating = true
	animation_id += 1  # Increment to invalidate any running loops
	var my_animation_id = animation_id
	_clear_board()
	_setup_step(step)
	_run_animation_loop(my_animation_id)

func stop_animation():
	is_animating = false
	animation_id += 1  # Also increment to stop any running loops immediately

func _should_continue(my_animation_id: int) -> bool:
	return is_animating and animation_id == my_animation_id

func _clear_board():
	for piece in pieces_container.get_children():
		piece.queue_free()
	for proj in projectiles_container.get_children():
		proj.queue_free()
	for highlight in highlights_container.get_children():
		highlight.queue_free()
	pieces.clear()
	active_projectiles = 0

func _setup_step(step: int):
	match step:
		1: _setup_step_1()
		2: _setup_step_2()
		3: _setup_step_3()
		4: _setup_step_4()
		5: _setup_step_5()
		6: _setup_step_6()
		7: _setup_step_7()
		8: _setup_step_8()
		9: _setup_step_9()

func _spawn_piece(type: int, color: int, pos: Vector2i) -> Node2D:
	var piece = PieceScene.instantiate()
	piece.type = type
	piece.color = color
	piece.board_position = pos
	piece.position = _board_to_screen(pos)
	piece.scale = Vector2(0.6, 0.6)
	pieces_container.add_child(piece)
	pieces[pos] = piece
	return piece

func _board_to_screen(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * SQUARE_SIZE + SQUARE_SIZE / 2,
				   pos.y * SQUARE_SIZE + SQUARE_SIZE / 2)

func _run_animation_loop(my_animation_id: int):
	while is_animating and animation_id == my_animation_id:
		await _play_step_animation(current_step, my_animation_id)
		if is_animating and animation_id == my_animation_id:
			await get_tree().create_timer(1.5).timeout

func _play_step_animation(step: int, my_animation_id: int):
	match step:
		1: await _animate_step_1(my_animation_id)
		2: await _animate_step_2(my_animation_id)
		3: await _animate_step_3(my_animation_id)
		4: await _animate_step_4(my_animation_id)
		5: await _animate_step_5(my_animation_id)
		6: await _animate_step_6(my_animation_id)
		7: await _animate_step_7(my_animation_id)
		8: await _animate_step_8(my_animation_id)
		9: await _animate_step_9(my_animation_id)

# Step 1: Pieces shoot in attack directions after a move
func _setup_step_1():
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 3))

func _animate_step_1(my_id: int):
	if not _should_continue(my_id):
		return

	var pawn = pieces.get(Vector2i(1, 3))
	if not is_instance_valid(pawn):
		return

	_show_selected(Vector2i(1, 3))
	_show_highlights([Vector2i(1, 2)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Move pawn forward
	_clear_highlights()
	pawn.move_to(_board_to_screen(Vector2i(1, 2)))
	pieces.erase(Vector2i(1, 3))
	pieces[Vector2i(1, 2)] = pawn
	pawn.board_position = Vector2i(1, 2)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn shoots diagonally (attack directions)
	_spawn_projectile(pawn.position, Vector2i(0, 1), true)
	_spawn_projectile(pawn.position, Vector2i(2, 1), true)

	await get_tree().create_timer(1.2).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Reset
	pawn.move_to(_board_to_screen(Vector2i(1, 3)))
	pieces.erase(Vector2i(1, 2))
	pieces[Vector2i(1, 3)] = pawn
	pawn.board_position = Vector2i(1, 3)

	await get_tree().create_timer(0.3).timeout

# Step 2: ALL your pieces shoot after a move
func _setup_step_2():
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 3))
	_spawn_piece(GameManager.PieceType.BISHOP, GameManager.PieceColor.WHITE, Vector2i(3, 3))

func _animate_step_2(my_id: int):
	if not _should_continue(my_id):
		return

	var pawn = pieces.get(Vector2i(1, 3))
	var bishop = pieces.get(Vector2i(3, 3))
	if not is_instance_valid(pawn) or not is_instance_valid(bishop):
		return

	_show_selected(Vector2i(1, 3))
	_show_highlights([Vector2i(1, 2)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Move pawn forward
	_clear_highlights()
	pawn.move_to(_board_to_screen(Vector2i(1, 2)))
	pieces.erase(Vector2i(1, 3))
	pieces[Vector2i(1, 2)] = pawn
	pawn.board_position = Vector2i(1, 2)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn) or not is_instance_valid(bishop):
		return

	# BOTH pieces shoot — bishop projectiles reach borders
	_spawn_projectile(pawn.position, Vector2i(0, 1), true)
	_spawn_projectile(pawn.position, Vector2i(2, 1), true)
	_spawn_projectile(bishop.position, Vector2i(0, 0), true)
	_spawn_projectile(bishop.position, Vector2i(2, 4), true)

	await get_tree().create_timer(1.2).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Reset
	pawn.move_to(_board_to_screen(Vector2i(1, 3)))
	pieces.erase(Vector2i(1, 2))
	pieces[Vector2i(1, 3)] = pawn
	pawn.board_position = Vector2i(1, 3)

	await get_tree().create_timer(0.3).timeout

# Step 3: Heal allies, damage enemies
func _setup_step_3():
	_spawn_piece(GameManager.PieceType.BISHOP, GameManager.PieceColor.WHITE, Vector2i(0, 4))
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(0, 2))
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.BLACK, Vector2i(3, 1))

func _animate_step_3(my_id: int):
	if not _should_continue(my_id):
		return

	var bishop = pieces.get(Vector2i(0, 4))
	var white_knight = pieces.get(Vector2i(0, 2))
	var black_knight = pieces.get(Vector2i(3, 1))

	if not is_instance_valid(bishop) or not is_instance_valid(white_knight) or not is_instance_valid(black_knight):
		return

	_show_selected(Vector2i(0, 4))
	_show_highlights([Vector2i(1, 3)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(bishop):
		return

	# Bishop moves to (1,3)
	_clear_highlights()
	bishop.move_to(_board_to_screen(Vector2i(1, 3)))
	pieces.erase(Vector2i(0, 4))
	pieces[Vector2i(1, 3)] = bishop
	bishop.board_position = Vector2i(1, 3)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(bishop):
		return

	# Bishop at (1,3) shoots all 4 diagonals
	_spawn_projectile(bishop.position, Vector2i(0, 2), true)   # up-left → white knight HEAL
	_spawn_projectile(bishop.position, Vector2i(3, 1), true)   # up-right → black knight DMG
	_spawn_projectile(bishop.position, Vector2i(0, 4), true)   # down-left → border
	_spawn_projectile(bishop.position, Vector2i(2, 4), true)   # down-right → border
	# White knight at (0,2) shoots all L-shapes
	if is_instance_valid(white_knight):
		_spawn_projectile(white_knight.position, Vector2i(1, 0), true)
		_spawn_projectile(white_knight.position, Vector2i(1, 4), true)
		_spawn_projectile(white_knight.position, Vector2i(2, 1), true)
		_spawn_projectile(white_knight.position, Vector2i(2, 3), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(white_knight) or not is_instance_valid(black_knight):
		return

	# White knight heals, black knight takes damage
	white_knight.heal(1)
	black_knight.take_damage(1)

	await get_tree().create_timer(1.5).timeout
	if not _should_continue(my_id) or not is_instance_valid(bishop):
		return

	# Reset
	bishop.move_to(_board_to_screen(Vector2i(0, 4)))
	pieces.erase(Vector2i(1, 3))
	pieces[Vector2i(0, 4)] = bishop
	bishop.board_position = Vector2i(0, 4)
	if is_instance_valid(white_knight):
		white_knight.reset_hp()
	if is_instance_valid(black_knight):
		black_knight.reset_hp()

	await get_tree().create_timer(0.3).timeout

# Step 4: Pieces have different HP
func _setup_step_4():
	# Row y=1: HP 1 pieces + Queen
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(0, 1))
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.WHITE, Vector2i(1, 1))
	_spawn_piece(GameManager.PieceType.QUEEN, GameManager.PieceColor.WHITE, Vector2i(2, 1))
	# Row y=3: HP 2 pieces
	_spawn_piece(GameManager.PieceType.BISHOP, GameManager.PieceColor.WHITE, Vector2i(0, 3))
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(1, 3))
	_spawn_piece(GameManager.PieceType.ROOK, GameManager.PieceColor.WHITE, Vector2i(2, 3))

func _animate_step_4(my_id: int):
	if not _should_continue(my_id):
		return

	var positions = [
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3)
	]

	for pos in positions:
		if not _should_continue(my_id):
			return
		_clear_highlights()
		_show_selected(pos)
		await get_tree().create_timer(1.0).timeout

	_clear_highlights()

# Step 5: When HP reaches 0, the piece dies
func _setup_step_5():
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.BLACK, Vector2i(2, 1))
	_spawn_piece(GameManager.PieceType.BISHOP, GameManager.PieceColor.WHITE, Vector2i(0, 3))
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(1, 4))

func _animate_step_5(my_id: int):
	if not _should_continue(my_id):
		return

	var black_knight = pieces.get(Vector2i(2, 1))
	var bishop = pieces.get(Vector2i(0, 3))
	var white_knight = pieces.get(Vector2i(1, 4))

	if not is_instance_valid(black_knight) or not is_instance_valid(bishop) or not is_instance_valid(white_knight):
		return

	_show_selected(Vector2i(1, 4))
	_show_highlights([Vector2i(0, 2)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(white_knight):
		return

	# White knight moves to (0,2) — L-shape attacks (2,1)
	_clear_highlights()
	white_knight.move_to(_board_to_screen(Vector2i(0, 2)))
	pieces.erase(Vector2i(1, 4))
	pieces[Vector2i(0, 2)] = white_knight
	white_knight.board_position = Vector2i(0, 2)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(white_knight) or not is_instance_valid(bishop):
		return

	# All white pieces shoot in attack directions
	# Knight at (0,2): all L-shapes on board
	_spawn_projectile(white_knight.position, Vector2i(2, 1), true)  # black knight → DMG
	_spawn_projectile(white_knight.position, Vector2i(1, 0), true)  # border
	_spawn_projectile(white_knight.position, Vector2i(1, 4), true)  # border
	_spawn_projectile(white_knight.position, Vector2i(2, 3), true)  # border
	# Bishop at (0,3): 2 valid diagonals (up-left/down-left OOB)
	_spawn_projectile(bishop.position, Vector2i(2, 1), true)        # up-right → black knight DMG
	_spawn_projectile(bishop.position, Vector2i(1, 4), true)        # down-right → border

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(black_knight):
		return

	# Black knight takes 2 damage (2 HP -> 0)
	black_knight.take_damage(1)
	await get_tree().create_timer(0.15).timeout
	if not _should_continue(my_id) or not is_instance_valid(black_knight):
		return
	black_knight.take_damage(1)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(black_knight):
		return

	# Black knight dies
	_spawn_explosion(black_knight.position, 0.5)
	black_knight.queue_free()
	pieces.erase(Vector2i(2, 1))

	await get_tree().create_timer(1.5).timeout
	if not _should_continue(my_id) or not is_instance_valid(white_knight):
		return

	# Reset
	white_knight.move_to(_board_to_screen(Vector2i(1, 4)))
	pieces.erase(Vector2i(0, 2))
	pieces[Vector2i(1, 4)] = white_knight
	white_knight.board_position = Vector2i(1, 4)

	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.BLACK, Vector2i(2, 1))

	await get_tree().create_timer(0.3).timeout

# Step 6: Kill the enemy King to win
func _setup_step_6():
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 0))
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 2))

func _animate_step_6(my_id: int):
	if not _should_continue(my_id):
		return

	var king = pieces.get(Vector2i(2, 0))
	var pawn = pieces.get(Vector2i(1, 2))

	if not is_instance_valid(king) or not is_instance_valid(pawn):
		return

	_show_selected(Vector2i(1, 2))
	_show_highlights([Vector2i(1, 1)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn moves forward
	_clear_highlights()
	pawn.move_to(_board_to_screen(Vector2i(1, 1)))
	pieces.erase(Vector2i(1, 2))
	pieces[Vector2i(1, 1)] = pawn
	pawn.board_position = Vector2i(1, 1)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn shoots both diags
	_spawn_projectile(pawn.position, Vector2i(0, 0), true)    # left diag → border
	_spawn_projectile(pawn.position, Vector2i(2, 0), true)    # right diag → king DMG

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(king):
		return

	# King dies
	king.take_damage(1)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(king):
		return

	_spawn_explosion(king.position, 1.5)
	king.queue_free()
	pieces.erase(Vector2i(2, 0))

	await get_tree().create_timer(3.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Reset
	pawn.move_to(_board_to_screen(Vector2i(1, 2)))
	pieces.erase(Vector2i(1, 1))
	pieces[Vector2i(1, 2)] = pawn
	pawn.board_position = Vector2i(1, 2)

	await get_tree().create_timer(0.5).timeout
	if not _should_continue(my_id):
		return

	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 0))

	await get_tree().create_timer(0.5).timeout

# Step 7: Check is allowed if King is protected
func _setup_step_7():
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 3))
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 1))
	# Rook starts on the side
	_spawn_piece(GameManager.PieceType.ROOK, GameManager.PieceColor.BLACK, Vector2i(0, 0))

func _animate_step_7(my_id: int):
	if not _should_continue(my_id):
		return

	var pawn = pieces.get(Vector2i(1, 3))
	var king = pieces.get(Vector2i(2, 1))
	var rook = pieces.get(Vector2i(0, 0))

	if not is_instance_valid(pawn) or not is_instance_valid(king) or not is_instance_valid(rook):
		return

	# === Black's turn: rook moves behind king to protect it ===
	_show_selected(Vector2i(0, 0))
	_show_highlights([Vector2i(2, 0)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	_clear_highlights()
	rook.move_to(_board_to_screen(Vector2i(2, 0)))
	pieces.erase(Vector2i(0, 0))
	pieces[Vector2i(2, 0)] = rook
	rook.board_position = Vector2i(2, 0)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook) or not is_instance_valid(king):
		return

	# All black pieces shoot
	# Rook at (2,0): 3 directions (up OOB)
	_spawn_projectile(rook.position, Vector2i(0, 0), false)    # left → border
	_spawn_projectile(rook.position, Vector2i(3, 0), false)    # right → border
	_spawn_projectile(rook.position, Vector2i(2, 1), false)    # down → king HEAL
	# King at (2,1): 8 adjacent cells
	if is_instance_valid(king):
		_spawn_projectile(king.position, Vector2i(1, 0), false)
		_spawn_projectile(king.position, Vector2i(2, 0), false)   # rook → HEAL
		_spawn_projectile(king.position, Vector2i(3, 0), false)
		_spawn_projectile(king.position, Vector2i(1, 1), false)
		_spawn_projectile(king.position, Vector2i(3, 1), false)
		_spawn_projectile(king.position, Vector2i(1, 2), false)
		_spawn_projectile(king.position, Vector2i(2, 2), false)
		_spawn_projectile(king.position, Vector2i(3, 2), false)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(king) or not is_instance_valid(rook):
		return

	king.heal(1)   # from rook → HP 1→2
	rook.heal(1)   # from king → HP 2→3

	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# === White's turn: pawn approaches king ===
	_show_selected(Vector2i(1, 3))
	_show_highlights([Vector2i(1, 2)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	_clear_highlights()
	pawn.move_to(_board_to_screen(Vector2i(1, 2)))
	pieces.erase(Vector2i(1, 3))
	pieces[Vector2i(1, 2)] = pawn
	pawn.board_position = Vector2i(1, 2)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn shoots both diags
	_spawn_projectile(pawn.position, Vector2i(0, 1), true)    # left diag → border
	_spawn_projectile(pawn.position, Vector2i(2, 1), true)    # right diag → king DMG

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(king):
		return

	king.take_damage(1)  # HP 2 -> 1, survives

	await get_tree().create_timer(1.5).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook) or not is_instance_valid(king):
		return

	# Reset: move rook back, pawn back, king HP back to 1
	rook.move_to(_board_to_screen(Vector2i(0, 0)))
	pieces.erase(Vector2i(2, 0))
	pieces[Vector2i(0, 0)] = rook
	rook.board_position = Vector2i(0, 0)

	pawn.move_to(_board_to_screen(Vector2i(1, 3)))
	pieces.erase(Vector2i(1, 2))
	pieces[Vector2i(1, 3)] = pawn
	pawn.board_position = Vector2i(1, 3)

	king.reset_hp()
	rook.reset_hp()

	await get_tree().create_timer(0.5).timeout

# Step 8: HP resets each turn — doesn't accumulate
func _setup_step_8():
	# White: two pawns in diagonal + king
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(0, 4))
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 3))
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.WHITE, Vector2i(3, 4))
	# Black: just a king that moves left-right
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(1, 0))

func _animate_step_8(my_id: int):
	if not _should_continue(my_id):
		return

	var w_pawn1 = pieces.get(Vector2i(0, 4))  # shoots at (1,3) — heals
	var w_pawn2 = pieces.get(Vector2i(1, 3))  # the one that gets healed
	var w_king = pieces.get(Vector2i(3, 4))
	var b_king = pieces.get(Vector2i(1, 0))

	if not is_instance_valid(w_pawn1) or not is_instance_valid(w_pawn2):
		return
	if not is_instance_valid(w_king) or not is_instance_valid(b_king):
		return

	# === White's turn: king approaches pawns ===
	# King moves (3,4) -> (2,3), now adjacent to pawn at (1,3)
	_show_selected(Vector2i(3, 4))
	_show_highlights([Vector2i(2, 3)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_king):
		return

	_clear_highlights()
	w_king.move_to(_board_to_screen(Vector2i(2, 3)))
	pieces.erase(Vector2i(3, 4))
	pieces[Vector2i(2, 3)] = w_king
	w_king.board_position = Vector2i(2, 3)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_king):
		return

	# All white pieces shoot
	# King at (2,3) shoots all 8 adjacent cells
	_spawn_projectile(w_king.position, Vector2i(1, 2), true)
	_spawn_projectile(w_king.position, Vector2i(2, 2), true)
	_spawn_projectile(w_king.position, Vector2i(3, 2), true)
	_spawn_projectile(w_king.position, Vector2i(1, 3), true)  # hits ally pawn — heal
	_spawn_projectile(w_king.position, Vector2i(3, 3), true)
	_spawn_projectile(w_king.position, Vector2i(1, 4), true)
	_spawn_projectile(w_king.position, Vector2i(2, 4), true)
	_spawn_projectile(w_king.position, Vector2i(3, 4), true)
	# Pawn at (0,4) shoots diag
	_spawn_projectile(w_pawn1.position, Vector2i(1, 3), true)  # hits ally pawn — heal
	# Pawn at (1,3) shoots diag
	_spawn_projectile(w_pawn2.position, Vector2i(0, 2), true)
	_spawn_projectile(w_pawn2.position, Vector2i(2, 2), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return

	# Pawn at (1,3) healed by king + pawn = +2 HP (1 -> 3)
	w_pawn2.heal(1)
	await get_tree().create_timer(0.15).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return
	w_pawn2.heal(1)  # HP now 3

	await get_tree().create_timer(1.2).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	# === Black's turn: king moves sideways (just passes the turn) ===
	_show_selected(Vector2i(1, 0))
	_show_highlights([Vector2i(0, 0)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	_clear_highlights()
	b_king.move_to(_board_to_screen(Vector2i(0, 0)))
	pieces.erase(Vector2i(1, 0))
	pieces[Vector2i(0, 0)] = b_king
	b_king.board_position = Vector2i(0, 0)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	# Black king shoots adjacent cells
	_spawn_projectile(b_king.position, Vector2i(1, 0), false)
	_spawn_projectile(b_king.position, Vector2i(0, 1), false)
	_spawn_projectile(b_king.position, Vector2i(1, 1), false)

	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return

	# === Start of white's next turn: HP resets ===
	w_pawn2.blink(Color(1.0, 1.0, 1.0))
	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return
	w_pawn2.reset_hp()  # HP 3 -> 1

	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_king):
		return

	# === White's turn: king returns ===
	_show_selected(Vector2i(2, 3))
	_show_highlights([Vector2i(3, 4)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_king):
		return

	_clear_highlights()
	w_king.move_to(_board_to_screen(Vector2i(3, 4)))
	pieces.erase(Vector2i(2, 3))
	pieces[Vector2i(3, 4)] = w_king
	w_king.board_position = Vector2i(3, 4)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_king):
		return

	# All white pieces shoot
	# King at (3,4): 3 valid adjacents
	_spawn_projectile(w_king.position, Vector2i(2, 3), true)
	_spawn_projectile(w_king.position, Vector2i(3, 3), true)
	_spawn_projectile(w_king.position, Vector2i(2, 4), true)
	# Pawn at (0,4): diag
	_spawn_projectile(w_pawn1.position, Vector2i(1, 3), true)  # heals pawn
	# Pawn at (1,3): diags
	_spawn_projectile(w_pawn2.position, Vector2i(0, 2), true)
	_spawn_projectile(w_pawn2.position, Vector2i(2, 2), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return

	w_pawn2.heal(1)  # from pawn → HP 1→2

	await get_tree().create_timer(1.2).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	# === Black's turn: king returns ===
	_show_selected(Vector2i(0, 0))
	_show_highlights([Vector2i(1, 0)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	_clear_highlights()
	b_king.move_to(_board_to_screen(Vector2i(1, 0)))
	pieces.erase(Vector2i(0, 0))
	pieces[Vector2i(1, 0)] = b_king
	b_king.board_position = Vector2i(1, 0)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	# Black king at (1,0): 5 valid adjacents
	_spawn_projectile(b_king.position, Vector2i(0, 0), false)
	_spawn_projectile(b_king.position, Vector2i(2, 0), false)
	_spawn_projectile(b_king.position, Vector2i(0, 1), false)
	_spawn_projectile(b_king.position, Vector2i(1, 1), false)
	_spawn_projectile(b_king.position, Vector2i(2, 1), false)

	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return

	# HP resets again before loop
	w_pawn2.blink(Color(1.0, 1.0, 1.0))
	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(w_pawn2):
		return
	w_pawn2.reset_hp()  # HP 2→1

	await get_tree().create_timer(0.5).timeout

# Step 9: Protect your King — kill the enemy King!
func _setup_step_9():
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 1))
	_spawn_piece(GameManager.PieceType.QUEEN, GameManager.PieceColor.WHITE, Vector2i(1, 4))
	_spawn_piece(GameManager.PieceType.ROOK, GameManager.PieceColor.WHITE, Vector2i(0, 3))
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.WHITE, Vector2i(0, 4))
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(3, 3))
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 3))

func _animate_step_9(my_id: int):
	if not _should_continue(my_id):
		return

	var b_king = pieces.get(Vector2i(2, 1))
	var pawn = pieces.get(Vector2i(1, 3))
	var knight = pieces.get(Vector2i(3, 3))
	var queen = pieces.get(Vector2i(1, 4))
	var rook = pieces.get(Vector2i(0, 3))
	var w_king = pieces.get(Vector2i(0, 4))

	if not is_instance_valid(b_king) or not is_instance_valid(pawn):
		return

	_show_selected(Vector2i(1, 3))
	_show_highlights([Vector2i(1, 2)])

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn moves forward
	_clear_highlights()
	pawn.move_to(_board_to_screen(Vector2i(1, 2)))
	pieces.erase(Vector2i(1, 3))
	pieces[Vector2i(1, 2)] = pawn
	pawn.board_position = Vector2i(1, 2)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# ALL white pieces shoot in all attack directions
	# Pawn at (1,2): diags forward
	_spawn_projectile(pawn.position, Vector2i(0, 1), true)   # border
	_spawn_projectile(pawn.position, Vector2i(2, 1), true)   # black king → DMG
	# Knight at (3,3): L-shapes hitting 3 valid cells
	if is_instance_valid(knight):
		_spawn_projectile(knight.position, Vector2i(2, 1), true)  # black king → DMG
		_spawn_projectile(knight.position, Vector2i(1, 2), true)  # pawn → HEAL
		_spawn_projectile(knight.position, Vector2i(1, 4), true)  # queen → HEAL
	# Queen at (1,4): 5 directions (down/down-left/down-right OOB)
	if is_instance_valid(queen):
		_spawn_projectile(queen.position, Vector2i(1, 2), true)   # up → pawn HEAL
		_spawn_projectile(queen.position, Vector2i(0, 4), true)   # left → king HEAL
		_spawn_projectile(queen.position, Vector2i(3, 4), true)   # right → border
		_spawn_projectile(queen.position, Vector2i(0, 3), true)   # up-left → rook HEAL
		_spawn_projectile(queen.position, Vector2i(3, 2), true)   # up-right → border
	# Rook at (0,3): 3 directions (left OOB)
	if is_instance_valid(rook):
		_spawn_projectile(rook.position, Vector2i(0, 0), true)    # up → border
		_spawn_projectile(rook.position, Vector2i(0, 4), true)    # down → king HEAL
		_spawn_projectile(rook.position, Vector2i(3, 3), true)    # right → knight HEAL
	# King at (0,4): 3 valid adjacent cells
	if is_instance_valid(w_king):
		_spawn_projectile(w_king.position, Vector2i(0, 3), true)  # rook → HEAL
		_spawn_projectile(w_king.position, Vector2i(1, 3), true)  # empty
		_spawn_projectile(w_king.position, Vector2i(1, 4), true)  # queen → HEAL

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	# Apply damage and heals
	b_king.take_damage(1)  # king HP 1→0, dies
	if is_instance_valid(pawn):
		pawn.heal(1)   # from knight
		pawn.heal(1)   # from queen → HP 1→3
	if is_instance_valid(queen):
		queen.heal(1)  # from w_king
		queen.heal(1)  # from knight → HP 3→5
	if is_instance_valid(rook):
		rook.heal(1)   # from queen
		rook.heal(1)   # from w_king → HP 2→4
	if is_instance_valid(knight):
		knight.heal(1) # from rook → HP 2→3
	if is_instance_valid(w_king):
		w_king.heal(1) # from queen
		w_king.heal(1) # from rook → HP 1→3

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(b_king):
		return

	# King dies — big explosion
	_spawn_explosion(b_king.position, 2.0)
	b_king.queue_free()
	pieces.erase(Vector2i(2, 1))

	await get_tree().create_timer(3.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Reset positions and HP
	pawn.move_to(_board_to_screen(Vector2i(1, 3)))
	pieces.erase(Vector2i(1, 2))
	pieces[Vector2i(1, 3)] = pawn
	pawn.board_position = Vector2i(1, 3)
	if is_instance_valid(pawn):
		pawn.reset_hp()
	if is_instance_valid(queen):
		queen.reset_hp()
	if is_instance_valid(rook):
		rook.reset_hp()
	if is_instance_valid(knight):
		knight.reset_hp()
	if is_instance_valid(w_king):
		w_king.reset_hp()

	await get_tree().create_timer(0.5).timeout
	if not _should_continue(my_id):
		return

	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 1))

	await get_tree().create_timer(0.5).timeout

func _show_highlights(positions: Array):
	for pos in positions:
		var highlight = ColorRect.new()
		highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
		var screen_pos = _board_to_screen(pos)
		highlight.position = Vector2(screen_pos.x - SQUARE_SIZE / 2, screen_pos.y - SQUARE_SIZE / 2)
		highlight.color = HIGHLIGHT_COLOR
		highlights_container.add_child(highlight)

func _show_selected(pos: Vector2i):
	var highlight = ColorRect.new()
	highlight.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	var screen_pos = _board_to_screen(pos)
	highlight.position = Vector2(screen_pos.x - SQUARE_SIZE / 2, screen_pos.y - SQUARE_SIZE / 2)
	highlight.color = SELECTED_COLOR
	highlights_container.add_child(highlight)

func _clear_highlights():
	for highlight in highlights_container.get_children():
		highlight.queue_free()

func _spawn_projectile(from_pos: Vector2, target_cell: Vector2i, is_white: bool):
	var projectile = ProjectileScene.instantiate()
	var target_pos = _board_to_screen(target_cell)
	var bounds = Rect2(0, 0, BOARD_COLS * SQUARE_SIZE, BOARD_ROWS * SQUARE_SIZE)
	projectile.setup_targeted(from_pos, target_pos, target_cell, is_white, bounds)
	projectile.skip_piece_check = true  # Tutorial mode - don't use GameManager
	projectile.scale = Vector2(0.6, 0.6)
	projectile.finished.connect(_on_projectile_finished)
	projectiles_container.add_child(projectile)
	active_projectiles += 1

func _on_projectile_finished(_hit_piece, _is_white: bool):
	active_projectiles -= 1

func _spawn_explosion(pos: Vector2, scale_multiplier: float = 1.0):
	var explosion = ExplosionScene.instantiate()
	explosion.position = pos
	explosion.scale = Vector2(0.6, 0.6)
	add_child(explosion)
	explosion.explode(scale_multiplier)
