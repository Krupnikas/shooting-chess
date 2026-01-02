extends Node2D

signal finished

var sprite: Label = null
var target_position: Vector2 = Vector2.ZERO
var speed: float = 400.0
var is_reinforce: bool = true  # true = green, false = red

func _ready():
	sprite = $Sprite2D
	update_color()

func setup(from_pos: Vector2, to_pos: Vector2, reinforce: bool):
	position = from_pos
	target_position = to_pos
	is_reinforce = reinforce
	# Don't call update_color here - wait for _ready

func update_color():
	if sprite == null:
		return

	if is_reinforce:
		sprite.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Green
	else:
		sprite.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))  # Red

func _process(delta):
	var direction = (target_position - position).normalized()
	var distance = position.distance_to(target_position)

	if distance < speed * delta:
		position = target_position
		emit_signal("finished")
		queue_free()
	else:
		position += direction * speed * delta
