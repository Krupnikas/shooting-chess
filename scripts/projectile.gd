extends Node2D

signal finished(hit_piece)

var sprite: Label = null
var direction: Vector2 = Vector2.ZERO
var speed: float = 600.0
var is_reinforce: bool = true  # true = green, false = red
var board_bounds: Rect2 = Rect2(0, 0, 1280, 1280)  # 8 * 160

# Targeted mode: projectile travels to specific cell then disappears
var is_targeted: bool = false
var target_position: Vector2 = Vector2.ZERO
var target_board_pos: Vector2i = Vector2i.ZERO

func _ready():
	sprite = $Sprite2D
	update_color()

func setup_directional(from_pos: Vector2, dir: Vector2, reinforce: bool, bounds: Rect2):
	position = from_pos
	direction = dir.normalized()
	is_reinforce = reinforce
	board_bounds = bounds
	is_targeted = false

func setup_targeted(from_pos: Vector2, target_pos: Vector2, target_cell: Vector2i, reinforce: bool, bounds: Rect2):
	position = from_pos
	target_position = target_pos
	target_board_pos = target_cell
	direction = (target_pos - from_pos).normalized()
	is_reinforce = reinforce
	board_bounds = bounds
	is_targeted = true

# Legacy setup for compatibility during transition
func setup(from_pos: Vector2, to_pos: Vector2, reinforce: bool):
	position = from_pos
	direction = (to_pos - from_pos).normalized()
	is_reinforce = reinforce
	is_targeted = false

func update_color():
	if sprite == null:
		return

	if is_reinforce:
		sprite.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Green
	else:
		sprite.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red

var source_piece = null  # The piece that fired this projectile

func set_source(piece):
	source_piece = piece

func _process(delta):
	position += direction * speed * delta

	# Check if out of bounds
	if not board_bounds.has_point(position):
		emit_signal("finished", null)
		queue_free()
		return

	var board_pos = GameManager.screen_to_board(position)

	# Targeted mode: check if reached target cell
	if is_targeted:
		if board_pos == target_board_pos:
			var piece = GameManager.get_piece_at(board_pos)
			if piece != null and piece != source_piece:
				if is_valid_target(piece):
					emit_signal("finished", piece)
				else:
					emit_signal("finished", null)
			else:
				emit_signal("finished", null)
			queue_free()
			return
		# In targeted mode, also check for collision along the way
		# (mainly relevant for shooting through friendly pieces)
		if not is_reinforce:
			var piece = GameManager.get_piece_at(board_pos)
			if piece != null and piece != source_piece:
				if source_piece != null and piece.color == source_piece.color:
					emit_signal("finished", null)  # Stopped by friendly
					queue_free()
					return
		return

	# Directional mode: check for collision with pieces
	if GameManager.is_valid_position(board_pos):
		var piece = GameManager.get_piece_at(board_pos)
		if piece != null and piece != source_piece:
			if source_piece == null:
				emit_signal("finished", null)
				queue_free()
				return

			if is_reinforce:
				# Reinforce: hits friendly pieces only, passes through enemies
				if piece.color == source_piece.color:
					emit_signal("finished", piece)  # Heal friendly
					queue_free()
					return
			else:
				# Shooting: stops on ANY piece
				if piece.color != source_piece.color:
					emit_signal("finished", piece)  # Damage enemy
				else:
					emit_signal("finished", null)  # Stopped by friendly
				queue_free()
				return

func is_valid_target(piece) -> bool:
	if source_piece == null:
		return false
	if is_reinforce:
		return piece.color == source_piece.color
	else:
		return piece.color != source_piece.color
