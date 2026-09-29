class_name RunState
extends PlayerState
## Movimento horizontal acelerado enquanto há entrada direcional.


func physics_update(delta: float) -> void:
	update_ground_movement(delta)
