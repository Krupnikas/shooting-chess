extends PanelContainer

@onready var moves_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MovesContainer
@onready var scroll_container: ScrollContainer = $MarginContainer/VBoxContainer/ScrollContainer

func _ready():
	GameLog.move_logged.connect(_on_move_logged)
	GameLog.history_cleared.connect(_on_history_cleared)

func _on_move_logged(_record):
	refresh_display()
	# Auto-scroll to bottom
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_history_cleared():
	clear_display()

func clear_display():
	for child in moves_container.get_children():
		child.queue_free()

func refresh_display():
	clear_display()

	var formatted = GameLog.get_formatted_moves()
	for entry in formatted:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 28)

		var turn_str = str(entry["turn"]) + "."
		var white_str = entry["white"] if entry["white"] != "" else "..."
		var black_str = entry["black"] if entry["black"] != "" else ""

		if black_str != "":
			label.text = "%s %s  %s" % [turn_str, white_str, black_str]
		else:
			label.text = "%s %s" % [turn_str, white_str]

		moves_container.add_child(label)
