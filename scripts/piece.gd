extends Node2D

@export var type: GameManager.PieceType = GameManager.PieceType.PAWN
@export var color: GameManager.PieceColor = GameManager.PieceColor.WHITE

var board_position: Vector2i = Vector2i.ZERO
var hp: int = 1
var base_hp: int = 1
var has_moved: bool = false  # Track if piece has moved (for castling)
var blink_tween: Tween = null
var move_tween: Tween = null

signal move_completed

const MOVE_DURATION = 0.2  # Duration of move animation in seconds

@onready var sprite = $Sprite
@onready var hp_label = $HPLabel
@onready var blink_overlay = $BlinkOverlay
@onready var health_bar = $HealthBar

const HEALTH_BAR_SEGMENTS = 4
const SEGMENT_WIDTH = 18
const SEGMENT_HEIGHT = 18
# Layer colors: green (base) -> blue -> gold -> purple -> cyan -> red...
const LAYER_COLORS = [
	Color(0.3, 0.85, 0.3),  # Green - layer 0 (1-4)
	Color(0.3, 0.5, 0.95),  # Blue - layer 1 (5-8)
	Color(0.95, 0.75, 0.2), # Gold - layer 2 (9-12)
	Color(0.7, 0.3, 0.9),   # Purple - layer 3 (13-16)
	Color(0.2, 0.85, 0.85), # Cyan - layer 4 (17-20)
	Color(0.9, 0.3, 0.3),   # Red - layer 5 (21-24)
]

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
	create_health_bar_segments()
	update_display()
	hp_label.visible = false  # HP numbers are never shown

	# Rotate black pieces 180 degrees in offline 1v1 mode only (not AI or online)
	if color == GameManager.PieceColor.BLACK and not NetworkManager.is_online_game() and not AIPlayer.is_enabled:
		sprite.rotation_degrees = 180

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
	update_health_bar()

func create_health_bar_segments():
	# Clear existing segments
	for child in health_bar.get_children():
		child.queue_free()

	# Create 8 segments
	for i in range(HEALTH_BAR_SEGMENTS):
		var segment = ColorRect.new()
		segment.custom_minimum_size = Vector2(SEGMENT_WIDTH, SEGMENT_HEIGHT)
		segment.color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray background
		health_bar.add_child(segment)

func update_health_bar():
	if health_bar == null:
		return

	var segments = health_bar.get_children()
	if segments.size() != HEALTH_BAR_SEGMENTS:
		return  # Must have exactly 4 segments

	# Calculate which layer we're on and how many segments are filled
	var current_hp = max(0, hp)
	var full_layers = current_hp / HEALTH_BAR_SEGMENTS  # How many complete layers
	var partial_fill = current_hp % HEALTH_BAR_SEGMENTS  # Segments in current layer

	# Determine the color for each segment
	for i in range(HEALTH_BAR_SEGMENTS):
		var segment = segments[i]
		var segment_num = i + 1  # 1-indexed for easier logic

		if current_hp <= 0:
			# No HP - all segments dark
			segment.color = Color(0.2, 0.2, 0.2, 0.8)
		elif full_layers == 0:
			# First layer (1-8 HP): red fill
			if segment_num <= partial_fill:
				segment.color = LAYER_COLORS[0]
			else:
				segment.color = Color(0.2, 0.2, 0.2, 0.8)
		else:
			# We have at least one full layer
			var base_layer = (full_layers - 1) % LAYER_COLORS.size()
			var overflow_layer = full_layers % LAYER_COLORS.size()

			if partial_fill == 0:
				# Exactly full layers (8, 16, 24, etc.) - show full bar of that layer color
				segment.color = LAYER_COLORS[base_layer]
			else:
				# Partial overflow - base color fills all, overflow color on top
				if segment_num <= partial_fill:
					segment.color = LAYER_COLORS[overflow_layer]
				else:
					segment.color = LAYER_COLORS[base_layer]

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

func move_to(target_position: Vector2):
	# Kill any existing move tween
	if move_tween and move_tween.is_valid():
		move_tween.kill()

	# Create smooth movement animation
	move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.set_trans(Tween.TRANS_QUAD)
	move_tween.tween_property(self, "position", target_position, MOVE_DURATION)
	move_tween.tween_callback(_on_move_completed)

func _on_move_completed():
	emit_signal("move_completed")

func die():
	GameManager.remove_piece_at(board_position)
	queue_free()
