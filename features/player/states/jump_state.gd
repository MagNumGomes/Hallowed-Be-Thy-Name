class_name JumpState
extends PlayerState
## Abrange subida e queda, inclusive saída de bordas sem salto.
## A janela de coyote pertence ao jogador e é consumida por try_jump().


func physics_update(delta: float) -> void:
	if try_dash():
		return
	if try_attack():
		return
	player.apply_horizontal_movement(delta)
	if player.jump_pressed:
		player.try_jump()
	player.apply_gravity(delta)
	# O piso descreve o último move_and_slide; velocidade negativa indica
	# um novo salto e impede uma transição prematura para Idle/Run.
	if body.is_on_floor() and body.velocity.y >= 0.0:
		if is_zero_approx(player.move_axis):
			request_transition(&"Idle")
		else:
			request_transition(&"Run")
