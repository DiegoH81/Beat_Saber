extends GPUParticles3D


func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	finished.connect(queue_free)
	emitting = true
