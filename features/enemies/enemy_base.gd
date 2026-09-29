class_name EnemyBase
extends CharacterBody2D
## Coordena percepção, vida e um único passo físico. Especializações definem a IA.

signal health_changed(current: float, maximum: float)
signal target_changed(current: Node2D)
signal defeated()

@export_category("Referências")
@export var hurtbox: Hurtbox
@export var health_bar: ProgressBar
@export var vision_area: Area2D
@export var sight_ray: RayCast2D
@export var visuals: Node2D

@export_category("Combate e percepção")
@export_range(1.0, 10000.0) var max_health: float = 60.0
@export_range(0.0, 2.0) var hit_recovery: float = 0.15
@export var target_group: StringName = &"player"
@export_range(1.0, 2000.0) var vision_radius: float = 360.0

@export_category("Física")
@export_range(0.0, 5000.0) var gravity: float = 1200.0
@export_range(1.0, 3000.0) var max_fall_speed: float = 900.0
@export_range(1.0, 10000.0) var deceleration: float = 1400.0

var health: float = 0.0
var target: Node2D
var facing_direction: float = 1.0
var dead: bool = false
var _initialized: bool = false
var _hit_remaining: float = 0.0
var _pending_knockback: Vector2 = Vector2.ZERO
var _grapple_velocity: Vector2 = Vector2.ZERO
var _has_grapple_pull: bool = false


func _ready() -> void:
	if not is_instance_valid(hurtbox) or not is_instance_valid(health_bar) or not is_instance_valid(vision_area) or not is_instance_valid(sight_ray) or not is_instance_valid(visuals):
		push_error("EnemyBase: atribua Hurtbox, HealthBar, VisionArea, SightRay e Visuals.")
		return
	var vision_shape := vision_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if vision_shape == null:
		push_error("EnemyBase: VisionArea precisa de um CollisionShape2D.")
		return
	# Recurso por instância: ajustar alcance não altera os outros inimigos.
	var circle := CircleShape2D.new()
	circle.radius = maxf(1.0, vision_radius)
	vision_shape.shape = circle
	sight_ray.add_exception(self)
	hurtbox.receiver = self
	hurtbox.team = &"enemy"
	hurtbox.impacted.connect(_on_impacted)
	add_to_group(&"grapple_enemies")
	health = maxf(1.0, max_health)
	health_bar.max_value = health
	health_bar.value = health
	_initialized = true


func _physics_process(delta: float) -> void:
	if not _initialized or dead:
		return
	_update_target()
	if _hit_remaining > 0.0:
		_hit_remaining = maxf(0.0, _hit_remaining - delta)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	else:
		_update_behavior(delta)
	if gravity > 0.0:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	else:
		velocity.y = move_toward(velocity.y, 0.0, deceleration * delta)
	if _has_grapple_pull:
		velocity = _grapple_velocity
		_has_grapple_pull = false
	velocity += _pending_knockback
	_pending_knockback = Vector2.ZERO
	move_and_slide()
	_after_move()


## Pontos de extensão; não duplicar move_and_slide nas especializações.
func _update_behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _after_move() -> void:
	pass


func _on_interrupted() -> void:
	pass


func _on_death() -> void:
	pass


## A área limita o alcance; o raio exige linha de visão sem atravessar World.
func can_see(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
		return false
	if not candidate.is_in_group(target_group) or not vision_area.overlaps_body(candidate):
		return false
	sight_ray.target_position = sight_ray.to_local(candidate.global_position)
	sight_ray.force_raycast_update()
	return sight_ray.is_colliding() and sight_ray.get_collider() == candidate


func _update_target() -> void:
	var next_target: Node2D = null
	if is_instance_valid(target) and can_see(target):
		next_target = target
	else:
		var nearest_distance: float = INF
		for body: Node2D in vision_area.get_overlapping_bodies():
			var distance := global_position.distance_squared_to(body.global_position)
			if distance < nearest_distance and can_see(body):
				next_target = body
				nearest_distance = distance
	if target != next_target:
		target = next_target
		target_changed.emit(target)


func face_direction(direction: float) -> void:
	if not is_zero_approx(direction):
		facing_direction = signf(direction)
		visuals.scale.x = absf(visuals.scale.x) * facing_direction


## Hurtbox consulta antes de aceitar um impacto.
func is_invulnerable() -> bool:
	return not _initialized or dead or _hit_remaining > 0.0


## Intenção do gancho tem prioridade sobre a IA no próximo passo físico.
func apply_grapple_pull(pull_velocity: Vector2) -> void:
	if not dead:
		_grapple_velocity = pull_velocity
		_has_grapple_pull = true


func _on_impacted(amount: float, _kind: StringName, impulse: Vector2, _source: Node) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	_hit_remaining = hit_recovery
	_pending_knockback += impulse
	_on_interrupted()
	health_bar.value = health
	var lethal := health <= 0.0
	if lethal:
		# Trava síncrona: nenhum segundo impacto/ataque durante a remoção diferida.
		dead = true
		hurtbox.invulnerable = true
		hurtbox.set_deferred(&"monitorable", false)
		set_deferred(&"collision_layer", 0)
		set_deferred(&"collision_mask", 0)
		health_bar.hide()
		visuals.hide()
		target = null
		remove_from_group(&"grapple_enemies")
		_finish_death.call_deferred()
	health_changed.emit(health, max_health)
	if lethal:
		defeated.emit()


func _finish_death() -> void:
	_on_death()
	queue_free()
