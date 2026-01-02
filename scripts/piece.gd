extends Node2D

@export var type: GameManager.PieceType = GameManager.PieceType.PAWN
@export var color: GameManager.PieceColor = GameManager.PieceColor.WHITE

var board_position: Vector2i = Vector2i.ZERO
var hp: int = 1
var base_hp: int = 1
var blink_tween: Tween = null

@onready var sprite = $Sprite
@onready var hp_label = $HPLabel
@onready var blink_overlay = $BlinkOverlay

# Texture paths for each piece type
const PIECE_TEXTURES = {
	GameManager.PieceColor.WHITE: {
		GameManager.PieceType.KING: "res://assets/pieces/white_king.png",
		GameManager.PieceType.QUEEN: "res://assets/pieces/white_queen.png",
		GameManager.PieceType.ROOK: "res://assets/pieces/white_rook.png",
		GameManager.PieceType.BISHOP: "res://assets/pieces/white_bishop.png",
		GameManager.PieceType.KNIGHT: "res://assets/pieces/white_knight.png",
		GameManager.PieceType.PAWN: "res://assets/pieces/white_pawn.png"
	},
	GameManager.PieceColor.BLACK: {
		GameManager.PieceType.KING: "res://assets/pieces/black_king.png",
		GameManager.PieceType.QUEEN: "res://assets/pieces/black_queen.png",
		GameManager.PieceType.ROOK: "res://assets/pieces/black_rook.png",
		GameManager.PieceType.BISHOP: "res://assets/pieces/black_bishop.png",
		GameManager.PieceType.KNIGHT: "res://assets/pieces/black_knight.png",
		GameManager.PieceType.PAWN: "res://assets/pieces/black_pawn.png"
	}
}

func _ready():
	base_hp = GameManager.BASE_HP[type]
	hp = base_hp
	update_display()

func update_display():
	# Load the appropriate texture for this piece
	var texture_path = PIECE_TEXTURES[color][type]
	sprite.texture = load(texture_path)
	update_hp_display()

func update_hp_display():
	hp_label.text = str(hp)
	# Use modulate for HP color - nicer colors
	if hp > base_hp:
		hp_label.modulate = Color(0.4, 1.0, 0.4)  # Soft green
	elif hp < base_hp:
		hp_label.modulate = Color(1.0, 0.4, 0.4)  # Soft red
	else:
		hp_label.modulate = Color.WHITE

func take_damage(amount: int):
	hp -= amount
	update_hp_display()
	blink(Color(1.0, 0.3, 0.3))  # Soft red blink

func heal(amount: int):
	hp += amount
	update_hp_display()
	blink(Color(0.3, 1.0, 0.3))  # Soft green blink

func blink(blink_color: Color):
	# Kill any existing blink tween to avoid color staying stuck
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		# Reset overlay to transparent immediately
		blink_overlay.color = Color(0, 0, 0, 0)

	# Use overlay with semi-transparent blink color
	var overlay_color = Color(blink_color.r, blink_color.g, blink_color.b, 0.5)
	blink_tween = create_tween()
	blink_tween.tween_property(blink_overlay, "color", overlay_color, 0.5)
	blink_tween.tween_property(blink_overlay, "color", Color(0, 0, 0, 0), 0.5)

func reset_hp():
	hp = base_hp
	update_hp_display()

func die():
	GameManager.remove_piece_at(board_position)
	queue_free()
