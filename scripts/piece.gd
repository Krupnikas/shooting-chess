extends Node2D

@export var type: GameManager.PieceType = GameManager.PieceType.PAWN
@export var color: GameManager.PieceColor = GameManager.PieceColor.WHITE

var board_position: Vector2i = Vector2i.ZERO
var hp: int = 1
var base_hp: int = 1
var blink_tween: Tween = null

@onready var label = $Label
@onready var hp_label = $HPLabel

# Unicode chess symbols
const PIECE_SYMBOLS = {
	GameManager.PieceColor.WHITE: {
		GameManager.PieceType.KING: "♔",
		GameManager.PieceType.QUEEN: "♕",
		GameManager.PieceType.ROOK: "♖",
		GameManager.PieceType.BISHOP: "♗",
		GameManager.PieceType.KNIGHT: "♘",
		GameManager.PieceType.PAWN: "♙"
	},
	GameManager.PieceColor.BLACK: {
		GameManager.PieceType.KING: "♚",
		GameManager.PieceType.QUEEN: "♛",
		GameManager.PieceType.ROOK: "♜",
		GameManager.PieceType.BISHOP: "♝",
		GameManager.PieceType.KNIGHT: "♞",
		GameManager.PieceType.PAWN: "♟"
	}
}

func _ready():
	base_hp = GameManager.BASE_HP[type]
	hp = base_hp
	update_display()

func update_display():
	label.text = PIECE_SYMBOLS[color][type]

	# Set color tint for visibility
	if color == GameManager.PieceColor.WHITE:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
	else:
		label.add_theme_color_override("font_color", Color.BLACK)
		label.add_theme_color_override("font_outline_color", Color.WHITE)

	update_hp_display()

func update_hp_display():
	hp_label.text = str(hp)

	# Color based on HP vs base
	if hp > base_hp:
		hp_label.add_theme_color_override("font_color", Color.GREEN)
	elif hp < base_hp:
		hp_label.add_theme_color_override("font_color", Color.RED)
	else:
		hp_label.add_theme_color_override("font_color", Color.WHITE)

func take_damage(amount: int):
	hp -= amount
	update_hp_display()
	blink(Color.RED)

func heal(amount: int):
	hp += amount
	update_hp_display()
	blink(Color.GREEN)

func blink(blink_color: Color):
	# Kill any existing blink tween to avoid color staying stuck
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	blink_tween = create_tween()
	blink_tween.tween_property(label, "modulate", blink_color, 0.15)
	blink_tween.tween_property(label, "modulate", Color.WHITE, 0.15)

func reset_hp():
	hp = base_hp
	update_hp_display()

func die():
	GameManager.remove_piece_at(board_position)
	queue_free()
