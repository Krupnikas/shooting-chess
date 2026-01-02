extends Node2D

signal finished(hit_piece, is_white: bool)

var sprite: Sprite2D = null
var direction: Vector2 = Vector2.ZERO
var speed: float = 600.0
var is_white: bool = true  # White or black projectile
var board_bounds: Rect2 = Rect2(0, 0, 1280, 1280)  # 8 * 160

# Targeted mode: projectile travels to specific cell then disappears
var is_targeted: bool = false
var target_position: Vector2 = Vector2.ZERO
var target_board_pos: Vector2i = Vector2i.ZERO

var source_piece = null  # The piece that fired this projectile

# Preload textures
var white_texture = preload("res://assets/pieces/white_circle.png")
var black_texture = preload("res://assets/pieces/black_circle.png")

func _ready():
	sprite = $Sprite2D
	update_color()

func setup_directional(from_pos: Vector2, dir: Vector2, white: bool, bounds: Rect2):
	position = from_pos
	direction = dir.normalized()
	is_white = white
	board_bounds = bounds
	is_targeted = false

func setup_targeted(from_pos: Vector2, target_pos: Vector2, target_cell: Vector2i, white: bool, bounds: Rect2):
	position = from_pos
	target_position = target_pos
	target_board_pos = target_cell
	direction = (target_pos - from_pos).normalized()
	is_white = white
	board_bounds = bounds
	is_targeted = true

func set_source(piece):
	source_piece = piece

func update_color():
	if sprite == null:
		return

	# Use preloaded textures - no add_theme_color_override!
	if is_white:
		sprite.texture = white_texture
	else:
		sprite.texture = black_texture

func _process(delta):
	position += direction * speed * delta

	# Check if out of bounds
	if not board_bounds.has_point(position):
		emit_signal("finished", null, is_white)
		queue_free()
		return

	var board_pos = GameManager.screen_to_board(position)

	# Targeted mode: check if reached target cell
	if is_targeted:
		if board_pos == target_board_pos:
			var piece = GameManager.get_piece_at(board_pos)
			if piece != null and piece != source_piece:
				emit_signal("finished", piece, is_white)
			else:
				emit_signal("finished", null, is_white)
			queue_free()
			return
		return

	# Directional mode: check for collision with pieces
	if GameManager.is_valid_position(board_pos):
		var piece = GameManager.get_piece_at(board_pos)
		if piece != null and piece != source_piece:
			emit_signal("finished", piece, is_white)
			queue_free()
			return
