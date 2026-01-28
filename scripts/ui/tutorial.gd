extends Control

@onready var tutorial_board = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/BoardContainer/TutorialBoard
@onready var step_indicator = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/TextContainer/StepIndicator
@onready var step_title = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/TextContainer/StepTitle
@onready var step_description = $CenterContainer/PanelContainer/VBoxContainer/ContentContainer/TextContainer/StepDescription
@onready var prev_button = $CenterContainer/PanelContainer/VBoxContainer/NavigationContainer/PrevButton
@onready var next_button = $CenterContainer/PanelContainer/VBoxContainer/NavigationContainer/NextButton
@onready var close_button = $CenterContainer/PanelContainer/VBoxContainer/CloseButton
@onready var step_dots_container = $CenterContainer/PanelContainer/VBoxContainer/NavigationContainer/StepDots

const TOTAL_STEPS = 5
var current_step: int = 1
var step_dots: Array = []

const STEP_TITLES = [
	"",
	"Movement",
	"HP System",
	"Shooting Phase",
	"Death & Reset",
	"Win Condition"
]

const STEP_DESCRIPTIONS = [
	"",
	"Pieces move and attack like in regular chess. Select a piece to see valid moves highlighted in green.",
	"Pieces have HP:\n[color=#aaddaa]Pawn & King: 1 HP\nKnight, Bishop, Rook: 2 HP\nQueen: 3 HP[/color]",
	"After a move, all pieces shoot.\n[color=#aaddaa]Hit ally = heal (+1 HP)[/color]\n[color=#ffaaaa]Hit enemy = damage (-1 HP)[/color]",
	"When HP reaches 0, the piece [color=#ffaaaa]dies[/color].\nAt the start of your turn, all your pieces' HP [color=#aaddaa]resets to default[/color].",
	"Protect your King, attack the opponent's!\n[color=#ffdd88]Check can be ignored[/color], but if your King is captured - [color=#ffaaaa]Game Over[/color]."
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
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = Color(0.3, 0.3, 0.28)
		step_dots_container.add_child(dot)
		step_dots.append(dot)

func _show_step(step: int):
	current_step = step
	_update_ui()
	tutorial_board.play_step(step)

func _update_ui():
	step_indicator.text = "Step %d of %d" % [current_step, TOTAL_STEPS]
	step_title.text = STEP_TITLES[current_step]
	step_description.text = STEP_DESCRIPTIONS[current_step]
	prev_button.disabled = (current_step == 1)
	next_button.text = "Done" if current_step == TOTAL_STEPS else "Next"
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
