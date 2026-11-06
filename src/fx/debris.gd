class_name Debris
extends RigidBody3D
## Peça solta (p. ex. uma roda do rover) com gravidade para o centro do planeta.

var planet_center := Vector3.ZERO
var gravity := 22.0

func _ready() -> void:
	gravity_scale = 0.0
	can_sleep = false

func _physics_process(_delta: float) -> void:
	apply_central_force(-(global_position - planet_center).normalized() * gravity * mass)
