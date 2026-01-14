extends Control

signal game_started()

# Main screen
@onready var main_screen = $CenterPanel/VBoxContainer/MainScreen
@onready var quick_match_button = $CenterPanel/VBoxContainer/MainScreen/QuickMatchButton
@onready var create_room_button = $CenterPanel/VBoxContainer/MainScreen/CreateRoomButton
@onready var join_room_button = $CenterPanel/VBoxContainer/MainScreen/JoinRoomButton
@onready var back_to_menu_button = $CenterPanel/VBoxContainer/MainScreen/BackToMenuButton

# Color screen (shown when creating room)
@onready var color_screen = $CenterPanel/VBoxContainer/ColorScreen
@onready var play_white_button = $CenterPanel/VBoxContainer/ColorScreen/PlayWhiteButton
@onready var play_black_button = $CenterPanel/VBoxContainer/ColorScreen/PlayBlackButton
@onready var color_back_button = $CenterPanel/VBoxContainer/ColorScreen/ColorBackButton

# Create screen
@onready var create_screen = $CenterPanel/VBoxContainer/CreateScreen
@onready var room_code_label = $CenterPanel/VBoxContainer/CreateScreen/RoomCodeContainer/RoomCodeLabel
@onready var copy_button = $CenterPanel/VBoxContainer/CreateScreen/CopyButton
@onready var create_back_button = $CenterPanel/VBoxContainer/CreateScreen/CreateBackButton

# Join screen
@onready var join_screen = $CenterPanel/VBoxContainer/JoinScreen
@onready var room_code_input = $CenterPanel/VBoxContainer/JoinScreen/RoomCodeInput
@onready var numpad_container = $CenterPanel/VBoxContainer/JoinScreen/NumpadContainer
@onready var join_submit_button = $CenterPanel/VBoxContainer/JoinScreen/NumpadContainer/JoinSubmitButton
@onready var join_back_button = $CenterPanel/VBoxContainer/JoinScreen/JoinBackButton

# Matchmaking screen
@onready var matchmaking_screen = $CenterPanel/VBoxContainer/MatchmakingScreen
@onready var matchmaking_label = $CenterPanel/VBoxContainer/MatchmakingScreen/MatchmakingLabel
@onready var matchmaking_back_button = $CenterPanel/VBoxContainer/MatchmakingScreen/MatchmakingBackButton
@onready var loader_dot1 = $CenterPanel/VBoxContainer/MatchmakingScreen/LoaderContainer/Loader/Dot1
@onready var loader_dot2 = $CenterPanel/VBoxContainer/MatchmakingScreen/LoaderContainer/Loader/Dot2
@onready var loader_dot3 = $CenterPanel/VBoxContainer/MatchmakingScreen/LoaderContainer/Loader/Dot3

# Shared
@onready var status_label = $CenterPanel/VBoxContainer/Header/StatusLabel
@onready var center_panel = $CenterPanel

var _current_scale: float = 1.0
var _last_screen: String = "main"  # Track which screen we're on for error handling
var _loader_timer: Timer = null
var _loader_step: int = 0

func _ready():
	# Main screen buttons
	quick_match_button.pressed.connect(_on_quick_match_pressed)
	create_room_button.pressed.connect(_on_create_room_pressed)
	join_room_button.pressed.connect(_on_join_room_pressed)
	back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)

	# Color screen buttons
	play_white_button.pressed.connect(_on_play_white_pressed)
	play_black_button.pressed.connect(_on_play_black_pressed)
	color_back_button.pressed.connect(_on_color_back_pressed)

	# Create screen buttons
	copy_button.pressed.connect(_on_copy_pressed)
	create_back_button.pressed.connect(_on_create_back_pressed)

	# Join screen buttons
	join_submit_button.pressed.connect(_on_join_submit_pressed)
	join_back_button.pressed.connect(_on_join_back_pressed)
	room_code_input.text_changed.connect(_on_code_input_changed)

	# Matchmaking screen buttons
	matchmaking_back_button.pressed.connect(_on_matchmaking_back_pressed)

	# Connect numpad buttons
	_setup_numpad()

	# Network signals
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.room_error.connect(_on_room_error)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	NetworkManager.matchmaking_started.connect(_on_matchmaking_started)
	NetworkManager.matchmaking_found.connect(_on_matchmaking_found)

	# Setup loader animation timer
	_loader_timer = Timer.new()
	_loader_timer.wait_time = 0.4
	_loader_timer.timeout.connect(_animate_loader)
	add_child(_loader_timer)

	_show_main_screen()
	_apply_responsive_scaling()
	get_tree().root.size_changed.connect(_apply_responsive_scaling)

	# Check URL for room reconnection (web only)
	_check_url_params()

func _setup_numpad():
	# Connect all numpad digit buttons (0-9)
	for i in range(10):
		var btn = numpad_container.get_node_or_null("Num%d" % i)
		if btn:
			btn.pressed.connect(_on_numpad_digit.bind(str(i)))

	# Connect backspace button
	var backspace = numpad_container.get_node_or_null("Backspace")
	if backspace:
		backspace.pressed.connect(_on_numpad_backspace)

func _on_numpad_digit(digit: String):
	if room_code_input.text.length() < 4:
		room_code_input.text += digit
		_on_code_input_changed(room_code_input.text)

func _on_numpad_backspace():
	if room_code_input.text.length() > 0:
		room_code_input.text = room_code_input.text.substr(0, room_code_input.text.length() - 1)
		_on_code_input_changed(room_code_input.text)

func _apply_responsive_scaling():
	var viewport_size = get_viewport().get_visible_rect().size

	# Panel base size matches main menu (800x900)
	var panel_base_height = 900.0
	var panel_base_width = 800.0
	var padding = 20.0  # Minimal margin

	# Calculate scale to fit viewport
	var scale_x = (viewport_size.x - padding) / panel_base_width
	var scale_y = (viewport_size.y - padding) / panel_base_height

	# Use the smaller scale to ensure it fits
	_current_scale = min(scale_x, scale_y)
	_current_scale = min(_current_scale, 1.0)  # Cap at 1x for desktop
	_current_scale = max(_current_scale, 0.5)  # Min scale

	center_panel.scale = Vector2(_current_scale, _current_scale)
	center_panel.pivot_offset = center_panel.size / 2

# ============ SCREEN NAVIGATION ============

func _show_main_screen():
	main_screen.visible = true
	color_screen.visible = false
	create_screen.visible = false
	join_screen.visible = false
	matchmaking_screen.visible = false
	status_label.text = "Create a room or join with a code"
	_last_screen = "main"
	_loader_timer.stop()

func _show_color_screen():
	main_screen.visible = false
	color_screen.visible = true
	create_screen.visible = false
	join_screen.visible = false
	matchmaking_screen.visible = false
	status_label.text = "Choose your color"
	_last_screen = "color"
	_loader_timer.stop()

func _show_create_screen():
	main_screen.visible = false
	color_screen.visible = false
	create_screen.visible = true
	join_screen.visible = false
	matchmaking_screen.visible = false
	room_code_label.text = "----"
	_last_screen = "create"
	_loader_timer.stop()

func _show_join_screen():
	main_screen.visible = false
	color_screen.visible = false
	create_screen.visible = false
	join_screen.visible = true
	matchmaking_screen.visible = false
	room_code_input.text = ""
	join_submit_button.disabled = true
	status_label.text = "Enter room code"
	_last_screen = "join"
	_loader_timer.stop()

func _show_matchmaking_screen():
	main_screen.visible = false
	color_screen.visible = false
	create_screen.visible = false
	join_screen.visible = false
	matchmaking_screen.visible = true
	status_label.text = "Looking for opponent..."
	_last_screen = "matchmaking"
	_loader_step = 0
	_update_loader_dots()
	_loader_timer.start()

# ============ MAIN SCREEN ACTIONS ============

func _on_quick_match_pressed():
	_show_matchmaking_screen()
	NetworkManager.start_matchmaking()

func _on_create_room_pressed():
	_show_color_screen()

func _on_join_room_pressed():
	_show_join_screen()

func _on_back_to_menu_pressed():
	NetworkManager.leave_room()
	_clear_url_params()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

# ============ COLOR SCREEN ACTIONS ============

func _on_play_white_pressed():
	_create_room_with_color(GameManager.PieceColor.WHITE)

func _on_play_black_pressed():
	_create_room_with_color(GameManager.PieceColor.BLACK)

func _on_color_back_pressed():
	_show_main_screen()

func _create_room_with_color(color: GameManager.PieceColor):
	_show_create_screen()
	status_label.text = "Creating room..."
	NetworkManager.create_room(color)

# ============ CREATE SCREEN ACTIONS ============

func _on_copy_pressed():
	DisplayServer.clipboard_set(room_code_label.text)
	status_label.text = "Code copied!"
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return  # Scene was changed
	if create_screen.visible:
		status_label.text = "Waiting for opponent..."

func _on_create_back_pressed():
	NetworkManager.leave_room()
	_show_main_screen()

# ============ JOIN SCREEN ACTIONS ============

func _on_code_input_changed(new_text: String):
	# Only allow digits
	var filtered = ""
	for c in new_text:
		if c.is_valid_int():
			filtered += c
	if filtered != new_text:
		room_code_input.text = filtered
		room_code_input.caret_column = filtered.length()

	join_submit_button.disabled = filtered.length() != 4

func _on_join_submit_pressed():
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() != 4:
		status_label.text = "Enter a 4-digit code"
		return

	status_label.text = "Joining room..."
	NetworkManager.join_room(code)

func _on_join_back_pressed():
	_show_main_screen()

# ============ MATCHMAKING SCREEN ACTIONS ============

func _on_matchmaking_back_pressed():
	NetworkManager.cancel_matchmaking()
	_show_main_screen()

func _animate_loader():
	_loader_step = (_loader_step + 1) % 4
	_update_loader_dots()

func _update_loader_dots():
	var dim_color = Color(0.4, 0.38, 0.28, 1)
	var bright_color = Color(1, 0.95, 0.7, 1)

	loader_dot1.add_theme_color_override("font_color", bright_color if _loader_step >= 1 else dim_color)
	loader_dot2.add_theme_color_override("font_color", bright_color if _loader_step >= 2 else dim_color)
	loader_dot3.add_theme_color_override("font_color", bright_color if _loader_step >= 3 else dim_color)

# ============ NETWORK CALLBACKS ============

func _on_room_created(room_code: String):
	if _last_screen == "matchmaking":
		# In matchmaking mode, keep showing the matchmaking screen
		status_label.text = "Waiting for opponent..."
	else:
		room_code_label.text = room_code
		status_label.text = "Waiting for opponent..."

func _on_room_joined(room_code: String):
	status_label.text = "Connecting to host..."

func _on_room_error(message: String):
	status_label.text = "Error: " + message
	# Stay on the current screen, just show the error
	# Re-enable UI elements based on which screen we're on
	match _last_screen:
		"join":
			# Stay on join screen, let user try again
			join_submit_button.disabled = room_code_input.text.length() != 4
		"create":
			# Go back to color selection since room creation failed
			_show_color_screen()
		"matchmaking":
			# Go back to main screen since matchmaking failed
			_show_main_screen()
		_:
			_show_main_screen()

func _on_peer_connected():
	print("[Lobby] Peer connected! Starting game in 1 second...")
	status_label.text = "Connected! Starting game..."
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return  # Scene was changed
	_start_game()

func _on_peer_disconnected():
	print("[Lobby] Peer disconnected while in lobby")
	if not is_inside_tree():
		return  # Scene was changed
	status_label.text = "Connection lost"
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return  # Scene was changed
	_show_main_screen()

func _on_matchmaking_started():
	print("[Lobby] Matchmaking started")
	status_label.text = "Looking for opponent..."

func _on_matchmaking_found():
	print("[Lobby] Found opponent!")
	status_label.text = "Found opponent! Connecting..."
	_loader_timer.stop()

func _start_game():
	print("[Lobby] Starting game, disabling AI...")
	# Disable AI for online play
	AIPlayer.disable_ai()
	# Set board flip before scene loads (guest plays as black)
	GameManager.is_board_flipped = NetworkManager.get_local_color() == GameManager.PieceColor.BLACK
	# Update URL with game state for reconnection
	_update_url_with_game_state()
	print("[Lobby] Changing scene to main.tscn")
	emit_signal("game_started")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# ============ URL STATE MANAGEMENT (Web only) ============

func _check_url_params():
	if not OS.has_feature("web"):
		return

	# Get URL parameters using JavaScript
	var js_code = """
		(function() {
			var params = new URLSearchParams(window.location.search);
			var room = params.get('room');
			var role = params.get('role');
			if (room && role) {
				return room + ',' + role;
			}
			return '';
		})()
	"""
	var result = JavaScriptBridge.eval(js_code)

	if result != null and result != "":
		var parts = result.split(",")
		if parts.size() == 2:
			var room_code = parts[0]
			var role = parts[1]
			print("[Lobby] Found URL params: room=", room_code, " role=", role)
			_auto_reconnect(room_code, role)

func _auto_reconnect(room_code: String, role: String):
	status_label.text = "Reconnecting to room " + room_code + "..."
	main_screen.visible = false
	create_screen.visible = false
	join_screen.visible = false

	if role == "host":
		# Reconnect as host - create room with same code
		NetworkManager.reconnect_as_host(room_code)
	else:
		# Reconnect as guest - force rejoin to skip "Room is full" check
		NetworkManager.join_room(room_code, true)

func _update_url_with_game_state():
	if not OS.has_feature("web"):
		return

	var room_code = NetworkManager.current_room_code
	var role = "host" if NetworkManager.is_host else "guest"

	var js_code = """
		(function() {
			var url = new URL(window.location.href);
			url.searchParams.set('room', '%s');
			url.searchParams.set('role', '%s');
			window.history.replaceState({}, '', url.toString());
		})()
	""" % [room_code, role]
	JavaScriptBridge.eval(js_code)
	print("[Lobby] Updated URL with room=", room_code, " role=", role)

func _clear_url_params():
	if not OS.has_feature("web"):
		return

	var js_code = """
		(function() {
			var url = new URL(window.location.href);
			url.searchParams.delete('room');
			url.searchParams.delete('role');
			window.history.replaceState({}, '', url.toString());
		})()
	"""
	JavaScriptBridge.eval(js_code)
