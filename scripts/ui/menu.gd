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
@onready var hp_toggle = $SettingsPopup/PanelContainer/VBoxContainer/OptionsContainer/HPToggle
@onready var ai_difficulty_slider = $SettingsPopup/PanelContainer/VBoxContainer/OptionsContainer/AIDifficultyContainer/AIDifficultySlider
@onready var ai_difficulty_label = $SettingsPopup/PanelContainer/VBoxContainer/OptionsContainer/AIDifficultyContainer/AIDifficultyLabel
@onready var close_button = $SettingsPopup/PanelContainer/VBoxContainer/CloseButton
@onready var rules_close_button = $RulesPopup/PanelContainer/VBoxContainer/RulesCloseButton
@onready var play_white_button = $ColorPopup/PanelContainer/VBoxContainer/ButtonContainer/PlayWhiteButton
@onready var play_black_button = $ColorPopup/PanelContainer/VBoxContainer/ButtonContainer/PlayBlackButton
@onready var color_cancel_button = $ColorPopup/PanelContainer/VBoxContainer/CancelButton

var _current_scale: float = 1.0

func _ready():
	play_ai_button.pressed.connect(_on_play_ai_pressed)
	play_local_button.pressed.connect(_on_play_local_pressed)
	play_online_button.pressed.connect(_on_play_online_pressed)
	rules_button.pressed.connect(_on_rules_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_button.pressed.connect(_on_close_settings_pressed)
	rules_close_button.pressed.connect(_on_close_rules_pressed)
	hp_toggle.toggled.connect(_on_hp_toggle_changed)
	ai_difficulty_slider.value_changed.connect(_on_difficulty_changed)

	# Color selection buttons
	play_white_button.pressed.connect(_on_play_white_pressed)
	play_black_button.pressed.connect(_on_play_black_pressed)
	color_cancel_button.pressed.connect(_on_color_cancel_pressed)

	# Enable online button
	play_online_button.disabled = false

	# Sync HP toggle with current state
	hp_toggle.button_pressed = GameManager.show_hp_numbers

	# Sync AI difficulty slider
	ai_difficulty_slider.value = AIPlayer.difficulty
	_update_difficulty_label(AIPlayer.difficulty)

	# Scale UI for mobile/small screens
	_apply_responsive_scaling()
	get_tree().root.size_changed.connect(_apply_responsive_scaling)

func _apply_responsive_scaling():
	var viewport_size = get_viewport().get_visible_rect().size
	var min_dimension = min(viewport_size.x, viewport_size.y)

	# Scale up for small screens (mobile)
	# Base design is for ~1600px viewport
	if min_dimension < 800:
		_current_scale = 5.0  # Very small screens (phones)
	elif min_dimension < 1200:
		_current_scale = 3.0  # Medium screens (tablets)
	else:
		_current_scale = 1.0  # Desktop

	center_panel.scale = Vector2(_current_scale, _current_scale)

	# Center the scaled panel properly
	center_panel.pivot_offset = center_panel.size / 2

func _on_play_ai_pressed():
	# Show color selection popup
	_show_scaled_popup(color_popup)

func _on_play_white_pressed():
	color_popup.hide()
	# Player is white, AI controls black
	AIPlayer.enable_ai(GameManager.PieceColor.BLACK)
	GameManager.player_color = GameManager.PieceColor.WHITE
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_play_black_pressed():
	color_popup.hide()
	# Player is black, AI controls white
	AIPlayer.enable_ai(GameManager.PieceColor.WHITE)
	GameManager.player_color = GameManager.PieceColor.BLACK
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_color_cancel_pressed():
	color_popup.hide()

func _on_play_local_pressed():
	# Disable AI for local play
	AIPlayer.disable_ai()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_play_online_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/online_lobby.tscn")

func _on_rules_pressed():
	_show_scaled_popup(rules_popup)

func _on_close_rules_pressed():
	rules_popup.hide()

func _on_settings_pressed():
	_show_scaled_popup(settings_popup)

func _show_scaled_popup(popup: PopupPanel):
	var screen_size = get_viewport().get_visible_rect().size

	# Scale popup for mobile
	var popup_scale = _current_scale
	popup.content_scale_factor = popup_scale

	# Calculate scaled size and center
	var scaled_size = popup.size * popup_scale
	var pos_x = int((screen_size.x - scaled_size.x) / 2)
	var pos_y = int((screen_size.y - scaled_size.y) / 2)

	# Ensure popup stays on screen
	pos_x = max(10, pos_x)
	pos_y = max(10, pos_y)

	popup.position = Vector2i(pos_x, pos_y)
	popup.size = Vector2i(scaled_size.x, scaled_size.y)
	popup.popup()

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
