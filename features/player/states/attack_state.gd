class_name AttackState
extends PlayerState
## Sequência: leve 1 → leve 2 → pesado. Um novo toque agenda o próximo golpe.

signal strike_started(index: int)

@export var light_damage: float = 12.0
@export var heavy_damage: float = 30.0
@export var light_knockback: Vector2 = Vector2(180.0, -60.0)
@export var heavy_knockback: Vector2 = Vector2(380.0, -150.0)
@export_range(0.01, 2.0) var light_windup: float = 0.10
@export_range(0.01, 2.0) var light_active: float = 0.12
@export_range(0.01, 2.0) var light_recovery: float = 0.20
@export_range(0.01, 2.0) var heavy_windup: float = 0.22
@export_range(0.01, 2.0) var heavy_active: float = 0.18
@export_range(0.01, 2.0) var heavy_recovery: float = 0.35

var combo_index: int = 0
var _elapsed: float = 0.0
var _queued: bool = false
var _opened: bool = false
var _facing: float = 1.0


func enter(_previous_state: State) -> void:
	combo_index = 0
	_start_strike()


func exit() -> void:
	player.sword_hitbox.end_strike()
	_queued = false
	combo_index = 0


func physics_update(delta: float) -> void:
	# Dash cancela o combo e exit fecha a hitbox imediatamente.
	if try_dash():
		return
	body.velocity.x = move_toward(body.velocity.x, 0.0, player.deceleration * delta)
	player.apply_gravity(delta)
	if player.attack_pressed and combo_index < 2:
		_queued = true
	_elapsed += delta
	var heavy := combo_index == 2
	var windup := heavy_windup if heavy else light_windup
	var duration := heavy_active if heavy else light_active
	var recovery := heavy_recovery if heavy else light_recovery
	if _elapsed >= windup and _elapsed < windup + duration and not _opened:
		_opened = true
		player.sword_hitbox.begin_strike(heavy_damage if heavy else light_damage,
			&"nanotube_heavy" if heavy else &"nanotube_slash",
			heavy_knockback if heavy else light_knockback, _facing)
	if _elapsed >= windup + duration:
		player.sword_hitbox.end_strike()
	if _elapsed >= windup + duration + recovery:
		if _queued and combo_index < 2:
			combo_index += 1
			_start_strike()
		elif not body.is_on_floor():
			request_transition(&"Jump")
		elif is_zero_approx(player.move_axis):
			request_transition(&"Idle")
		else:
			request_transition(&"Run")


func _start_strike() -> void:
	player.sword_hitbox.end_strike()
	_elapsed = 0.0
	_queued = false
	_opened = false
	_facing = player.facing_direction
	player.sword_hitbox.position.x = absf(player.sword_hitbox.position.x) * _facing
	strike_started.emit(combo_index)
