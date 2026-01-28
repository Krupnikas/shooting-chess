extends Control

@onready var center_panel = $CenterPanel
@onready var play_ai_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/PlayAIButton
@onready var play_local_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/PlayLocalButton
@onready var play_online_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/PlayOnlineButton
@onready var rules_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/RulesButton
@onready var tutorial_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/TutorialButton
@onready var settings_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/SettingsButton
@onready var exit_button = $CenterPanel/ScrollContainer/VBoxContainer/ButtonContainer/ExitButton
@onready var rules_popup = $RulesPopup
@onready var settings_popup = $SettingsPopup
@onready var color_popup = $ColorPopup
@onready var rules_close_button = $RulesPopup/PanelContainer/VBoxContainer/RulesCloseButton
@onready var play_white_button = $ColorPopup/PanelContainer/VBoxContainer/ButtonContainer/PlayWhiteButton
@onready var play_black_button = $ColorPopup/PanelContainer/VBoxContainer/ButtonContainer/PlayBlackButton
@onready var color_cancel_button = $ColorPopup/PanelContainer/VBoxContainer/CancelButton
@onready var ai_difficulty_slider = $ColorPopup/PanelContainer/VBoxContainer/AIDifficultyContainer/AIDifficultySlider
@onready var ai_difficulty_label = $ColorPopup/PanelContainer/VBoxContainer/AIDifficultyContainer/AIDifficultyLabel

# Settings popup
@onready var settings_title = $SettingsPopup/PanelContainer/VBoxContainer/TitleContainer/Title
@onready var language_label = $SettingsPopup/PanelContainer/VBoxContainer/LanguageContainer/LanguageLabel
@onready var language_option = $SettingsPopup/PanelContainer/VBoxContainer/LanguageContainer/LanguageOption
@onready var settings_close_button = $SettingsPopup/PanelContainer/VBoxContainer/CloseButton

# Title elements
@onready var title_label = $CenterPanel/ScrollContainer/VBoxContainer/TitleContainer/Title
@onready var subtitle_label = $CenterPanel/ScrollContainer/VBoxContainer/TitleContainer/Subtitle

# Popup elements
@onready var rules_title = $RulesPopup/PanelContainer/VBoxContainer/Header/RulesTitle
@onready var rules_text = $RulesPopup/PanelContainer/VBoxContainer/ScrollContainer/RulesText
@onready var color_popup_title = $ColorPopup/PanelContainer/VBoxContainer/Title
@onready var color_popup_subtitle = $ColorPopup/PanelContainer/VBoxContainer/Subtitle
@onready var easy_label = $ColorPopup/PanelContainer/VBoxContainer/AIDifficultyContainer/DifficultyHints/EasyLabel
@onready var hard_label = $ColorPopup/PanelContainer/VBoxContainer/AIDifficultyContainer/DifficultyHints/HardLabel

func _ready():
	# Apply safe area margins for iOS notch/dynamic island
	_apply_safe_area_margins()

	play_ai_button.pressed.connect(_on_play_ai_pressed)
	play_local_button.pressed.connect(_on_play_local_pressed)
	play_online_button.pressed.connect(_on_play_online_pressed)
	rules_button.pressed.connect(_on_rules_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	rules_close_button.pressed.connect(_on_close_rules_pressed)
	settings_close_button.pressed.connect(_on_close_settings_pressed)
	ai_difficulty_slider.value_changed.connect(_on_difficulty_changed)

	# Color selection buttons
	play_white_button.pressed.connect(_on_play_white_pressed)
	play_black_button.pressed.connect(_on_play_black_pressed)
	color_cancel_button.pressed.connect(_on_color_cancel_pressed)

	# Language option
	language_option.item_selected.connect(_on_language_selected)
	SettingsManager.language_changed.connect(_on_language_changed)

	# Enable online button
	play_online_button.disabled = false

	# Sync AI difficulty slider
	ai_difficulty_slider.value = AIPlayer.difficulty
	_update_difficulty_label(AIPlayer.difficulty)

	# Apply translations
	_update_translations()
	_update_language_option()

	# Configure language option popup
	var popup = language_option.get_popup()
	popup.add_theme_font_size_override("font_size", 34)
	popup.add_theme_constant_override("v_separation", 12)

func _on_language_selected(index: int):
	if index == 0:
		SettingsManager.set_language("en")
	elif index == 1:
		SettingsManager.set_language("ru")

func _on_language_changed(_locale: String):
	_update_translations()
	_update_language_option()

func _update_language_option():
	var is_en = SettingsManager.is_english()
	language_option.selected = 0 if is_en else 1

func _update_translations():
	# Title
	title_label.text = tr("GAME_TITLE")
	subtitle_label.text = tr("GAME_SUBTITLE")

	# Menu buttons
	play_local_button.text = tr("MENU_PLAY_LOCAL")
	play_ai_button.text = tr("MENU_PLAY_AI")
	play_online_button.text = tr("MENU_PLAY_ONLINE")
	rules_button.text = tr("MENU_RULES")
	tutorial_button.text = tr("MENU_TUTORIAL")
	settings_button.text = tr("MENU_SETTINGS")
	exit_button.text = tr("MENU_EXIT")

	# Settings popup
	settings_title.text = tr("MENU_SETTINGS")
	language_label.text = tr("SETTINGS_LANGUAGE")
	settings_close_button.text = tr("BTN_CLOSE")

	# Rules popup
	rules_title.text = tr("RULES_TITLE")
	rules_text.text = tr("RULES_TEXT")
	rules_close_button.text = tr("BTN_GOT_IT")

	# Color popup
	color_popup_title.text = tr("POPUP_PLAY_VS_AI")
	color_popup_subtitle.text = tr("POPUP_CHOOSE_COLOR")
	play_white_button.text = tr("BTN_WHITE")
	play_black_button.text = tr("BTN_BLACK")
	color_cancel_button.text = tr("BTN_CANCEL")
	easy_label.text = tr("HINT_EASY")
	hard_label.text = tr("HINT_HARD")

	# Update difficulty label
	_update_difficulty_label(int(ai_difficulty_slider.value))

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

func _on_tutorial_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/tutorial.tscn")

func _on_settings_pressed():
	_show_centered_popup(settings_popup)

func _on_close_rules_pressed():
	rules_popup.hide()

func _on_close_settings_pressed():
	settings_popup.hide()

func _show_centered_popup(popup: PopupPanel):
	var screen_size = get_viewport().get_visible_rect().size
	var pos_x = int((screen_size.x - popup.size.x) / 2)
	var pos_y = int((screen_size.y - popup.size.y) / 2)
	popup.position = Vector2i(max(10, pos_x), max(10, pos_y))
	popup.popup()

func _on_exit_pressed():
	get_tree().quit()

func _on_difficulty_changed(value: float):
	var level = int(value)
	AIPlayer.set_difficulty(level)
	_update_difficulty_label(level)

func _update_difficulty_label(level: int):
	var difficulty_name = AIPlayer.get_difficulty_name()
	ai_difficulty_label.text = tr("AI_DIFFICULTY") % [difficulty_name, level]

func _apply_safe_area_margins():
	# Get safe area margins (for iOS notch/dynamic island)
	var safe_rect = DisplayServer.get_display_safe_area()
	var screen_size = DisplayServer.screen_get_size()

	# Calculate top margin from safe area
	var top_margin = safe_rect.position.y

	# Apply margin to CenterPanel
	if top_margin > 20:
		center_panel.offset_top = top_margin
	else:
		center_panel.offset_top = 20
