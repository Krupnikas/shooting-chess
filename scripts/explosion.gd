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

	# Apply scale to flash
	flash.scale = Vector2(scale_multiplier, scale_multiplier)

	# Start particles
	particles.emitting = true

	# Flash effect - more intense for bigger explosions
	var flash_intensity = 0.8 * min(scale_multiplier, 2.0)
	var tween = create_tween()
	tween.tween_property(flash, "color:a", flash_intensity, 0.05)
	tween.tween_property(flash, "color:a", 0.0, 0.3 * scale_multiplier)

	# Wait for particles to finish then clean up
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	emit_signal("finished")
	queue_free()
