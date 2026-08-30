extends Area3D
class_name MovementModule

@export_category("Dependencies")
@export var enemy: Area3D

@export_category("Attributes")
@export var hp: int = 0

@export var max_velocity: float = 0.0
@export var acceleration: float = 0.0
@export var direction: Vector3 = Vector3.ZERO

var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	assert(enemy, "[%s]: enemy is null" % name)
	
	assert(hp != 0, "[%s]: hp is zero" % name)
	
	assert(max_velocity != 0, "[%s]: max velocity is zero" % name)
	assert(acceleration != 0, "[%s]: acceleration is zero" % name)
	assert(direction != Vector3.ZERO, "[%s]: direction is zero" % name)
	
func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(max_velocity * direction, acceleration * delta)
	enemy.position += velocity * delta
