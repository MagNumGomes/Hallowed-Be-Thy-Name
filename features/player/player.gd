class_name Player
extends CharacterBody2D
## Coordena entrada, temporizadores e física. Estados apenas alteram intenção.

signal dash_invulnerability_changed(active: bool)
signal health_changed(current: float, maximum: float)
signal defeated()
signal fragments_changed(total: int)

var fragments: int = 0:
	set(value):
		fragments = maxi(0, value)
		fragments_changed.emit(fragments)

@export_category("Referências")
@export var state_machine: StateMachine
@export var sword_hitbox: Hitbox
@export var hurtbox: Hurtbox
@export var grappling_hook: GrapplingHookProsthetic

@export_category("Combate")
@export_range(1.0, 10000.0) var max_health: float = 100.0
@export_range(0.0, 2.0) var hit_recovery: float = 0.18

var health: float = 0.0
var _hit_remaining: float = 0.0
var _pending_knockback: Vector2 = Vector2.ZERO

@export_category("Movimento")
@export_range(1.0, 2000.0, 1.0) var move_speed: float = 250.0
@export_range(1.0, 10000.0, 1.0) var acceleration: float = 1800.0
@export_range(1.0, 10000.0, 1.0) var deceleration: float = 2200.0
@export_range(0.0, 1.0, 0.05) var air_control: float = 0.65

@export_category("Salto")
@export_range(1.0, 2000.0, 1.0) var jump_speed: float = 420.0
@export_range(1.0, 5000.0, 1.0) var gravity: float = 1200.0
@export_range(1.0, 5.0, 0.1) var fall_gravity_multiplier: float = 1.7
@export_range(1.0, 5.0, 0.1) var released_jump_gravity_multiplier: float = 2.5
@export_range(1.0, 3000.0, 1.0) var max_fall_speed: float = 900.0
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.12

@export_category("Dash")
@export_range(1.0, 3000.0, 1.0) var dash_speed: float = 750.0
@export_range(0.01, 1.0, 0.01) var dash_duration: float = 0.16
@export_range(0.0, 5.0, 0.01) var dash_cooldown: float = 0.45

var move_axis: float = 0.0
var facing_direction: float = 1.0
var jump_pressed: bool = false
var jump_held: bool = false
var dash_pressed: bool = false
var attack_pressed: bool = false

var _coyote_remaining: float = 0.0
var _dash_cooldown_remaining: float = 0.0
var _dash_invulnerable: bool = false
var _initialized: bool = false
var level_transition_active: bool = false


func _ready() -> void:
	if not is_instance_valid(state_machine) or state_machine.get_parent() != self:
		push_error("Player: atribua o filho StateMachine no Inspector.")
		return
	if not is_instance_valid(sword_hitbox) or not is_instance_valid(hurtbox) or not is_instance_valid(grappling_hook):
		push_error("Player: atribua SwordHitbox, Hurtbox e GrapplingHook no Inspector.")
		return
	health = max_health
	hurtbox.impacted.connect(_on_impacted)
	for action: StringName in [&"move_left", &"move_right", &"jump", &"dash", &"attack", &"grapple"]:
		if not InputMap.has_action(action):
			push_error("Player: ação ausente no Input Map: %s" % action)
			return
	for child: Node in state_machine.get_children():
		if child is PlayerState:
			(child as PlayerState).setup(self)
	_initialized = state_machine.start()
	if not _initialized:
		push_error("Player: não foi possível iniciar a StateMachine.")


func _unhandled_input(event: InputEvent) -> void:
	if _initialized and not level_transition_active:
		state_machine.handle_input(event)


func _process(delta: float) -> void:
	if _initialized and not level_transition_active:
		state_machine.update(delta)


func _physics_process(delta: float) -> void:
	if not _initialized or level_transition_active:
		return
	if health <= 0.0:
		apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		move_and_slide()
		return
	move_axis = Input.get_axis(&"move_left", &"move_right")
	jump_pressed = Input.is_action_just_pressed(&"jump")
	jump_held = Input.is_action_pressed(&"jump")
	dash_pressed = Input.is_action_just_pressed(&"dash")
	attack_pressed = Input.is_action_just_pressed(&"attack")
	if not is_zero_approx(move_axis):
		facing_direction = signf(move_axis)
	_dash_cooldown_remaining = maxf(0.0, _dash_cooldown_remaining - delta)
	if is_on_floor():
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)
	if _hit_remaining > 0.0:
		_hit_remaining = maxf(0.0, _hit_remaining - delta)
		apply_gravity(delta)
	else:
		state_machine.physics_update(delta)
	if is_invulnerable() or _hit_remaining > 0.0:
		grappling_hook.release()
	else:
		if Input.is_action_just_pressed(&"grapple"):
			grappling_hook.fire_at(get_global_mouse_position())
		if Input.is_action_just_released(&"grapple"):
			grappling_hook.release()
	grappling_hook.physics_update(delta)
	# Impactos recebidos entre ciclos físicos não são anulados pela locomoção.
	velocity += _pending_knockback
	_pending_knockback = Vector2.ZERO
	move_and_slide()
	sword_hitbox.scan_overlaps()


func apply_horizontal_movement(delta: float) -> void:
	var rate := acceleration if not is_zero_approx(move_axis) else deceleration
	if not is_on_floor():
		rate *= air_control
	velocity.x = move_toward(velocity.x, move_axis * move_speed, rate * delta)


## Soltar salto acelera a subida até o ápice; a queda usa outro multiplicador.
func apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		return
	var multiplier: float = 1.0
	if velocity.y >= 0.0:
		multiplier = fall_gravity_multiplier
	elif not jump_held:
		multiplier = released_jump_gravity_multiplier
	velocity.y = minf(velocity.y + gravity * multiplier * delta, max_fall_speed)


## Consome a janela ao saltar: não permite salto duplo durante o coyote time.
func try_jump() -> bool:
	if not is_on_floor() and _coyote_remaining <= 0.0:
		return false
	if velocity.y < 0.0:
		return false
	velocity.y = -jump_speed
	clear_coyote_time()
	return true


func clear_coyote_time() -> void:
	_coyote_remaining = 0.0


func can_dash() -> bool:
	return not _dash_invulnerable and _dash_cooldown_remaining <= 0.0


func start_dash_cooldown() -> void:
	_dash_cooldown_remaining = dash_cooldown


## Hurtbox consulta este getter antes de emitir o impacto.
## Colisões com o cenário permanecem ativas durante o dash.
func is_invulnerable() -> bool:
	return level_transition_active or _dash_invulnerable or health <= 0.0 or _hit_remaining > 0.0


## Cancela ações antes de um fade; o nível mantém a proteção até terminá-lo.
func begin_level_transition() -> void:
	level_transition_active = true
	grappling_hook.release()
	sword_hitbox.end_strike()
	state_machine.transition_to(&"Jump")
	set_dash_invulnerable(false)
	velocity = Vector2.ZERO


## Reposiciona sem recriar o nó nem perder conexões ou durabilidade das próteses.
func reset_at(world_position: Vector2, restore_health: bool = true) -> void:
	grappling_hook.release()
	sword_hitbox.end_strike()
	state_machine.transition_to(&"Jump")
	set_dash_invulnerable(false)
	global_position = world_position
	velocity = Vector2.ZERO
	_pending_knockback = Vector2.ZERO
	_hit_remaining = 0.0
	_coyote_remaining = 0.0
	_dash_cooldown_remaining = 0.0
	move_axis = 0.0
	jump_pressed = false
	jump_held = false
	dash_pressed = false
	attack_pressed = false
	if restore_health:
		health = max_health
		health_changed.emit(health, max_health)


func set_dash_invulnerable(active: bool) -> void:
	if _dash_invulnerable == active:
		return
	_dash_invulnerable = active
	dash_invulnerability_changed.emit(active)


func _on_impacted(damage: float, _damage_type: StringName, knockback: Vector2, _source: Node) -> void:
	health = maxf(0.0, health - damage)
	_hit_remaining = hit_recovery
	_pending_knockback += knockback
	grappling_hook.release()
	sword_hitbox.end_strike()
	state_machine.transition_to(&"Jump")
	health_changed.emit(health, max_health)
	if health <= 0.0:
		velocity += _pending_knockback
		_pending_knockback = Vector2.ZERO
		defeated.emit()
