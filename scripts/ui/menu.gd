extends Control

@onready var play_ai_button = $CenterPanel/VBoxContainer/ButtonContainer/PlayAIButton
@onready var play_local_button = $CenterPanel/VBoxContainer/ButtonContainer/PlayLocalButton
@onready var rules_button = $CenterPanel/VBoxContainer/ButtonContainer/RulesButton
@onready var settings_button = $CenterPanel/VBoxContainer/ButtonContainer/SettingsButton
@onready var exit_button = $CenterPanel/VBoxContainer/ButtonContainer/ExitButton
@onready var settings_popup = $SettingsPopup
@onready var rules_popup = $RulesPopup
@onready var hp_toggle = $SettingsPopup/PanelContainer/VBoxContainer/OptionsContainer/HPToggle
@onready var ai_difficulty_slider = $SettingsPopup/PanelContainer/VBoxContainer/OptionsContainer/AIDifficultyContainer/AIDifficultySlider
@onready var ai_difficulty_label = $SettingsPopup/PanelContainer/VBoxContainer/OptionsContainer/AIDifficultyContainer/AIDifficultyLabel
@onready var close_button = $SettingsPopup/PanelContainer/VBoxContainer/CloseButton
@onready var rules_close_button = $RulesPopup/PanelContainer/VBoxContainer/RulesCloseButton

func _ready():
	play_ai_button.pressed.connect(_on_play_ai_pressed)
	play_local_button.pressed.connect(_on_play_local_pressed)
	rules_button.pressed.connect(_on_rules_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_button.pressed.connect(_on_close_settings_pressed)
	rules_close_button.pressed.connect(_on_close_rules_pressed)
	hp_toggle.toggled.connect(_on_hp_toggle_changed)
	ai_difficulty_slider.value_changed.connect(_on_difficulty_changed)

	# Sync HP toggle with current state
	hp_toggle.button_pressed = GameManager.show_hp_numbers

	# Sync AI difficulty slider
	ai_difficulty_slider.value = AIPlayer.difficulty
	_update_difficulty_label(AIPlayer.difficulty)

func _on_play_ai_pressed():
	# Enable AI for black pieces
	AIPlayer.enable_ai(GameManager.PieceColor.BLACK)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_play_local_pressed():
	# Disable AI for local play
	AIPlayer.disable_ai()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_rules_pressed():
	# Center the popup on screen
	var screen_size = get_viewport().get_visible_rect().size
	var popup_size = rules_popup.size
	rules_popup.position = Vector2i((screen_size.x - popup_size.x) / 2, (screen_size.y - popup_size.y) / 2)
	rules_popup.popup()

func _on_close_rules_pressed():
	rules_popup.hide()

func _on_settings_pressed():
	# Center the popup on screen
	var screen_size = get_viewport().get_visible_rect().size
	var popup_size = settings_popup.size
	settings_popup.position = Vector2i((screen_size.x - popup_size.x) / 2, (screen_size.y - popup_size.y) / 2)
	settings_popup.popup()

func _on_exit_pressed():
	get_tree().quit()

func _on_close_settings_pressed():
	settings_popup.hide()

func _on_hp_toggle_changed(pressed: bool):
	GameManager.show_hp_numbers = pressed
	GameManager.emit_signal("hp_display_toggled", pressed)

func _on_difficulty_changed(value: float):
	var level = int(value)
	AIPlayer.set_difficulty(level)
	_update_difficulty_label(level)

func _update_difficulty_label(level: int):
	ai_difficulty_label.text = "AI Difficulty: " + AIPlayer.get_difficulty_name()
