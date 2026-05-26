extends Node2D

@onready var particles = $Particles
@onready var flash = $Flash

signal finished

var explosion_scale: float = 1.0

func _ready():
	# Don't auto-start
	pass

func explode(scale_multiplier: float = 1.0):
	explosion_scale = scale_multiplier

	# Apply scale to particles
	particles.scale_amount_min *= scale_multiplier
	particles.scale_amount_max *= scale_multiplier
	particles.initial_velocity_min *= scale_multiplier
	particles.initial_velocity_max *= scale_multiplier
	particles.amount = int(particles.amount * scale_multiplier)

	# Start particles
	particles.emitting = true

	# Hide flash (square ColorRect doesn't look good)
	flash.visible = false

	# Wait for particles to finish then clean up
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	emit_signal("finished")
	queue_free()
