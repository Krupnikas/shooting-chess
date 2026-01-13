extends SceneTree

# Test runner for Shooting Chess
# Run with: godot --headless --script tests/test_runner.gd

var tests_passed = 0
var tests_failed = 0
var current_test = ""

func _init():
	print("\n========================================")
	print("   SHOOTING CHESS TEST SUITE")
	print("========================================\n")

	run_all_tests()

	print("\n========================================")
	print("   RESULTS: %d passed, %d failed" % [tests_passed, tests_failed])
	print("========================================\n")

	quit(0 if tests_failed == 0 else 1)

func run_all_tests():
	test_position_validation()
	test_board_coordinates()
	test_pawn_moves()
	test_knight_moves()
	test_bishop_moves()
	test_rook_moves()
	test_queen_moves()
	test_king_moves()
	test_hp_values()
	test_piece_blocking()
	test_pawn_attack_squares()
	test_attack_targeting()
	test_reinforcement()
	test_shooting()
	test_mate_in_3()
	test_king_capture_win()
	test_king_death_by_shooting()

# ============ HELPER FUNCTIONS ============

func start_test(name: String):
	current_test = name
	print("TEST: %s" % name)

func assert_true(condition: bool, message: String = ""):
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % message)
	else:
		tests_failed += 1
		print("  ✗ FAIL: %s" % message)

func assert_equal(actual, expected, message: String = ""):
	if actual == expected:
		tests_passed += 1
		print("  ✓ PASS: %s" % message)
	else:
		tests_failed += 1
		print("  ✗ FAIL: %s (expected %s, got %s)" % [message, expected, actual])

func assert_contains(array: Array, item, message: String = ""):
	if item in array:
		tests_passed += 1
		print("  ✓ PASS: %s" % message)
	else:
		tests_failed += 1
		print("  ✗ FAIL: %s (item %s not in array)" % [message, item])

func assert_not_contains(array: Array, item, message: String = ""):
	if item not in array:
		tests_passed += 1
		print("  ✓ PASS: %s" % message)
	else:
		tests_failed += 1
		print("  ✗ FAIL: %s (item %s should not be in array)" % [message, item])

# ============ MOCK PIECE CLASS ============

class MockPiece:
	var type: int
	var color: int
	var board_position: Vector2i
	var hp: int
	var base_hp: int

	func _init(p_type: int, p_color: int, p_pos: Vector2i):
		type = p_type
		color = p_color
		board_position = p_pos
		base_hp = BASE_HP_MAP.get(p_type, 1)
		hp = base_hp

# ============ GAME LOGIC COPY FOR TESTING ============
# (We copy the logic here since we can't easily access autoload in --script mode)

enum PieceType { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum PieceColor { WHITE, BLACK }

const BOARD_SIZE = 8
const BASE_HP_MAP = {
	PieceType.PAWN: 1,
	PieceType.KNIGHT: 2,
	PieceType.BISHOP: 2,
	PieceType.ROOK: 2,
	PieceType.QUEEN: 3,
	PieceType.KING: 1
}

func get_base_hp(type: int) -> int:
	return BASE_HP_MAP.get(type, 1)

var test_board: Array = []

func clear_board():
	test_board.clear()
	for row in range(BOARD_SIZE):
		var board_row = []
		for col in range(BOARD_SIZE):
			board_row.append(null)
		test_board.append(board_row)

func place_piece(piece: MockPiece):
	test_board[piece.board_position.y][piece.board_position.x] = piece

func get_piece_at(pos: Vector2i):
	if is_valid_position(pos):
		return test_board[pos.y][pos.x]
	return null

func is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func get_valid_moves(piece: MockPiece) -> Array[Vector2i]:
	match piece.type:
		PieceType.PAWN:
			return get_pawn_moves(piece)
		PieceType.KNIGHT:
			return get_knight_moves(piece)
		PieceType.BISHOP:
			return get_bishop_moves(piece)
		PieceType.ROOK:
			return get_rook_moves(piece)
		PieceType.QUEEN:
			return get_queen_moves(piece)
		PieceType.KING:
			return get_king_moves(piece)
	return []

func get_pawn_moves(piece: MockPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var pos = piece.board_position
	var direction = -1 if piece.color == PieceColor.WHITE else 1
	var start_row = 6 if piece.color == PieceColor.WHITE else 1

	var forward = Vector2i(pos.x, pos.y + direction)
	if is_valid_position(forward) and get_piece_at(forward) == null:
		moves.append(forward)
		if pos.y == start_row:
			var double_forward = Vector2i(pos.x, pos.y + direction * 2)
			if get_piece_at(double_forward) == null:
				moves.append(double_forward)

	for dx in [-1, 1]:
		var capture_pos = Vector2i(pos.x + dx, pos.y + direction)
		if is_valid_position(capture_pos):
			var target = get_piece_at(capture_pos)
			if target != null and target.color != piece.color:
				moves.append(capture_pos)

	return moves

func get_knight_moves(piece: MockPiece) -> Array[Vector2i]:
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

func get_bishop_moves(piece: MockPiece) -> Array[Vector2i]:
	return get_sliding_moves(piece, [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])

func get_rook_moves(piece: MockPiece) -> Array[Vector2i]:
	return get_sliding_moves(piece, [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)])

func get_queen_moves(piece: MockPiece) -> Array[Vector2i]:
	return get_sliding_moves(piece, [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	])

func get_sliding_moves(piece: MockPiece, directions: Array) -> Array[Vector2i]:
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

func get_king_moves(piece: MockPiece) -> Array[Vector2i]:
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

# ============ TESTS ============

func test_position_validation():
	start_test("Position Validation")

	assert_true(is_valid_position(Vector2i(0, 0)), "0,0 is valid")
	assert_true(is_valid_position(Vector2i(7, 7)), "7,7 is valid")
	assert_true(is_valid_position(Vector2i(4, 4)), "4,4 is valid")
	assert_true(!is_valid_position(Vector2i(-1, 0)), "-1,0 is invalid")
	assert_true(!is_valid_position(Vector2i(0, -1)), "0,-1 is invalid")
	assert_true(!is_valid_position(Vector2i(8, 0)), "8,0 is invalid")
	assert_true(!is_valid_position(Vector2i(0, 8)), "0,8 is invalid")

func test_board_coordinates():
	start_test("Board Coordinates")

	clear_board()
	var piece = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(3, 4))
	place_piece(piece)

	assert_equal(get_piece_at(Vector2i(3, 4)), piece, "Piece placed at 3,4")
	assert_equal(get_piece_at(Vector2i(0, 0)), null, "No piece at 0,0")
	assert_equal(get_piece_at(Vector2i(10, 10)), null, "Out of bounds returns null")

func test_pawn_moves():
	start_test("Pawn Movement")

	# White pawn at starting position
	clear_board()
	var white_pawn = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 6))
	place_piece(white_pawn)
	var moves = get_valid_moves(white_pawn)

	assert_contains(moves, Vector2i(4, 5), "White pawn can move forward one")
	assert_contains(moves, Vector2i(4, 4), "White pawn can move forward two from start")
	assert_equal(moves.size(), 2, "White pawn has 2 moves from start")

	# White pawn not at starting position
	clear_board()
	var white_pawn2 = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(white_pawn2)
	moves = get_valid_moves(white_pawn2)

	assert_contains(moves, Vector2i(4, 3), "White pawn can move forward one")
	assert_not_contains(moves, Vector2i(4, 2), "White pawn cannot move two from non-start")

	# Pawn capture
	clear_board()
	var white_pawn3 = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 4))
	var black_pawn = MockPiece.new(PieceType.PAWN, PieceColor.BLACK, Vector2i(3, 3))
	place_piece(white_pawn3)
	place_piece(black_pawn)
	moves = get_valid_moves(white_pawn3)

	assert_contains(moves, Vector2i(3, 3), "White pawn can capture diagonally")
	assert_contains(moves, Vector2i(4, 3), "White pawn can still move forward")

	# Black pawn moves in opposite direction
	clear_board()
	var black_pawn2 = MockPiece.new(PieceType.PAWN, PieceColor.BLACK, Vector2i(4, 1))
	place_piece(black_pawn2)
	moves = get_valid_moves(black_pawn2)

	assert_contains(moves, Vector2i(4, 2), "Black pawn moves down")
	assert_contains(moves, Vector2i(4, 3), "Black pawn can move two from start")

func test_knight_moves():
	start_test("Knight Movement")

	clear_board()
	var knight = MockPiece.new(PieceType.KNIGHT, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(knight)
	var moves = get_valid_moves(knight)

	assert_equal(moves.size(), 8, "Knight in center has 8 moves")
	assert_contains(moves, Vector2i(5, 6), "Knight L-shape move")
	assert_contains(moves, Vector2i(6, 5), "Knight L-shape move")
	assert_contains(moves, Vector2i(3, 2), "Knight L-shape move")
	assert_contains(moves, Vector2i(2, 3), "Knight L-shape move")

	# Knight in corner
	clear_board()
	var corner_knight = MockPiece.new(PieceType.KNIGHT, PieceColor.WHITE, Vector2i(0, 0))
	place_piece(corner_knight)
	moves = get_valid_moves(corner_knight)

	assert_equal(moves.size(), 2, "Knight in corner has 2 moves")
	assert_contains(moves, Vector2i(1, 2), "Knight can jump to 1,2")
	assert_contains(moves, Vector2i(2, 1), "Knight can jump to 2,1")

func test_bishop_moves():
	start_test("Bishop Movement")

	clear_board()
	var bishop = MockPiece.new(PieceType.BISHOP, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(bishop)
	var moves = get_valid_moves(bishop)

	assert_equal(moves.size(), 13, "Bishop in center has 13 moves")
	assert_contains(moves, Vector2i(5, 5), "Bishop diagonal")
	assert_contains(moves, Vector2i(7, 7), "Bishop diagonal to corner")
	assert_contains(moves, Vector2i(0, 0), "Bishop diagonal to opposite corner")
	assert_not_contains(moves, Vector2i(4, 5), "Bishop cannot move straight")

func test_rook_moves():
	start_test("Rook Movement")

	clear_board()
	var rook = MockPiece.new(PieceType.ROOK, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(rook)
	var moves = get_valid_moves(rook)

	assert_equal(moves.size(), 14, "Rook in center has 14 moves")
	assert_contains(moves, Vector2i(4, 0), "Rook can move to top")
	assert_contains(moves, Vector2i(4, 7), "Rook can move to bottom")
	assert_contains(moves, Vector2i(0, 4), "Rook can move to left")
	assert_contains(moves, Vector2i(7, 4), "Rook can move to right")
	assert_not_contains(moves, Vector2i(5, 5), "Rook cannot move diagonally")

func test_queen_moves():
	start_test("Queen Movement")

	clear_board()
	var queen = MockPiece.new(PieceType.QUEEN, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(queen)
	var moves = get_valid_moves(queen)

	assert_equal(moves.size(), 27, "Queen in center has 27 moves")
	assert_contains(moves, Vector2i(4, 0), "Queen can move straight")
	assert_contains(moves, Vector2i(7, 7), "Queen can move diagonal")

func test_king_moves():
	start_test("King Movement")

	clear_board()
	var king = MockPiece.new(PieceType.KING, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(king)
	var moves = get_valid_moves(king)

	assert_equal(moves.size(), 8, "King in center has 8 moves")
	assert_contains(moves, Vector2i(4, 5), "King one square down")
	assert_contains(moves, Vector2i(5, 5), "King one square diagonal")
	assert_not_contains(moves, Vector2i(4, 6), "King cannot move two squares")

func test_hp_values():
	start_test("HP Values")

	assert_equal(get_base_hp(PieceType.PAWN), 1, "Pawn base HP is 1")
	assert_equal(get_base_hp(PieceType.KNIGHT), 3, "Knight base HP is 3")
	assert_equal(get_base_hp(PieceType.BISHOP), 3, "Bishop base HP is 3")
	assert_equal(get_base_hp(PieceType.ROOK), 4, "Rook base HP is 4")
	assert_equal(get_base_hp(PieceType.QUEEN), 8, "Queen base HP is 8")
	assert_equal(get_base_hp(PieceType.KING), 8, "King base HP is 8")

func test_piece_blocking():
	start_test("Piece Blocking")

	# Rook blocked by friendly piece
	clear_board()
	var rook = MockPiece.new(PieceType.ROOK, PieceColor.WHITE, Vector2i(4, 4))
	var blocker = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 2))
	place_piece(rook)
	place_piece(blocker)
	var moves = get_valid_moves(rook)

	assert_contains(moves, Vector2i(4, 3), "Rook can move to square before blocker")
	assert_not_contains(moves, Vector2i(4, 2), "Rook cannot capture friendly piece")
	assert_not_contains(moves, Vector2i(4, 1), "Rook cannot jump over friendly piece")
	assert_not_contains(moves, Vector2i(4, 0), "Rook cannot jump over friendly piece")

	# Rook can capture enemy piece
	clear_board()
	var rook2 = MockPiece.new(PieceType.ROOK, PieceColor.WHITE, Vector2i(4, 4))
	var enemy = MockPiece.new(PieceType.PAWN, PieceColor.BLACK, Vector2i(4, 2))
	place_piece(rook2)
	place_piece(enemy)
	moves = get_valid_moves(rook2)

	assert_contains(moves, Vector2i(4, 2), "Rook can capture enemy piece")
	assert_not_contains(moves, Vector2i(4, 1), "Rook cannot jump over enemy piece")

func test_pawn_attack_squares():
	start_test("Pawn Attack Squares")

	# Pawn attack squares are diagonal only (different from movement)
	clear_board()
	var white_pawn = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(white_pawn)
	var attack_squares = get_pawn_attack_squares(white_pawn)

	assert_equal(attack_squares.size(), 2, "White pawn has 2 attack squares")
	assert_contains(attack_squares, Vector2i(3, 3), "White pawn attacks diagonally left")
	assert_contains(attack_squares, Vector2i(5, 3), "White pawn attacks diagonally right")
	assert_not_contains(attack_squares, Vector2i(4, 3), "White pawn does not attack forward")

	# Black pawn attacks in opposite direction
	clear_board()
	var black_pawn = MockPiece.new(PieceType.PAWN, PieceColor.BLACK, Vector2i(4, 4))
	place_piece(black_pawn)
	attack_squares = get_pawn_attack_squares(black_pawn)

	assert_contains(attack_squares, Vector2i(3, 5), "Black pawn attacks diagonally left")
	assert_contains(attack_squares, Vector2i(5, 5), "Black pawn attacks diagonally right")

func test_attack_targeting():
	start_test("Attack Targeting")

	# Test friendly targets (for reinforcement)
	clear_board()
	var white_rook = MockPiece.new(PieceType.ROOK, PieceColor.WHITE, Vector2i(4, 4))
	var white_pawn = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 2))
	var black_pawn = MockPiece.new(PieceType.PAWN, PieceColor.BLACK, Vector2i(4, 6))
	place_piece(white_rook)
	place_piece(white_pawn)
	place_piece(black_pawn)

	var friendly = get_friendly_targets(white_rook)
	var enemies = get_enemy_targets(white_rook)

	assert_equal(friendly.size(), 1, "Rook has 1 friendly target")
	assert_equal(friendly[0], white_pawn, "Rook's friendly target is the white pawn")
	assert_equal(enemies.size(), 1, "Rook has 1 enemy target")
	assert_equal(enemies[0], black_pawn, "Rook's enemy target is the black pawn")

	# Piece cannot target itself
	clear_board()
	var knight = MockPiece.new(PieceType.KNIGHT, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(knight)
	friendly = get_friendly_targets(knight)
	assert_equal(friendly.size(), 0, "Knight cannot target itself")

func test_reinforcement():
	start_test("Reinforcement HP Stacking")

	# Test that HP can exceed base value
	clear_board()
	var pawn = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(pawn)

	assert_equal(pawn.hp, 1, "Pawn starts with 1 HP")

	# Simulate reinforcement
	pawn.hp += 1  # One reinforce
	assert_equal(pawn.hp, 2, "Pawn has 2 HP after one reinforce")

	pawn.hp += 1  # Another reinforce
	assert_equal(pawn.hp, 3, "Pawn has 3 HP after two reinforces (exceeds base)")

	# Simulate taking damage
	pawn.hp -= 1
	assert_equal(pawn.hp, 2, "Pawn has 2 HP after taking 1 damage")

func test_shooting():
	start_test("Shooting and Death")

	clear_board()
	var pawn = MockPiece.new(PieceType.PAWN, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(pawn)

	assert_equal(pawn.hp, 1, "Pawn starts with 1 HP")

	# Simulate shooting
	pawn.hp -= 1
	assert_equal(pawn.hp, 0, "Pawn has 0 HP after being shot")
	assert_true(pawn.hp <= 0, "Pawn should be dead (hp <= 0)")

	# Test knight survives one hit
	clear_board()
	var knight = MockPiece.new(PieceType.KNIGHT, PieceColor.WHITE, Vector2i(4, 4))
	place_piece(knight)

	assert_equal(knight.hp, 3, "Knight starts with 3 HP")
	knight.hp -= 1
	assert_equal(knight.hp, 2, "Knight has 2 HP after one hit")
	assert_true(knight.hp > 0, "Knight is still alive")

# ============ ATTACK SQUARE HELPERS ============

func get_pawn_attack_squares(piece: MockPiece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	var pos = piece.board_position
	var direction = -1 if piece.color == PieceColor.WHITE else 1

	for dx in [-1, 1]:
		var attack_pos = Vector2i(pos.x + dx, pos.y + direction)
		if is_valid_position(attack_pos):
			squares.append(attack_pos)

	return squares

func get_friendly_targets(piece: MockPiece) -> Array:
	var targets = []
	var attack_squares = get_attack_squares_for_piece(piece)

	for square in attack_squares:
		var target = get_piece_at(square)
		if target != null and target.color == piece.color and target != piece:
			targets.append(target)

	return targets

func get_enemy_targets(piece: MockPiece) -> Array:
	var targets = []
	var attack_squares = get_attack_squares_for_piece(piece)

	for square in attack_squares:
		var target = get_piece_at(square)
		if target != null and target.color != piece.color:
			targets.append(target)

	return targets

func get_attack_squares_for_piece(piece: MockPiece) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []

	match piece.type:
		PieceType.PAWN:
			squares = get_pawn_attack_squares(piece)
		PieceType.KNIGHT:
			squares = get_knight_attack_squares_test(piece)
		PieceType.BISHOP:
			squares = get_sliding_attack_squares_test(piece, [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
		PieceType.ROOK:
			squares = get_sliding_attack_squares_test(piece, [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)])
		PieceType.QUEEN:
			squares = get_sliding_attack_squares_test(piece, [
				Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
			])
		PieceType.KING:
			squares = get_king_attack_squares_test(piece)

	return squares

func get_knight_attack_squares_test(piece: MockPiece) -> Array[Vector2i]:
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

func get_sliding_attack_squares_test(piece: MockPiece, directions: Array) -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	var pos = piece.board_position

	for dir in directions:
		var current = pos + dir
		while is_valid_position(current):
			var target = get_piece_at(current)
			squares.append(current)
			if target != null:
				break
			current = current + dir

	return squares

func get_king_attack_squares_test(piece: MockPiece) -> Array[Vector2i]:
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

# ============ GAME SCENARIO TESTS ============

func test_mate_in_3():
	# Test a "mate in 3" scenario: Queen can reach and capture enemy king in 3 moves
	# Position: Black king at e8 (4,0), White queen at a1 (0,7)
	# Move 1: Qa1-a8 (threaten king)
	# Move 2: Black king moves Ke8-d7
	# Move 3: Qa8-d8+ (but we can also just capture if king stays)
	# Actually in this game, let's test a forced capture scenario
	start_test("Mate in 3 - Queen Hunt")

	clear_board()
	var white_queen = MockPiece.new(PieceType.QUEEN, PieceColor.WHITE, Vector2i(0, 7))  # a1
	var black_king = MockPiece.new(PieceType.KING, PieceColor.BLACK, Vector2i(4, 0))    # e8
	place_piece(white_queen)
	place_piece(black_king)

	# Move 1: Queen to a8 (threatens king's row)
	var queen_moves = get_valid_moves(white_queen)
	var target_a8 = Vector2i(0, 0)
	assert_contains(queen_moves, target_a8, "Queen can move to a8")

	# Simulate the move
	test_board[white_queen.board_position.y][white_queen.board_position.x] = null
	white_queen.board_position = target_a8
	test_board[target_a8.y][target_a8.x] = white_queen

	# Move 2: Black king escapes to d7
	var king_moves = get_valid_moves(black_king)
	var target_d7 = Vector2i(3, 1)
	assert_contains(king_moves, target_d7, "King can escape to d7")

	test_board[black_king.board_position.y][black_king.board_position.x] = null
	black_king.board_position = target_d7
	test_board[target_d7.y][target_d7.x] = black_king

	# Move 3: Queen to d8, threatening king
	queen_moves = get_valid_moves(white_queen)
	var target_d8 = Vector2i(3, 0)
	assert_contains(queen_moves, target_d8, "Queen can move to d8")

	test_board[white_queen.board_position.y][white_queen.board_position.x] = null
	white_queen.board_position = target_d8
	test_board[target_d8.y][target_d8.x] = white_queen

	# Now queen attacks king (king at d7, queen at d8)
	var enemy_targets = get_enemy_targets(white_queen)
	assert_equal(enemy_targets.size(), 1, "Queen has 1 enemy target")
	assert_equal(enemy_targets[0], black_king, "Queen targets the black king")

	# After 3 moves, queen can capture king on next turn
	queen_moves = get_valid_moves(white_queen)
	assert_contains(queen_moves, black_king.board_position, "Queen can capture king (mate!)")

func test_king_capture_win():
	# Test that capturing the king wins the game
	start_test("King Capture Win Condition")

	clear_board()
	var white_queen = MockPiece.new(PieceType.QUEEN, PieceColor.WHITE, Vector2i(3, 1))
	var black_king = MockPiece.new(PieceType.KING, PieceColor.BLACK, Vector2i(4, 0))
	place_piece(white_queen)
	place_piece(black_king)

	var queen_moves = get_valid_moves(white_queen)
	var king_pos = black_king.board_position

	assert_contains(queen_moves, king_pos, "Queen can capture the black king")

	# Simulate capture
	test_board[king_pos.y][king_pos.x] = null  # Remove king
	test_board[white_queen.board_position.y][white_queen.board_position.x] = null
	white_queen.board_position = king_pos
	test_board[king_pos.y][king_pos.x] = white_queen

	# Verify king is gone
	var found_black_king = false
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			var piece = test_board[row][col]
			if piece != null and piece.type == PieceType.KING and piece.color == PieceColor.BLACK:
				found_black_king = true

	assert_true(not found_black_king, "Black king is removed from board (game over)")

func test_king_death_by_shooting():
	# Test that a king can die from accumulated shooting damage
	start_test("King Death by Shooting")

	clear_board()
	# Set up 8 white rooks all attacking the black king
	# King at e4 (4,4), rooks on the same rank and file
	var black_king = MockPiece.new(PieceType.KING, PieceColor.BLACK, Vector2i(4, 4))
	place_piece(black_king)
	assert_equal(black_king.hp, 8, "Black king starts with 8 HP")

	# Place white rooks to attack the king
	var white_rooks = []
	var rook_positions = [
		Vector2i(0, 4),  # a4 - attacks via file
		Vector2i(4, 0),  # e8 - attacks via rank
		Vector2i(7, 4),  # h4 - attacks via file
		Vector2i(4, 7),  # e1 - attacks via rank
	]

	for pos in rook_positions:
		var rook = MockPiece.new(PieceType.ROOK, PieceColor.WHITE, pos)
		place_piece(rook)
		white_rooks.append(rook)

	# Verify each rook can attack the king
	var total_attackers = 0
	for rook in white_rooks:
		var enemies = get_enemy_targets(rook)
		if black_king in enemies:
			total_attackers += 1

	assert_equal(total_attackers, 4, "4 rooks can attack the king")

	# Simulate shooting phase - 4 damage
	black_king.hp -= 4
	assert_equal(black_king.hp, 4, "King has 4 HP after first shooting phase")

	# Next turn, shoot again (assuming king doesn't move)
	black_king.hp -= 4
	assert_equal(black_king.hp, 0, "King has 0 HP after second shooting phase")
	assert_true(black_king.hp <= 0, "King is dead - game over!")
