extends Control

signal game_started()

@onready var create_button = $CenterPanel/VBoxContainer/ButtonContainer/CreateRoomButton
@onready var join_button = $CenterPanel/VBoxContainer/ButtonContainer/JoinRoomButton
@onready var back_button = $CenterPanel/VBoxContainer/ButtonContainer/BackButton
@onready var room_code_input = $CenterPanel/VBoxContainer/JoinContainer/RoomCodeInput
@onready var status_label = $CenterPanel/VBoxContainer/StatusLabel
@onready var room_code_display = $CenterPanel/VBoxContainer/RoomCodeDisplay
@onready var room_code_label = $CenterPanel/VBoxContainer/RoomCodeDisplay/RoomCodeLabel
@onready var copy_button = $CenterPanel/VBoxContainer/RoomCodeDisplay/CopyButton
@onready var join_container = $CenterPanel/VBoxContainer/JoinContainer
@onready var button_container = $CenterPanel/VBoxContainer/ButtonContainer
@onready var center_panel = $CenterPanel

var _current_scale: float = 1.0

func _ready():
	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	room_code_input.text_changed.connect(_on_code_input_changed)

	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.room_error.connect(_on_room_error)
	NetworkManager.peer_connected.connect(_on_peer_connected)

	_reset_ui()
	_apply_responsive_scaling()
	get_tree().root.size_changed.connect(_apply_responsive_scaling)

func _apply_responsive_scaling():
	var viewport_size = get_viewport().get_visible_rect().size
	var min_dimension = min(viewport_size.x, viewport_size.y)

	if min_dimension < 800:
		_current_scale = 1.8
	elif min_dimension < 1200:
		_current_scale = 1.4
	else:
		_current_scale = 1.0

	center_panel.scale = Vector2(_current_scale, _current_scale)
	center_panel.pivot_offset = center_panel.size / 2

func _reset_ui():
	room_code_display.visible = false
	join_container.visible = true
	button_container.visible = true
	status_label.text = "Create a room or enter a code to join"
	room_code_input.text = ""
	join_button.disabled = true

func _on_create_pressed():
	status_label.text = "Creating room..."
	button_container.visible = false
	join_container.visible = false
	NetworkManager.create_room()

func _on_join_pressed():
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() != 4:
		status_label.text = "Enter a 4-digit code"
		return

	status_label.text = "Joining room..."
	button_container.visible = false
	join_container.visible = false
	NetworkManager.join_room(code)

func _on_back_pressed():
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_copy_pressed():
	DisplayServer.clipboard_set(room_code_label.text)
	status_label.text = "Code copied!"
	await get_tree().create_timer(1.5).timeout
	if room_code_display.visible:
		status_label.text = "Waiting for opponent..."

func _on_code_input_changed(new_text: String):
	# Only allow digits
	var filtered = ""
	for c in new_text:
		if c.is_valid_int():
			filtered += c
	if filtered != new_text:
		room_code_input.text = filtered
		room_code_input.caret_column = filtered.length()

	join_button.disabled = filtered.length() != 4

func _on_room_created(room_code: String):
	room_code_display.visible = true
	room_code_label.text = room_code
	status_label.text = "Waiting for opponent..."
	button_container.visible = false
	join_container.visible = false

func _on_room_joined(room_code: String):
	status_label.text = "Connecting to host..."

func _on_room_error(message: String):
	status_label.text = "Error: " + message
	_reset_ui()

func _on_peer_connected():
	print("[Lobby] Peer connected! Starting game in 1 second...")
	status_label.text = "Connected! Starting game..."
	await get_tree().create_timer(1.0).timeout
	_start_game()

func _start_game():
	print("[Lobby] Starting game, disabling AI...")
	# Disable AI for online play
	AIPlayer.disable_ai()
	print("[Lobby] Changing scene to main.tscn")
	emit_signal("game_started")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
