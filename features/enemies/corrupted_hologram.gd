class_name CorruptedHologram
extends EnemyBase
## Sentinela flutuante: transparência visual, rajadas instáveis e morte em glitch.

signal projectile_fired(projectile: EnergyProjectile)

@export_category("Disparo")
@export var projectile_scene: PackedScene = preload("res://features/combat/ranged/energy_projectile.tscn")
@export_range(0.05, 10.0) var fire_interval: float = 1.4
@export_range(0.01, 5.0) var attack_windup: float = 0.35
@export_range(0.0, 45.0) var spread_degrees: float = 9.0

@export_category("Glitch visual")
@export_range(0.0, 1.0) var minimum_alpha: float = 0.2
@export_range(0.0, 1.0) var maximum_alpha: float = 0.85
@export_range(0.01, 20.0) var flicker_frequency: float = 2.5
@export_range(1, 256) var death_particle_count: int = 36

var _clock: float = 0.0
var _cooldown: float = 0.0
var _windup_remaining: float = 0.0
var _charging: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng.randomize()
	_clock = _rng.randf_range(0.0, TAU)
	_cooldown = attack_windup


func _process(delta: float) -> void:
	if not _initialized or dead:
		return
	_clock += delta
	var wave := (sin(_clock * TAU * flicker_frequency) + 1.0) * 0.5
	visuals.modulate.a = lerpf(minimum_alpha, maximum_alpha, wave)


func _update_behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	if not is_instance_valid(target):
		_charging = false
		return
	face_direction(target.global_position.x - global_position.x)
	if not _charging:
		if _cooldown <= 0.0:
			_charging = true
			_windup_remaining = attack_windup
		return
	_windup_remaining -= delta
	if _windup_remaining <= 0.0:
		_charging = false
		_cooldown = fire_interval
		var aim := global_position.direction_to(target.global_position)
		aim = aim.rotated(deg_to_rad(_rng.randf_range(-spread_degrees, spread_degrees)))
		_spawn_projectile.call_deferred(global_position, aim)


func _spawn_projectile(origin: Vector2, direction: Vector2) -> void:
	if dead or not is_inside_tree() or projectile_scene == null:
		return
	var instance := projectile_scene.instantiate()
	var projectile := instance as EnergyProjectile
	if projectile == null:
		instance.free()
		push_error("CorruptedHologram: projectile_scene precisa de EnergyProjectile.")
		return
	projectile.configure(self, direction)
	# Irmão do inimigo: disparos continuam existindo após a morte da fonte.
	get_parent().add_child(projectile)
	projectile.global_position = origin
	projectile_fired.emit(projectile)


func _on_interrupted() -> void:
	_charging = false
	_cooldown = fire_interval


func _on_death() -> void:
	# CPU funciona no renderizador Compatibility. O efeito sobrevive ao inimigo.
	var particles := CPUParticles2D.new()
	particles.name = "GlitchDeath"
	particles.emitting = false
	particles.one_shot = true
	particles.amount = death_particle_count
	particles.lifetime = 0.65
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.direction = Vector2.RIGHT
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 180.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(10.0, 16.0)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color.CYAN, Color(1.0, 0.1, 0.8), Color(0.3, 1.0, 1.0), Color(0.3, 1.0, 1.0, 0.0)])
	particles.color_ramp = gradient
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
