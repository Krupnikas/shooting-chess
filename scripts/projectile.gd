extends Node2D

signal finished(hit_piece, is_white: bool)

var sprite: Sprite2D = null
var direction: Vector2 = Vector2.ZERO
var base_speed: float = 400.0  # Starting speed
var current_speed: float = 400.0  # Current speed (increases over time)
var acceleration: float = 800.0  # Speed increase per second
var max_speed: float = 1200.0  # Cap to prevent extreme speeds
var is_white: bool = true  # true = white projectile, false = black projectile
var board_bounds: Rect2 = Rect2(0, 0, 1280, 1280)  # 8 * 160

# Targeted mode: projectile travels to specific cell then disappears
var is_targeted: bool = false
var target_position: Vector2 = Vector2.ZERO
var target_board_pos: Vector2i = Vector2i.ZERO

var source_piece = null  # The piece that fired this projectile

# For directional mode: track if we've found a target to stop at
var stopping_at_cell: bool = false
var stop_cell_center: Vector2 = Vector2.ZERO
var stop_piece = null

@onready var outline: Sprite2D = $Outline

func _ready():
	sprite = $Sprite2D
	update_color()

func setup_directional(from_pos: Vector2, dir: Vector2, white: bool, bounds: Rect2):
	position = from_pos
	direction = dir.normalized()
	is_white = white
	board_bounds = bounds
	is_targeted = false
	stopping_at_cell = false
	current_speed = base_speed

func setup_targeted(from_pos: Vector2, target_pos: Vector2, target_cell: Vector2i, white: bool, bounds: Rect2):
	position = from_pos
	target_position = target_pos
	target_board_pos = target_cell
	direction = (target_pos - from_pos).normalized()
	is_white = white
	board_bounds = bounds
	is_targeted = true
	current_speed = base_speed

func set_source(piece):
	source_piece = piece

func update_color():
	if sprite == null:
		return

	# White or black circle based on the piece that shot it
	# Outline is the opposite color for visibility
	if is_white:
		sprite.texture = load("res://assets/pieces/white_circle.png")
		if outline:
			outline.texture = load("res://assets/pieces/black_circle.png")
	else:
		sprite.texture = load("res://assets/pieces/black_circle.png")
		if outline:
			outline.texture = load("res://assets/pieces/white_circle.png")

func _process(delta):
	# Apply acceleration
	current_speed = minf(current_speed + acceleration * delta, max_speed)

	# Move projectile
	position += direction * current_speed * delta

	# Check if out of bounds
	if not board_bounds.has_point(position):
		emit_signal("finished", null, is_white)
		queue_free()
		return

	var board_pos = GameManager.screen_to_board(position)

	# Targeted mode: check if reached center of target cell
	if is_targeted:
		# Check if we've reached (or passed) the target position
		var dist_to_target = position.distance_to(target_position)
		if dist_to_target < 20.0:  # Close enough to center
			var piece = GameManager.get_piece_at(target_board_pos)
			if piece != null and piece != source_piece:
				emit_signal("finished", piece, is_white)
			else:
				emit_signal("finished", null, is_white)
			queue_free()
			return
		return

	# Directional mode: if stopping, check if reached center
	if stopping_at_cell:
		var dist_to_center = position.distance_to(stop_cell_center)
		if dist_to_center < 20.0:
			# Check if piece is still valid (could have been freed)
			if is_instance_valid(stop_piece):
				emit_signal("finished", stop_piece, is_white)
			else:
				emit_signal("finished", null, is_white)
			queue_free()
			return
		return

	# Directional mode: check for collision with pieces
	if GameManager.is_valid_position(board_pos):
		var piece = GameManager.get_piece_at(board_pos)
		if piece != null and piece != source_piece:
			# Found a piece - start moving toward its cell center
			stopping_at_cell = true
			stop_cell_center = GameManager.board_to_screen(board_pos)
			stop_piece = piece
			# Redirect toward the center
			direction = (stop_cell_center - position).normalized()
