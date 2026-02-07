extends CanvasLayer

@onready var title_label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var winner_label = $CenterContainer/Panel/VBoxContainer/WinnerLabel
@onready var play_again_button = $CenterContainer/Panel/VBoxContainer/ButtonContainer/PlayAgainButton
@onready var menu_button = $CenterContainer/Panel/VBoxContainer/ButtonContainer/MenuButton

func _ready():
	hide()
	play_again_button.pressed.connect(_on_play_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	# Connect to game over signal
	if GameManager.has_signal("game_over"):
		GameManager.game_over.connect(_on_game_over)

	_update_translations()

func _update_translations():
	title_label.text = tr("GAME_OVER")
	play_again_button.text = tr("BTN_PLAY_AGAIN")
	menu_button.text = tr("BTN_MENU")

func show_game_over(winner_color: GameManager.PieceColor):
	if winner_color == GameManager.PieceColor.WHITE:
		winner_label.text = tr("WHITE_WINS")
		winner_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
	else:
		winner_label.text = tr("BLACK_WINS")
		winner_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35, 1))

	show()

	# Animate in
	var panel = $CenterContainer/Panel
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)

func _on_game_over(winner_color: GameManager.PieceColor):
	show_game_over(winner_color)

func _on_play_again_pressed():
	hide()
	# For online games, preserve board orientation based on player's color
	var is_online = NetworkManager.is_online_game()
	var local_color = NetworkManager.get_local_color() if is_online else GameManager.PieceColor.WHITE

	# Reset game
	GameManager.reset_game()

	# Restore board flip for online games (player's color doesn't change)
	if is_online:
		GameManager.is_board_flipped = local_color == GameManager.PieceColor.BLACK

	get_tree().reload_current_scene()

func _on_menu_pressed():
	hide()
	AIPlayer.disable_ai()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
