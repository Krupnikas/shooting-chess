extends PanelContainer

@onready var margin_container: MarginContainer = $MarginContainer
var moves_container: Container
var scroll_container: ScrollContainer
var title_label: Label

var is_mobile_layout: bool = false

func _ready():
	GameLog.move_logged.connect(_on_move_logged)
	GameLog.history_cleared.connect(_on_history_cleared)
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	call_deferred("_setup_layout")

func _setup_layout():
	var viewport_size = get_viewport().get_visible_rect().size
	is_mobile_layout = viewport_size.y > viewport_size.x

	# Clear existing children
	for child in margin_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	if is_mobile_layout:
		_setup_mobile_layout()
	else:
		_setup_desktop_layout()

	refresh_display()

func _setup_mobile_layout():
	# Bottom horizontal layout
	anchors_preset = 12  # Bottom wide
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	anchor_left = 0.0
	offset_left = 0.0
	offset_top = -150.0
	offset_right = 0.0
	offset_bottom = -100.0

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	margin_container.add_child(hbox)

	title_label = Label.new()
	title_label.text = "Moves:"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 1))
	hbox.add_child(title_label)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(scroll_container)

	moves_container = HBoxContainer.new()
	moves_container.add_theme_constant_override("separation", 24)
	scroll_container.add_child(moves_container)

func _setup_desktop_layout():
	# Right side vertical layout
	anchors_preset = 11  # Right wide
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -300.0
	offset_top = 100.0
	offset_right = 0.0
	offset_bottom = -200.0

	var vbox = VBoxContainer.new()
	margin_container.add_child(vbox)

	title_label = Label.new()
	title_label.text = "Moves"
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	vbox.add_child(separator)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll_container)

	moves_container = VBoxContainer.new()
	moves_container.add_theme_constant_override("separation", 4)
	scroll_container.add_child(moves_container)

func _on_viewport_size_changed():
	var viewport_size = get_viewport().get_visible_rect().size
	var should_be_mobile = viewport_size.y > viewport_size.x
	if should_be_mobile != is_mobile_layout:
		_setup_layout()

func _on_move_logged(_record):
	refresh_display()
	await get_tree().process_frame
	if is_mobile_layout:
		scroll_container.scroll_horizontal = scroll_container.get_h_scroll_bar().max_value
	else:
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func _on_history_cleared():
	clear_display()

func clear_display():
	if moves_container:
		for child in moves_container.get_children():
			child.queue_free()

func refresh_display():
	clear_display()
	if not moves_container:
		return

	var formatted = GameLog.get_formatted_moves()
	for entry in formatted:
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 28)
		label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 1))

		var turn_str = str(entry["turn"]) + "."
		var white_str = entry["white"] if entry["white"] != "" else "..."
		var black_str = entry["black"] if entry["black"] != "" else ""

		if black_str != "":
			label.text = "%s %s %s" % [turn_str, white_str, black_str]
		else:
			label.text = "%s %s" % [turn_str, white_str]

		moves_container.add_child(label)
