extends Control

@onready var center_panel = $CenterPanel
@onready var play_ai_button = $CenterPanel/VBoxContainer/ButtonContainer/PlayAIButton
@onready var play_local_button = $CenterPanel/VBoxContainer/ButtonContainer/PlayLocalButton
@onready var play_online_button = $CenterPanel/VBoxContainer/ButtonContainer/PlayOnlineButton
@onready var rules_button = $CenterPanel/VBoxContainer/ButtonContainer/RulesButton
@onready var settings_button = $CenterPanel/VBoxContainer/ButtonContainer/SettingsButton
@onready var exit_button = $CenterPanel/VBoxContainer/ButtonContainer/ExitButton
@onready var settings_popup = $SettingsPopup
@onready var rules_popup = $RulesPopup
@onready var color_popup = $ColorPopup
@onready var close_button = $SettingsPopup/PanelContainer/VBoxContainer/CloseButton
@onready var rules_close_button = $RulesPopup/PanelContainer/VBoxContainer/RulesCloseButton
@onready var play_white_button = $ColorPopup/PanelContainer/VBoxContainer/ButtonContainer/PlayWhiteButton
@onready var play_black_button = $ColorPopup/PanelContainer/VBoxContainer/ButtonContainer/PlayBlackButton
@onready var color_cancel_button = $ColorPopup/PanelContainer/VBoxContainer/CancelButton
@onready var ai_difficulty_slider = $ColorPopup/PanelContainer/VBoxContainer/AIDifficultyContainer/AIDifficultySlider
@onready var ai_difficulty_label = $ColorPopup/PanelContainer/VBoxContainer/AIDifficultyContainer/AIDifficultyLabel

func _ready():
	play_ai_button.pressed.connect(_on_play_ai_pressed)
	play_local_button.pressed.connect(_on_play_local_pressed)
	play_online_button.pressed.connect(_on_play_online_pressed)
	rules_button.pressed.connect(_on_rules_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_button.pressed.connect(_on_close_settings_pressed)
	rules_close_button.pressed.connect(_on_close_rules_pressed)
	ai_difficulty_slider.value_changed.connect(_on_difficulty_changed)

	# Color selection buttons
	play_white_button.pressed.connect(_on_play_white_pressed)
	play_black_button.pressed.connect(_on_play_black_pressed)
	color_cancel_button.pressed.connect(_on_color_cancel_pressed)

	# Enable online button
	play_online_button.disabled = false

	# Sync AI difficulty slider
	ai_difficulty_slider.value = AIPlayer.difficulty
	_update_difficulty_label(AIPlayer.difficulty)

func _on_play_ai_pressed():
	# Show color selection popup
	_show_centered_popup(color_popup)

func _on_play_white_pressed():
	color_popup.hide()
	# Player is white, AI controls black
	AIPlayer.enable_ai(GameManager.PieceColor.BLACK)
	GameManager.player_color = GameManager.PieceColor.WHITE
	GameManager.is_board_flipped = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_play_black_pressed():
	color_popup.hide()
	# Player is black, AI controls white
	AIPlayer.enable_ai(GameManager.PieceColor.WHITE)
	GameManager.player_color = GameManager.PieceColor.BLACK
	GameManager.is_board_flipped = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_color_cancel_pressed():
	color_popup.hide()

func _on_play_local_pressed():
	# Disable AI for local play
	AIPlayer.disable_ai()
	GameManager.is_board_flipped = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_play_online_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/online_lobby.tscn")

func _on_rules_pressed():
	_show_centered_popup(rules_popup)

func _on_close_rules_pressed():
	rules_popup.hide()

func _on_settings_pressed():
	_show_centered_popup(settings_popup)

func _show_centered_popup(popup: PopupPanel):
	var screen_size = get_viewport().get_visible_rect().size
	var pos_x = int((screen_size.x - popup.size.x) / 2)
	var pos_y = int((screen_size.y - popup.size.y) / 2)
	popup.position = Vector2i(max(10, pos_x), max(10, pos_y))
	popup.popup()

func _on_exit_pressed():
	get_tree().quit()

func _on_close_settings_pressed():
	settings_popup.hide()

func _on_difficulty_changed(value: float):
	var level = int(value)
	AIPlayer.set_difficulty(level)
	_update_difficulty_label(level)

func _update_difficulty_label(level: int):
	ai_difficulty_label.text = "AI Difficulty: " + AIPlayer.get_difficulty_name() + " (" + str(level) + ")"
