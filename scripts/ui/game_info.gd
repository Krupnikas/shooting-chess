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
	if winner == GameManager.PieceColor.WHITE:
		turn_label.text = tr("WHITE_WINS")
	else:
		turn_label.text = tr("BLACK_WINS")
	turn_label.modulate = Color.GOLD
	phase_label.text = tr("PHASE_GAME_OVER")

func update_display():
	if GameManager.current_player == GameManager.PieceColor.WHITE:
		turn_label.text = tr("TURN_WHITE")
	else:
		turn_label.text = tr("TURN_BLACK")

	var phase_name = ""
	var phase_color = Color.WHITE
	match GameManager.game_phase:
		GameManager.GamePhase.MOVING:
			phase_name = tr("PHASE_MOVE")
			phase_color = Color(0.7, 0.8, 1.0)  # Light blue
		GameManager.GamePhase.SHOOTING:
			phase_name = tr("PHASE_SHOOTING")
			phase_color = Color(1.0, 0.5, 0.5)  # Light red
		GameManager.GamePhase.GAME_OVER:
			phase_name = tr("PHASE_GAME_OVER")
			phase_color = Color.GOLD

	phase_label.text = phase_name
	phase_label.modulate = phase_color
