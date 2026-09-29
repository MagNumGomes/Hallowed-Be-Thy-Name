class_name ZealotMelee
extends EnemyBase
## Patrulha local; prepara, investe em direção fixa e se recupera entre golpes.

enum BehaviorState { PATROL, WINDUP, CHARGE, RECOVERY }

@export_category("Referências do fanático")
@export var melee_hitbox: Hitbox
@export var ground_ray: RayCast2D

@export_category("Patrulha e investida")
@export_range(1.0, 1000.0) var patrol_speed: float = 65.0
@export_range(1.0, 2000.0) var patrol_distance: float = 120.0
@export_range(1.0, 2000.0) var charge_speed: float = 340.0
@export_range(0.01, 5.0) var windup_duration: float = 0.3
@export_range(0.01, 5.0) var charge_duration: float = 0.8
@export_range(0.01, 5.0) var recovery_duration: float = 0.7
@export_range(0.0, 1000.0) var melee_damage: float = 18.0
@export var melee_knockback: Vector2 = Vector2(240.0, -100.0)

var state: BehaviorState = BehaviorState.PATROL
var _remaining: float = 0.0
var _patrol_origin: Vector2
var _hitbox_offset: float = 0.0


func _ready() -> void:
	super._ready()
	if not is_instance_valid(melee_hitbox) or not is_instance_valid(ground_ray):
		_initialized = false
		push_error("ZealotMelee: atribua MeleeHitbox e GroundRay.")
		return
	_patrol_origin = global_position
	_hitbox_offset = absf(melee_hitbox.position.x)
	melee_hitbox.source = self
	melee_hitbox.team = &"enemy"
	melee_hitbox.hit_confirmed.connect(_on_hit_confirmed)


func _update_behavior(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	match state:
		BehaviorState.PATROL:
			if is_instance_valid(target):
				face_direction(target.global_position.x - global_position.x)
				_set_state(BehaviorState.WINDUP, windup_duration)
				velocity.x = 0.0
				return
			var offset := global_position.x - _patrol_origin.x
			if (absf(offset) >= patrol_distance and signf(offset) == facing_direction) or is_on_wall() or _ledge_ahead():
				face_direction(-facing_direction)
			velocity.x = facing_direction * patrol_speed
		BehaviorState.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			if not is_instance_valid(target):
				_set_state(BehaviorState.RECOVERY, recovery_duration)
			elif _remaining <= 0.0:
				face_direction(target.global_position.x - global_position.x)
				melee_hitbox.position.x = _hitbox_offset * facing_direction
				melee_hitbox.begin_strike(melee_damage, &"zealot_melee", melee_knockback, facing_direction)
				_set_state(BehaviorState.CHARGE, charge_duration)
		BehaviorState.CHARGE:
			if _remaining <= 0.0 or is_on_wall() or _ledge_ahead():
				_set_state(BehaviorState.RECOVERY, recovery_duration)
				velocity.x = 0.0
			else:
				velocity.x = facing_direction * charge_speed
		BehaviorState.RECOVERY:
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			if _remaining <= 0.0:
				_set_state(BehaviorState.PATROL)


func _after_move() -> void:
	melee_hitbox.scan_overlaps()


func _ledge_ahead() -> bool:
	ground_ray.position.x = absf(ground_ray.position.x) * facing_direction
	ground_ray.force_raycast_update()
	return is_on_floor() and not ground_ray.is_colliding()


func _set_state(next: BehaviorState, duration: float = 0.0) -> void:
	if next != BehaviorState.CHARGE:
		melee_hitbox.end_strike()
	state = next
	_remaining = duration


func _on_hit_confirmed(_victim: Hurtbox) -> void:
	_set_state(BehaviorState.RECOVERY, recovery_duration)
	velocity.x = 0.0


func _on_interrupted() -> void:
	_set_state(BehaviorState.RECOVERY, recovery_duration)
