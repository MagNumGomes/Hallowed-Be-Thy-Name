class_name EnergyProjectile
extends Node2D
## Trajetória ondulada com varredura contínua por segmento, inclusive em alta velocidade.

signal impacted(collider: Node)

@export_range(1.0, 5000.0) var speed: float = 300.0
@export_range(0.01, 30.0) var lifetime: float = 3.0
@export_range(0.0, 1000.0) var damage: float = 12.0
@export var damage_type: StringName = &"unstable_energy"
@export_range(0.0, 2000.0) var knockback_strength: float = 120.0
@export var team: StringName = &"enemy"
@export_flags_2d_physics var collision_mask: int = 17 # World + PlayerHurtbox.
@export_range(0.0, 200.0) var wobble_amplitude: float = 12.0
@export_range(0.0, 30.0) var wobble_frequency: float = 5.0

var source: Node2D
var direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _phase: float = 0.0
var _spent: bool = false


## Configurar antes de adicionar à árvore. Direção é expressa no espaço global.
func configure(shooter: Node2D, travel_direction: Vector2) -> void:
	source = shooter
	if travel_direction.is_finite() and not travel_direction.is_zero_approx():
		direction = travel_direction.normalized()


func _ready() -> void:
	_phase = randf_range(0.0, TAU)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step := minf(delta, maxf(0.0, lifetime - _age))
	if step <= 0.0:
		_expire()
		return
	var previous_wave := sin(_age * TAU * wobble_frequency + _phase)
	_age += step
	var wave := sin(_age * TAU * wobble_frequency + _phase)
	var offset := direction.orthogonal() * (wave - previous_wave) * wobble_amplitude
	var destination := global_position + direction * speed * step + offset
	var query := PhysicsRayQueryParameters2D.create(global_position, destination, collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result["position"]
		_hit(result["collider"] as Node)
		return
	global_position = destination
	modulate.a = 0.65 + 0.35 * absf(wave)
	if _age >= lifetime:
		_expire()


func _hit(collider: Node) -> void:
	# Reservar antes de sinais: uma colisão nunca causa dano duplicado.
	_spent = true
	if collider is Hurtbox:
		var shooter: Node = source if is_instance_valid(source) else null
		(collider as Hurtbox).receive_hit(damage, damage_type, direction * knockback_strength, shooter, team)
	impacted.emit(collider)
	queue_free()


func _expire() -> void:
	_spent = true
	queue_free()
