extends Node2D

@onready var particles = $Particles
@onready var flash = $Flash

signal finished

func _ready():
	# Don't auto-start
	pass

func explode():
	# Start particles
	particles.emitting = true

	# Flash effect
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.8, 0.05)
	tween.tween_property(flash, "color:a", 0.0, 0.3)

	# Wait for particles to finish then clean up
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	emit_signal("finished")
	queue_free()
