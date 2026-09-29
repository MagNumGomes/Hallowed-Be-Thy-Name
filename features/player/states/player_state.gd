class_name PlayerState
extends State
## Base abstrata por contrato (Godot 4.3 não possui @abstract).
## body é a referência física; player fornece a API tipada do controlador.

var body: CharacterBody2D
var player: Player


## Injeção feita por Player antes de StateMachine.start().
func setup(actor: Player) -> void:
	player = actor
	body = actor


## Intenção compartilhada de Idle/Run. Dash tem prioridade sobre salto.
func update_ground_movement(delta: float) -> void:
	player.apply_horizontal_movement(delta)
	player.apply_gravity(delta)
	if try_dash():
		return
	if try_attack():
		return
	if player.jump_pressed and player.try_jump():
		request_transition(&"Jump")
		return
	if not body.is_on_floor():
		request_transition(&"Jump")
	elif is_zero_approx(player.move_axis):
		request_transition(&"Idle")
	else:
		request_transition(&"Run")


func try_dash() -> bool:
	if player.dash_pressed and player.can_dash():
		request_transition(&"Dash")
		return true
	return false


func try_attack() -> bool:
	if player.attack_pressed:
		request_transition(&"Attack")
		return true
	return false
