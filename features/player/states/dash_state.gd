class_name DashState
extends PlayerState
## Dash horizontal, sem gravidade e com invulnerabilidade enquanto ativo.

var _remaining: float = 0.0
var _direction: float = 1.0


func enter(_previous_state: State) -> void:
	_remaining = player.dash_duration
	_direction = player.facing_direction
	player.clear_coyote_time()
	player.set_dash_invulnerable(true)
	body.velocity = Vector2(_direction * player.dash_speed, 0.0)


func physics_update(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		if not body.is_on_floor():
			request_transition(&"Jump")
		elif is_zero_approx(player.move_axis):
			request_transition(&"Idle")
		else:
			request_transition(&"Run")
		return
	body.velocity = Vector2(_direction * player.dash_speed, 0.0)


func exit() -> void:
	player.set_dash_invulnerable(false)
	player.start_dash_cooldown()
	body.velocity.x = clampf(body.velocity.x, -player.move_speed, player.move_speed)
	_remaining = 0.0
