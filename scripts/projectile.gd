extends Node2D

signal finished(hit_piece, is_heal: bool)

var sprite: Sprite2D = null
var direction: Vector2 = Vector2.ZERO
var speed: float = 600.0
var is_heal: bool = true  # true = green heal, false = red damage
var board_bounds: Rect2 = Rect2(0, 0, 1280, 1280)  # 8 * 160

# Targeted mode: projectile travels to specific cell then disappears
var is_targeted: bool = false
var target_position: Vector2 = Vector2.ZERO
var target_board_pos: Vector2i = Vector2i.ZERO

var source_piece = null  # The piece that fired this projectile

func _ready():
	sprite = $Sprite2D
	update_color()

func setup_directional(from_pos: Vector2, dir: Vector2, heal: bool, bounds: Rect2):
	position = from_pos
	direction = dir.normalized()
	is_heal = heal
	board_bounds = bounds
	is_targeted = false

func setup_targeted(from_pos: Vector2, target_pos: Vector2, target_cell: Vector2i, heal: bool, bounds: Rect2):
	position = from_pos
	target_position = target_pos
	target_board_pos = target_cell
	direction = (target_pos - from_pos).normalized()
	is_heal = heal
	board_bounds = bounds
	is_targeted = true

func set_source(piece):
	source_piece = piece

func update_color():
	if sprite == null:
		return

	# Green for heal, red for damage - load at runtime since PNG may not be imported yet
	if is_heal:
		sprite.texture = load("res://assets/pieces/green_circle.png")
	else:
		sprite.texture = load("res://assets/pieces/red_circle.png")

func _process(delta):
	position += direction * speed * delta

	# Check if out of bounds
	if not board_bounds.has_point(position):
		emit_signal("finished", null, is_heal)
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
				emit_signal("finished", piece, is_heal)
			else:
				emit_signal("finished", null, is_heal)
			queue_free()
			return
		return

	# Directional mode: check for collision with pieces at cell center
	if GameManager.is_valid_position(board_pos):
		var piece = GameManager.get_piece_at(board_pos)
		if piece != null and piece != source_piece:
			# Check if we're close to the center of the cell
			var cell_center = GameManager.board_to_screen(board_pos)
			if position.distance_to(cell_center) < 30.0:
				emit_signal("finished", piece, is_heal)
				queue_free()
				return
