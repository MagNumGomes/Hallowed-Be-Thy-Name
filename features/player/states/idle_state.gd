class_name IdleState
extends PlayerState
## Desacelera até parar e permite salto, corrida e dash.


func physics_update(delta: float) -> void:
	update_ground_movement(delta)
