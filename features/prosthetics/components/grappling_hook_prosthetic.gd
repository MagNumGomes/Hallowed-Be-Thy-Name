class_name GrapplingHookProsthetic
extends ProstheticBase
## Disparo hitscan. Inimigos são puxados; âncoras puxam o portador.
## O portador chama physics_update antes de seu único move_and_slide.

signal fired(end_position: Vector2, attached: bool)
signal released()

@export var carrier: CharacterBody2D
@export var cable: Line2D
@export_flags_2d_physics var query_mask: int = 13
@export_range(1.0, 2000.0) var reach: float = 480.0
@export_range(1.0, 2000.0) var pull_speed: float = 550.0
@export_range(1.0, 200.0) var stop_distance: float = 28.0
@export_range(0.01, 10.0) var cooldown: float = 0.35
@export_range(0.01, 10.0) var max_attach_time: float = 1.5

var _cooldown_remaining: float = 0.0
var _attach_remaining: float = 0.0
var _target: Node2D
var _local_contact: Vector2
var _pull_enemy: bool = false


func can_activate() -> bool:
	return super.can_activate() and is_instance_valid(carrier) and _cooldown_remaining <= 0.0 and not is_attached()


## Entrada inválida não consome; disparo sem alvo consome normalmente.
func fire_at(world_position: Vector2) -> bool:
	if not can_activate() or not world_position.is_finite():
		return false
	var direction := carrier.global_position.direction_to(world_position)
	if direction.is_zero_approx():
		return false
	if not try_activate():
		return false
	_cooldown_remaining = cooldown
	var endpoint := carrier.global_position + direction * reach
	var query := PhysicsRayQueryParameters2D.create(carrier.global_position, endpoint, query_mask, [carrier.get_rid()])
	var result := carrier.get_world_2d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		endpoint = result["position"]
		var collider := result["collider"] as Node2D
		if collider is CharacterBody2D and collider.is_in_group(&"grapple_enemies"):
			_target = collider
			_pull_enemy = true
		elif collider is StaticBody2D and collider.is_in_group(&"grapple_anchors"):
			_target = collider
			_pull_enemy = false
		if is_attached():
			_local_contact = _target.to_local(endpoint)
			_attach_remaining = max_attach_time
	_update_cable(endpoint)
	fired.emit(endpoint, is_attached())
	return true


func is_attached() -> bool:
	return is_instance_valid(_target) and not _target.is_queued_for_deletion()


func release() -> void:
	var had_target := is_instance_valid(_target)
	_target = null
	if is_instance_valid(cable):
		cable.visible = false
	if had_target:
		released.emit()


func physics_update(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if not is_instance_valid(carrier) or not is_attached():
		release()
		return
	_attach_remaining -= delta
	var endpoint := _target.to_global(_local_contact)
	var offset := endpoint - carrier.global_position
	if _attach_remaining <= 0.0 or offset.length() <= stop_distance or offset.length() > reach:
		release()
		return
	# Qualquer parede entre portador e alvo encerra a ligação.
	var query := PhysicsRayQueryParameters2D.create(carrier.global_position, endpoint, query_mask, [carrier.get_rid()])
	var obstruction := carrier.get_world_2d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty() and obstruction["collider"] != _target:
		release()
		return
	var speed := minf(pull_speed, maxf(0.0, offset.length() - stop_distance) / maxf(delta, 0.001))
	if _pull_enemy:
		var enemy := _target as CharacterBody2D
		var pull_velocity := -offset.normalized() * speed
		if enemy.has_method(&"apply_grapple_pull"):
			enemy.call(&"apply_grapple_pull", pull_velocity)
		else:
			enemy.velocity = pull_velocity
	else:
		carrier.velocity = offset.normalized() * speed
	_update_cable(endpoint)


func _update_cable(endpoint: Vector2) -> void:
	if is_instance_valid(cable):
		cable.points = PackedVector2Array([cable.to_local(carrier.global_position), cable.to_local(endpoint)])
		cable.visible = is_attached()
