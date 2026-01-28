extends Control

@onready var tutorial_board = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/BoardContainer/TutorialBoard
@onready var step_indicator = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/TextContainer/StepIndicator
@onready var step_title = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/TextContainer/StepTitle
@onready var step_description = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/TextContainer/StepDescription
@onready var prev_button = $CenterContainer/PanelContainer/VBoxContainer/NavigationContainer/PrevButton
@onready var next_button = $CenterContainer/PanelContainer/VBoxContainer/NavigationContainer/NextButton
@onready var close_button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton
@onready var step_dots_container = $CenterContainer/PanelContainer/VBoxContainer/NavigationContainer/StepDots
@onready var title_label = $CenterContainer/PanelContainer/VBoxContainer/Header/Title

const TOTAL_STEPS = 5
var current_step: int = 1
var step_dots: Array = []

func _get_step_titles() -> Array:
	return [
		"",
		tr("STEP1_TITLE"),
		tr("STEP2_TITLE"),
		tr("STEP3_TITLE"),
		tr("STEP4_TITLE"),
		tr("STEP5_TITLE")
	]

func _get_step_descriptions() -> Array:
	return [
		"",
		tr("STEP1_DESC"),
		tr("STEP2_DESC"),
		tr("STEP3_DESC"),
		tr("STEP4_DESC"),
		tr("STEP5_DESC")
	]

func _ready():
	prev_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	close_button.pressed.connect(_on_close_pressed)

	_create_step_dots()
	_show_step(1)

func _create_step_dots():
	for i in range(TOTAL_STEPS):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.color = Color(0.3, 0.3, 0.28)
		step_dots_container.add_child(dot)
		step_dots.append(dot)

func _show_step(step: int):
	current_step = step
	_update_ui()
	tutorial_board.play_step(step)

func _update_ui():
	# Update title
	title_label.text = tr("TUTORIAL_TITLE")

	# Update step content
	step_indicator.text = tr("STEP_X_OF_Y") % [current_step, TOTAL_STEPS]
	step_title.text = _get_step_titles()[current_step]
	step_description.text = _get_step_descriptions()[current_step]

	# Update buttons
	prev_button.disabled = (current_step == 1)
	prev_button.text = tr("BTN_PREVIOUS")
	next_button.text = tr("BTN_DONE") if current_step == TOTAL_STEPS else tr("BTN_NEXT")
	close_button.text = tr("BTN_BACK_TO_MENU")

	_update_dots()

func _update_dots():
	for i in range(step_dots.size()):
		if i == current_step - 1:
			step_dots[i].color = Color(0.93, 0.86, 0.71)
		else:
			step_dots[i].color = Color(0.3, 0.3, 0.28)

func _on_previous_pressed():
	if current_step > 1:
		_transition_to_step(current_step - 1)

func _on_next_pressed():
	if current_step < TOTAL_STEPS:
		_transition_to_step(current_step + 1)
	else:
		_on_close_pressed()

func _transition_to_step(new_step: int):
	tutorial_board.stop_animation()
	var tween = create_tween()
	tween.tween_property(tutorial_board, "modulate:a", 0.0, 0.15)
	await tween.finished
	_show_step(new_step)
	tween = create_tween()
	tween.tween_property(tutorial_board, "modulate:a", 1.0, 0.15)

func _on_close_pressed():
	tutorial_board.stop_animation()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
