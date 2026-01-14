extends Node

# Network Manager - Uses Firebase Realtime Database for multiplayer
# Stores game state and moves directly in Firebase, polls for updates

signal room_created(room_code: String)
signal room_joined(room_code: String)
signal room_error(message: String)
signal peer_connected()
signal peer_disconnected()
signal move_received(from_pos: Vector2i, to_pos: Vector2i)
signal matchmaking_started()
signal matchmaking_found()

# Firebase configuration
const FIREBASE_PROJECT_ID = "shooting-chess"
const FIREBASE_DATABASE_URL = "https://shooting-chess-default-rtdb.europe-west1.firebasedatabase.app"

# Room settings
const ROOM_CODE_LENGTH = 4
const POLL_INTERVAL = 0.5  # Poll every 500ms
const HTTP_TIMEOUT = 10.0  # Timeout for HTTP requests
const MAX_POLL_FAILURES = 5  # Disconnect after this many consecutive poll failures

# Connection state
enum ConnectionState { DISCONNECTED, CONNECTING, WAITING_FOR_PEER, CONNECTED }
var connection_state: ConnectionState = ConnectionState.DISCONNECTED

var current_room_code: String = ""
var is_host: bool = false
var local_player_color: GameManager.PieceColor = GameManager.PieceColor.WHITE

# Move tracking
var _processed_move_keys: Array = []  # Track which Firebase keys we've processed
var _poll_timer: Timer = null
var _http_create: HTTPRequest = null
var _http_join: HTTPRequest = null
var _http_poll: HTTPRequest = null
var _http_send: HTTPRequest = null
var _http_matchmaking: HTTPRequest = null
var _force_rejoin: bool = false
var _poll_failure_count: int = 0
var _last_opponent_activity: float = 0.0
var _is_matchmaking: bool = false
var _matchmaking_room_code: String = ""

func _ready():
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.timeout.connect(_poll_for_moves)
	add_child(_poll_timer)

# ============ ROOM MANAGEMENT ============

func create_room(host_color: GameManager.PieceColor = GameManager.PieceColor.WHITE) -> void:
	if connection_state != ConnectionState.DISCONNECTED:
		emit_signal("room_error", "Already in a room")
		return

	connection_state = ConnectionState.CONNECTING
	is_host = true
	local_player_color = host_color
	current_room_code = _generate_room_code()
	_processed_move_keys = []

	# Create room in Firebase with host's color choice
	var room_data = {
		"host_joined": true,
		"guest_joined": false,
		"host_color": "white" if host_color == GameManager.PieceColor.WHITE else "black",
		"created_at": Time.get_unix_time_from_system(),
		"moves": [],
		"current_turn": 0
	}

	var url = "%s/rooms/%s.json" % [FIREBASE_DATABASE_URL, current_room_code]
	var json = JSON.stringify(room_data)
	var headers = ["Content-Type: application/json"]

	_http_create = HTTPRequest.new()
	_http_create.timeout = HTTP_TIMEOUT
	add_child(_http_create)
	_http_create.request_completed.connect(_on_create_completed)
	_http_create.request(url, headers, HTTPClient.METHOD_PUT, json)

func _on_create_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_create.queue_free()
	_http_create = null

	if result == HTTPRequest.RESULT_TIMEOUT:
		emit_signal("room_error", "Connection timed out")
		connection_state = ConnectionState.DISCONNECTED
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Failed to create room")
		connection_state = ConnectionState.DISCONNECTED
		return

	print("[Network] Room created: ", current_room_code)
	connection_state = ConnectionState.WAITING_FOR_PEER
	emit_signal("room_created", current_room_code)

	# Start polling for guest to join
	_poll_timer.start()

func join_room(room_code: String, force_rejoin: bool = false) -> void:
	if connection_state != ConnectionState.DISCONNECTED:
		emit_signal("room_error", "Already in a room")
		return

	if room_code.length() != ROOM_CODE_LENGTH:
		emit_signal("room_error", "Invalid room code")
		return

	connection_state = ConnectionState.CONNECTING
	is_host = false
	local_player_color = GameManager.PieceColor.BLACK
	current_room_code = room_code.to_upper()
	_processed_move_keys = []
	_force_rejoin = force_rejoin

	# Check if room exists
	var url = "%s/rooms/%s.json" % [FIREBASE_DATABASE_URL, current_room_code]

	_http_join = HTTPRequest.new()
	_http_join.timeout = HTTP_TIMEOUT
	add_child(_http_join)
	_http_join.request_completed.connect(_on_join_check_completed)
	_http_join.request(url, [], HTTPClient.METHOD_GET)

func _on_join_check_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_join.queue_free()
	_http_join = null

	if result == HTTPRequest.RESULT_TIMEOUT:
		emit_signal("room_error", "Connection timed out")
		connection_state = ConnectionState.DISCONNECTED
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Network error")
		connection_state = ConnectionState.DISCONNECTED
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json is Dictionary:
		emit_signal("room_error", "Room not found")
		connection_state = ConnectionState.DISCONNECTED
		return

	if not json.get("host_joined", false):
		emit_signal("room_error", "Room not found")
		connection_state = ConnectionState.DISCONNECTED
		return

	if json.get("guest_joined", false) and not _force_rejoin:
		emit_signal("room_error", "Room is full")
		connection_state = ConnectionState.DISCONNECTED
		return

	# Set guest color as opposite of host's color
	var host_color_str = json.get("host_color", "white")
	if host_color_str == "white":
		local_player_color = GameManager.PieceColor.BLACK
	else:
		local_player_color = GameManager.PieceColor.WHITE

	# Mark guest as joined
	var url = "%s/rooms/%s/guest_joined.json" % [FIREBASE_DATABASE_URL, current_room_code]
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_guest_joined_completed.bind(http))
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, "true")

func _on_guest_joined_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Failed to join room")
		connection_state = ConnectionState.DISCONNECTED
		return

	print("[Network] Joined room: ", current_room_code)
	connection_state = ConnectionState.CONNECTED
	emit_signal("room_joined", current_room_code)
	emit_signal("peer_connected")

	# Start polling for moves
	_poll_timer.start()

func reconnect_as_host(room_code: String) -> void:
	"""Reconnect to an existing room as the host (after page reload)"""
	if connection_state != ConnectionState.DISCONNECTED:
		emit_signal("room_error", "Already in a room")
		return

	connection_state = ConnectionState.CONNECTING
	is_host = true
	current_room_code = room_code.to_upper()
	_processed_move_keys = []

	# Check if room still exists and update host_joined
	var url = "%s/rooms/%s.json" % [FIREBASE_DATABASE_URL, current_room_code]

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_reconnect_check_completed.bind(http))
	http.request(url, [], HTTPClient.METHOD_GET)

func _on_reconnect_check_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Network error")
		connection_state = ConnectionState.DISCONNECTED
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if json == null or not json is Dictionary:
		emit_signal("room_error", "Room no longer exists")
		connection_state = ConnectionState.DISCONNECTED
		return

	# Restore host's color from room data
	var host_color_str = json.get("host_color", "white")
	if host_color_str == "white":
		local_player_color = GameManager.PieceColor.WHITE
	else:
		local_player_color = GameManager.PieceColor.BLACK

	# Room exists - mark host as rejoined
	var update_url = "%s/rooms/%s/host_joined.json" % [FIREBASE_DATABASE_URL, current_room_code]
	var update_http = HTTPRequest.new()
	add_child(update_http)
	update_http.request_completed.connect(_on_host_rejoin_completed.bind(update_http, json.get("guest_joined", false)))
	update_http.request(update_url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, "true")

func _on_host_rejoin_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, guest_was_joined: bool) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Failed to reconnect")
		connection_state = ConnectionState.DISCONNECTED
		return

	print("[Network] Reconnected as host to room: ", current_room_code)
	emit_signal("room_created", current_room_code)

	if guest_was_joined:
		connection_state = ConnectionState.CONNECTED
		emit_signal("peer_connected")
	else:
		connection_state = ConnectionState.WAITING_FOR_PEER

	# Start polling
	_poll_timer.start()

# ============ POLLING ============

func _poll_for_moves() -> void:
	if connection_state == ConnectionState.DISCONNECTED:
		_poll_timer.stop()
		return

	if _http_poll != null:
		return  # Already polling

	var url = "%s/rooms/%s.json" % [FIREBASE_DATABASE_URL, current_room_code]

	_http_poll = HTTPRequest.new()
	_http_poll.timeout = HTTP_TIMEOUT
	add_child(_http_poll)
	_http_poll.request_completed.connect(_on_poll_completed)
	_http_poll.request(url, [], HTTPClient.METHOD_GET)

func _on_poll_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http_poll != null:
		_http_poll.queue_free()
		_http_poll = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_poll_failure_count += 1
		if _poll_failure_count >= MAX_POLL_FAILURES:
			print("[Network] Too many poll failures, disconnecting")
			_poll_timer.stop()
			connection_state = ConnectionState.DISCONNECTED
			emit_signal("peer_disconnected")
		return

	# Reset failure count on success
	_poll_failure_count = 0

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json is Dictionary:
		# Room was deleted - opponent left
		print("[Network] Room no longer exists")
		_poll_timer.stop()
		connection_state = ConnectionState.DISCONNECTED
		emit_signal("peer_disconnected")
		return

	# Check if guest joined (for host)
	if is_host and connection_state == ConnectionState.WAITING_FOR_PEER:
		if json.get("guest_joined", false):
			print("[Network] Guest connected!")
			connection_state = ConnectionState.CONNECTED
			_last_opponent_activity = Time.get_unix_time_from_system()

			# Remove from matchmaking queue if we were matchmaking
			if _is_matchmaking and _matchmaking_room_code != "":
				var mm_url = "%s/matchmaking/%s.json" % [FIREBASE_DATABASE_URL, _matchmaking_room_code]
				var mm_http = HTTPRequest.new()
				add_child(mm_http)
				mm_http.request_completed.connect(func(_r, _c, _h, _b): mm_http.queue_free())
				mm_http.request(mm_url, [], HTTPClient.METHOD_DELETE)
				_is_matchmaking = false
				_matchmaking_room_code = ""

			emit_signal("peer_connected")

	# Check for new moves (Firebase stores as dict with auto-generated keys)
	var moves = json.get("moves", {})
	if moves is Dictionary:
		# Sort keys by timestamp to process in order
		var move_keys = moves.keys()
		for key in move_keys:
			if key in _processed_move_keys:
				continue  # Already processed

			var move = moves[key]
			if not move is Dictionary:
				_processed_move_keys.append(key)
				continue  # Skip malformed moves

			# Validate move data exists
			if not move.has("from") or not move.has("to"):
				_processed_move_keys.append(key)
				continue

			var from_data = move["from"]
			var to_data = move["to"]
			if not from_data is Dictionary or not to_data is Dictionary:
				_processed_move_keys.append(key)
				continue

			if not from_data.has("x") or not from_data.has("y") or not to_data.has("x") or not to_data.has("y"):
				_processed_move_keys.append(key)
				continue

			var from = Vector2i(int(from_data["x"]), int(from_data["y"]))
			var to = Vector2i(int(to_data["x"]), int(to_data["y"]))
			var by_host = move.get("by_host", true)

			# Only process opponent's moves
			if (is_host and not by_host) or (not is_host and by_host):
				print("[Network] Received move: ", from, " -> ", to)
				_last_opponent_activity = Time.get_unix_time_from_system()
				emit_signal("move_received", from, to)

			_processed_move_keys.append(key)

# ============ SEND MOVE ============

func send_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if connection_state != ConnectionState.CONNECTED:
		return

	var move_data = {
		"from": {"x": from_pos.x, "y": from_pos.y},
		"to": {"x": to_pos.x, "y": to_pos.y},
		"by_host": is_host,
		"timestamp": Time.get_unix_time_from_system()
	}

	# Append move to Firebase array
	var url = "%s/rooms/%s/moves.json" % [FIREBASE_DATABASE_URL, current_room_code]
	var json = JSON.stringify(move_data)
	var headers = ["Content-Type: application/json"]

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(url, headers, HTTPClient.METHOD_POST, json)

	print("[Network] Sent move: ", from_pos, " -> ", to_pos)

# ============ CLEANUP ============

func leave_room() -> void:
	_poll_timer.stop()

	# Clean up HTTP requests
	if _http_create != null:
		_http_create.queue_free()
		_http_create = null
	if _http_join != null:
		_http_join.queue_free()
		_http_join = null
	if _http_poll != null:
		_http_poll.queue_free()
		_http_poll = null
	if _http_matchmaking != null:
		_http_matchmaking.queue_free()
		_http_matchmaking = null

	# Remove from matchmaking queue if we were waiting
	if _is_matchmaking and _matchmaking_room_code != "":
		var mm_url = "%s/matchmaking/%s.json" % [FIREBASE_DATABASE_URL, _matchmaking_room_code]
		var mm_http = HTTPRequest.new()
		add_child(mm_http)
		mm_http.request_completed.connect(func(_r, _c, _h, _b): mm_http.queue_free())
		mm_http.request(mm_url, [], HTTPClient.METHOD_DELETE)

	# Delete room if host
	if is_host and current_room_code != "":
		var url = "%s/rooms/%s.json" % [FIREBASE_DATABASE_URL, current_room_code]
		var http = HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
		http.request(url, [], HTTPClient.METHOD_DELETE)

	current_room_code = ""
	connection_state = ConnectionState.DISCONNECTED
	is_host = false
	_processed_move_keys = []
	_poll_failure_count = 0
	_last_opponent_activity = 0.0
	_is_matchmaking = false
	_matchmaking_room_code = ""

func _generate_room_code() -> String:
	var code = ""
	for i in range(ROOM_CODE_LENGTH):
		code += str(randi() % 10)
	return code

func is_online_game() -> bool:
	return connection_state == ConnectionState.CONNECTED

func get_local_color() -> GameManager.PieceColor:
	return local_player_color

# ============ MATCHMAKING ============

func start_matchmaking() -> void:
	"""Start looking for an opponent via matchmaking queue"""
	if connection_state != ConnectionState.DISCONNECTED:
		emit_signal("room_error", "Already in a room")
		return

	connection_state = ConnectionState.CONNECTING
	_is_matchmaking = true
	emit_signal("matchmaking_started")

	# Check if there's anyone waiting in the matchmaking queue
	var url = "%s/matchmaking.json" % FIREBASE_DATABASE_URL

	_http_matchmaking = HTTPRequest.new()
	_http_matchmaking.timeout = HTTP_TIMEOUT
	add_child(_http_matchmaking)
	_http_matchmaking.request_completed.connect(_on_matchmaking_check_completed)
	_http_matchmaking.request(url, [], HTTPClient.METHOD_GET)

func _on_matchmaking_check_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http_matchmaking != null:
		_http_matchmaking.queue_free()
		_http_matchmaking = null

	if result == HTTPRequest.RESULT_TIMEOUT:
		emit_signal("room_error", "Connection timed out")
		connection_state = ConnectionState.DISCONNECTED
		_is_matchmaking = false
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Network error")
		connection_state = ConnectionState.DISCONNECTED
		_is_matchmaking = false
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	# Check if there's a waiting player
	if json != null and json is Dictionary and json.size() > 0:
		# Get the first waiting player
		var waiting_key = json.keys()[0]
		var waiting_data = json[waiting_key]

		if waiting_data is Dictionary and waiting_data.has("room_code"):
			var room_code = waiting_data["room_code"]
			print("[Network] Found waiting player with room: ", room_code)

			# Remove them from queue first, then join their room
			_remove_from_matchmaking_queue(waiting_key, room_code)
			return

	# No one waiting - create room and add ourselves to queue
	print("[Network] No one waiting, creating room for matchmaking")
	_create_matchmaking_room()

func _remove_from_matchmaking_queue(key: String, room_code: String) -> void:
	"""Remove a player from matchmaking queue and join their room"""
	var url = "%s/matchmaking/%s.json" % [FIREBASE_DATABASE_URL, key]

	var http = HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_matchmaking_remove_completed.bind(http, room_code))
	http.request(url, [], HTTPClient.METHOD_DELETE)

func _on_matchmaking_remove_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, room_code: String) -> void:
	http.queue_free()

	# Even if delete failed (race condition), try to join the room
	# Reset state so join_room works
	connection_state = ConnectionState.DISCONNECTED
	_is_matchmaking = false

	print("[Network] Joining matchmaking room: ", room_code)
	emit_signal("matchmaking_found")
	join_room(room_code)

func _create_matchmaking_room() -> void:
	"""Create a room and add ourselves to matchmaking queue"""
	# Randomly assign color for matchmaking (host is white)
	is_host = true
	local_player_color = GameManager.PieceColor.WHITE
	current_room_code = _generate_room_code()
	_matchmaking_room_code = current_room_code
	_processed_move_keys = []

	# Create room in Firebase
	var room_data = {
		"host_joined": true,
		"guest_joined": false,
		"host_color": "white",
		"created_at": Time.get_unix_time_from_system(),
		"moves": [],
		"current_turn": 0
	}

	var url = "%s/rooms/%s.json" % [FIREBASE_DATABASE_URL, current_room_code]
	var json = JSON.stringify(room_data)
	var headers = ["Content-Type: application/json"]

	_http_create = HTTPRequest.new()
	_http_create.timeout = HTTP_TIMEOUT
	add_child(_http_create)
	_http_create.request_completed.connect(_on_matchmaking_room_created)
	_http_create.request(url, headers, HTTPClient.METHOD_PUT, json)

func _on_matchmaking_room_created(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _http_create != null:
		_http_create.queue_free()
		_http_create = null

	if result == HTTPRequest.RESULT_TIMEOUT:
		emit_signal("room_error", "Connection timed out")
		connection_state = ConnectionState.DISCONNECTED
		_is_matchmaking = false
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Failed to create room")
		connection_state = ConnectionState.DISCONNECTED
		_is_matchmaking = false
		return

	print("[Network] Matchmaking room created: ", current_room_code)

	# Add ourselves to matchmaking queue
	var matchmaking_data = {
		"room_code": current_room_code,
		"created_at": Time.get_unix_time_from_system()
	}

	var url = "%s/matchmaking.json" % FIREBASE_DATABASE_URL
	var json = JSON.stringify(matchmaking_data)
	var http_headers = ["Content-Type: application/json"]

	var http = HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT
	add_child(http)
	http.request_completed.connect(_on_added_to_matchmaking_queue.bind(http))
	http.request(url, http_headers, HTTPClient.METHOD_POST, json)

func _on_added_to_matchmaking_queue(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("room_error", "Failed to join matchmaking queue")
		# Clean up the room we created
		leave_room()
		_is_matchmaking = false
		return

	# Parse the response to get our matchmaking key
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json != null and json is Dictionary and json.has("name"):
		_matchmaking_room_code = json["name"]  # Store the Firebase key for later removal

	print("[Network] Added to matchmaking queue, waiting for opponent...")
	connection_state = ConnectionState.WAITING_FOR_PEER
	emit_signal("room_created", current_room_code)

	# Start polling for guest to join
	_poll_timer.start()

func cancel_matchmaking() -> void:
	"""Cancel matchmaking and clean up"""
	if _is_matchmaking and _matchmaking_room_code != "":
		# Remove from matchmaking queue
		var url = "%s/matchmaking/%s.json" % [FIREBASE_DATABASE_URL, _matchmaking_room_code]
		var http = HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
		http.request(url, [], HTTPClient.METHOD_DELETE)

	_is_matchmaking = false
	_matchmaking_room_code = ""
	leave_room()
