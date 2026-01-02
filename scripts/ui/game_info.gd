extends Control

@onready var turn_label = $TurnLabel
@onready var phase_label = $PhaseLabel

func _ready():
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)
	update_display()

func _on_turn_changed(_player):
	update_display()

func _on_phase_changed(_phase):
	update_display()

func _on_game_over(winner):
	var winner_name = "White" if winner == GameManager.PieceColor.WHITE else "Black"
	turn_label.text = winner_name + " Wins!"
	turn_label.add_theme_color_override("font_color", Color.GOLD)
	phase_label.text = "Game Over"

func update_display():
	var player_name = "White" if GameManager.current_player == GameManager.PieceColor.WHITE else "Black"
	turn_label.text = player_name + "'s Turn"

	var phase_name = ""
	var phase_color = Color.WHITE
	match GameManager.game_phase:
		GameManager.GamePhase.REINFORCE:
			phase_name = "Reinforce Phase"
			phase_color = Color(0.2, 1.0, 0.2)  # Green
		GameManager.GamePhase.SHOOTING:
			phase_name = "Shooting Phase"
			phase_color = Color(1.0, 0.2, 0.2)  # Red
		GameManager.GamePhase.MOVING:
			phase_name = "Move Phase"
			phase_color = Color(0.5, 0.7, 1.0)  # Blue
		GameManager.GamePhase.GAME_OVER:
			phase_name = "Game Over"
			phase_color = Color.GOLD

	phase_label.text = phase_name
	phase_label.add_theme_color_override("font_color", phase_color)
