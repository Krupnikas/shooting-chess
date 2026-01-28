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

# Step 1: Basic Movement
func _setup_step_1():
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(1, 2))

func _animate_step_1(my_id: int):
	if not _should_continue(my_id):
		return

	var knight = pieces.get(Vector2i(1, 2))
	if not is_instance_valid(knight):
		return

	# Show valid moves (L-shaped from position 1,2)
	var knight_moves = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 1), Vector2i(3, 3), Vector2i(2, 4), Vector2i(0, 4)]
	_show_highlights(knight_moves)
	_show_selected(Vector2i(1, 2))

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id):
		return

	# Move knight
	_clear_highlights()
	var target = Vector2i(3, 1)
	knight.move_to(_board_to_screen(target))
	pieces.erase(Vector2i(1, 2))
	pieces[target] = knight
	knight.board_position = target

	await get_tree().create_timer(0.5).timeout
	if not _should_continue(my_id):
		return

	# Show new valid moves from 3,1
	var new_moves = [Vector2i(1, 0), Vector2i(2, 3), Vector2i(1, 2)]
	_show_highlights(new_moves)
	_show_selected(target)

	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id):
		return

	# Move back
	_clear_highlights()
	knight.move_to(_board_to_screen(Vector2i(1, 2)))
	pieces.erase(target)
	pieces[Vector2i(1, 2)] = knight
	knight.board_position = Vector2i(1, 2)

	await get_tree().create_timer(0.3).timeout

# Step 2: HP System
func _setup_step_2():
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(0, 4))
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(1, 4))
	_spawn_piece(GameManager.PieceType.ROOK, GameManager.PieceColor.WHITE, Vector2i(2, 4))
	_spawn_piece(GameManager.PieceType.QUEEN, GameManager.PieceColor.WHITE, Vector2i(3, 4))
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(1, 0))

func _animate_step_2(my_id: int):
	if not _should_continue(my_id):
		return

	var positions = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 0)]

	for i in range(positions.size()):
		if not _should_continue(my_id):
			return

		_clear_highlights()
		_show_selected(positions[i])

		await get_tree().create_timer(1.0).timeout

# Step 3: Shooting
# Rook moves and shoots - first cycle heals pawn, second cycle damages knight
func _setup_step_3():
	# White rook that will move and shoot
	_spawn_piece(GameManager.PieceType.ROOK, GameManager.PieceColor.WHITE, Vector2i(1, 4))
	# Friendly pawn that will be healed (first cycle)
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.WHITE, Vector2i(1, 2))
	# Enemy knight that will be damaged (second cycle)
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.BLACK, Vector2i(3, 2))

func _animate_step_3(my_id: int):
	if not _should_continue(my_id):
		return

	var rook = pieces.get(Vector2i(1, 4))
	var pawn = pieces.get(Vector2i(1, 2))
	var enemy_knight = pieces.get(Vector2i(3, 2))

	if not is_instance_valid(rook) or not is_instance_valid(pawn) or not is_instance_valid(enemy_knight):
		return

	# Initial pause to read the text
	await get_tree().create_timer(2.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	# === Cycle 1: Rook heals friendly pawn ===
	_show_selected(Vector2i(1, 4))
	_show_highlights([Vector2i(1, 3), Vector2i(1, 2)])
	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	# Rook moves up to (1,3)
	_clear_highlights()
	var rook_pos1 = Vector2i(1, 3)
	rook.move_to(_board_to_screen(rook_pos1))
	pieces.erase(Vector2i(1, 4))
	pieces[rook_pos1] = rook
	rook.board_position = rook_pos1

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	# Rook shoots up, hits friendly pawn at (1,2)
	_spawn_projectile(rook.position, Vector2i(1, 2), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn heals (green blink)
	pawn.heal(1)

	await get_tree().create_timer(1.5).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook) or not is_instance_valid(pawn):
		return

	# Reset rook position for cycle 2
	rook.move_to(_board_to_screen(Vector2i(1, 4)))
	pieces.erase(rook_pos1)
	pieces[Vector2i(1, 4)] = rook
	rook.board_position = Vector2i(1, 4)
	pawn.reset_hp()

	await get_tree().create_timer(0.5).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	# === Cycle 2: Rook damages enemy knight ===
	_show_selected(Vector2i(1, 4))
	_show_highlights([Vector2i(2, 4), Vector2i(3, 4)])
	await get_tree().create_timer(0.8).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	# Rook moves right to (3,4)
	_clear_highlights()
	var rook_pos2 = Vector2i(3, 4)
	rook.move_to(_board_to_screen(rook_pos2))
	pieces.erase(Vector2i(1, 4))
	pieces[rook_pos2] = rook
	rook.board_position = rook_pos2

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook):
		return

	# Rook shoots up, hits enemy knight at (3,2)
	_spawn_projectile(rook.position, Vector2i(3, 2), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(enemy_knight):
		return

	# Enemy knight takes damage (red blink)
	enemy_knight.take_damage(1)

	await get_tree().create_timer(1.5).timeout
	if not _should_continue(my_id) or not is_instance_valid(rook) or not is_instance_valid(enemy_knight):
		return

	# Reset for loop
	rook.move_to(_board_to_screen(Vector2i(1, 4)))
	pieces.erase(rook_pos2)
	pieces[Vector2i(1, 4)] = rook
	rook.board_position = Vector2i(1, 4)
	enemy_knight.reset_hp()

	await get_tree().create_timer(0.5).timeout

# Step 4: Death and HP Reset
# Knight moves, then shoots at pawn which dies
func _setup_step_4():
	# White knight that will move and shoot
	_spawn_piece(GameManager.PieceType.KNIGHT, GameManager.PieceColor.WHITE, Vector2i(1, 3))
	# Black pawn that will be killed (HP 1)
	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.BLACK, Vector2i(2, 0))

func _animate_step_4(my_id: int):
	if not _should_continue(my_id):
		return

	var knight = pieces.get(Vector2i(1, 3))
	var pawn = pieces.get(Vector2i(2, 0))

	if not is_instance_valid(knight) or not is_instance_valid(pawn):
		return

	# Show knight selected with valid moves
	_show_selected(Vector2i(1, 3))
	var knight_moves = [Vector2i(0, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(3, 4)]
	_show_highlights(knight_moves)

	await get_tree().create_timer(0.6).timeout
	if not _should_continue(my_id) or not is_instance_valid(knight):
		return

	# Knight moves to position where it can shoot pawn
	_clear_highlights()
	var target = Vector2i(0, 1)
	knight.move_to(_board_to_screen(target))
	pieces.erase(Vector2i(1, 3))
	pieces[target] = knight
	knight.board_position = target

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(knight):
		return

	# Shooting phase - knight shoots at pawn (L-shaped attack)
	_spawn_projectile(knight.position, Vector2i(2, 0), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn takes damage and dies (HP 1 -> 0)
	pawn.take_damage(1)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(pawn):
		return

	# Pawn dies with explosion
	_spawn_explosion(pawn.position, 0.5)
	pawn.queue_free()
	pieces.erase(Vector2i(2, 0))

	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(knight):
		return

	# Show HP reset text moment - knight's HP resets at start of next turn
	knight.heal(1)  # Show heal effect to indicate HP reset

	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(knight):
		return

	# Reset for loop - move knight back and respawn pawn
	knight.move_to(_board_to_screen(Vector2i(1, 3)))
	pieces.erase(target)
	pieces[Vector2i(1, 3)] = knight
	knight.board_position = Vector2i(1, 3)
	knight.reset_hp()

	_spawn_piece(GameManager.PieceType.PAWN, GameManager.PieceColor.BLACK, Vector2i(2, 0))

	await get_tree().create_timer(0.3).timeout

# Step 5: Win Condition
# Queen moves, then shoots and kills enemy king
func _setup_step_5():
	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 0))
	_spawn_piece(GameManager.PieceType.QUEEN, GameManager.PieceColor.WHITE, Vector2i(2, 4))

func _animate_step_5(my_id: int):
	if not _should_continue(my_id):
		return

	var king = pieces.get(Vector2i(2, 0))
	var queen = pieces.get(Vector2i(2, 4))

	if not is_instance_valid(king) or not is_instance_valid(queen):
		return

	# Show queen selected with valid moves
	_show_selected(Vector2i(2, 4))
	_show_highlights([Vector2i(2, 3), Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 3), Vector2i(3, 3), Vector2i(1, 4), Vector2i(3, 4)])
	await get_tree().create_timer(1.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(queen):
		return

	# Queen moves closer to king
	_clear_highlights()
	var target = Vector2i(2, 2)
	queen.move_to(_board_to_screen(target))
	pieces.erase(Vector2i(2, 4))
	pieces[target] = queen
	queen.board_position = target

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(queen):
		return

	# Shooting phase - queen shoots at king
	_spawn_projectile(queen.position, Vector2i(2, 0), true)

	await get_tree().create_timer(0.4).timeout
	if not _should_continue(my_id) or not is_instance_valid(king):
		return

	# King takes damage (HP 1 -> 0)
	king.take_damage(1)

	await get_tree().create_timer(0.3).timeout
	if not _should_continue(my_id) or not is_instance_valid(king):
		return

	# King dies - big explosion
	var king_pos = king.position
	_spawn_explosion(king_pos, 1.5)
	king.queue_free()
	pieces.erase(Vector2i(2, 0))

	# Wait longer for dramatic effect
	await get_tree().create_timer(3.0).timeout
	if not _should_continue(my_id) or not is_instance_valid(queen):
		return

	# Reset for loop - move queen back and respawn king
	queen.move_to(_board_to_screen(Vector2i(2, 4)))
	pieces.erase(target)
	pieces[Vector2i(2, 4)] = queen
	queen.board_position = Vector2i(2, 4)

	await get_tree().create_timer(0.5).timeout
	if not _should_continue(my_id):
		return

	_spawn_piece(GameManager.PieceType.KING, GameManager.PieceColor.BLACK, Vector2i(2, 0))

	await get_tree().create_timer(1.0).timeout

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
