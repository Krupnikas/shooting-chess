extends Control

@onready var turn_label = $TurnLabel
@onready var phase_label = $PhaseLabel
@onready var time_label = $TimeLabel

func _ready():
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_over.connect(_on_game_over)
	update_display()

var _time_update_counter: int = 0

func _process(_delta):
	# Update timer every 30 frames (~0.5s)
	_time_update_counter += 1
	if _time_update_counter >= 30:
		_time_update_counter = 0
		if time_label:
			time_label.text = str(int(Time.get_ticks_msec() / 1000))

func _on_turn_changed(_player):
	update_display()

func _on_phase_changed(_phase):
	update_display()

func _on_game_over(winner):
	var winner_name = "White" if winner == GameManager.PieceColor.WHITE else "Black"
	turn_label.text = winner_name + " Wins!"
	turn_label.modulate = Color.GOLD  # Use modulate instead of add_theme_color_override
	phase_label.text = "Game Over"

func update_display():
	var player_name = "White" if GameManager.current_player == GameManager.PieceColor.WHITE else "Black"
	turn_label.text = player_name + "'s Turn"

	var phase_name = ""
	var phase_color = Color.WHITE
	match GameManager.game_phase:
		GameManager.GamePhase.REINFORCE:
			phase_name = "Reinforce Phase"
			phase_color = Color(0.5, 1.0, 0.5)  # Light green
		GameManager.GamePhase.SHOOTING:
			phase_name = "Shooting Phase"
			phase_color = Color(1.0, 0.5, 0.5)  # Light red
		GameManager.GamePhase.MOVING:
			phase_name = "Move Phase"
			phase_color = Color(0.7, 0.8, 1.0)  # Light blue
		GameManager.GamePhase.GAME_OVER:
			phase_name = "Game Over"
			phase_color = Color.GOLD

	phase_label.text = phase_name
	phase_label.modulate = phase_color
