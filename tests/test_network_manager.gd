extends Node

# Manual test script for NetworkManager
# Run this scene to test Firebase connectivity

var test_room_code: String = ""

func _ready():
	print("=== NetworkManager Tests ===")
	print("")

	# Connect signals
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.room_error.connect(_on_room_error)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.move_received.connect(_on_move_received)

	# Run tests
	await test_room_code_generation()
	await test_create_room()
	await test_join_nonexistent_room()
	await test_leave_room()

	print("")
	print("=== Tests Complete ===")

func test_room_code_generation():
	print("[TEST] Room code generation...")

	var codes = []
	for i in range(10):
		var code = NetworkManager._generate_room_code()
		assert(code.length() == 4, "Room code should be 4 digits")
		for c in code:
			assert(c.is_valid_int(), "Room code should only contain digits")
		codes.append(code)

	print("  ✓ Generated 10 valid 4-digit codes")

func test_create_room():
	print("[TEST] Create room...")

	# Create room
	NetworkManager.create_room()

	# Wait for response
	await get_tree().create_timer(2.0).timeout

	if NetworkManager.connection_state == NetworkManager.ConnectionState.WAITING_FOR_PEER:
		print("  ✓ Room created successfully: ", NetworkManager.current_room_code)
		test_room_code = NetworkManager.current_room_code
	else:
		print("  ✗ Failed to create room")

func test_join_nonexistent_room():
	print("[TEST] Join nonexistent room...")

	# First leave current room
	NetworkManager.leave_room()
	await get_tree().create_timer(0.5).timeout

	# Try to join a room that doesn't exist
	NetworkManager.join_room("9999")

	# Wait for response
	await get_tree().create_timer(2.0).timeout

	if NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED:
		print("  ✓ Correctly rejected nonexistent room")
	else:
		print("  ✗ Should have failed to join nonexistent room")

func test_leave_room():
	print("[TEST] Leave room...")

	NetworkManager.leave_room()
	await get_tree().create_timer(0.5).timeout

	assert(NetworkManager.connection_state == NetworkManager.ConnectionState.DISCONNECTED)
	assert(NetworkManager.current_room_code == "")
	print("  ✓ Successfully left room")

func _on_room_created(room_code: String):
	print("  [Signal] room_created: ", room_code)

func _on_room_joined(room_code: String):
	print("  [Signal] room_joined: ", room_code)

func _on_room_error(message: String):
	print("  [Signal] room_error: ", message)

func _on_peer_connected():
	print("  [Signal] peer_connected")

func _on_move_received(from_pos: Vector2i, to_pos: Vector2i):
	print("  [Signal] move_received: ", from_pos, " -> ", to_pos)
