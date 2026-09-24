extends Node
class_name MovementModule

@export_category("Dependencies")
@export var enemy: Area3D

@export var direction: Vector3 = Vector3.ZERO

var velocity: float = 0

func _ready() -> void:
	assert(enemy, "[%s]: enemy is null" % name)
	assert(direction != Vector3.ZERO, "[%s]: direction is zero" % name)
	
func _physics_process(delta: float) -> void:
	enemy.global_position += direction * velocity * delta
