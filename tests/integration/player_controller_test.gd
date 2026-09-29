extends SceneTree
## Executar: godot --headless --path . --script res://tests/integration/player_controller_test.gd

const PLAYER_SCENE := preload("res://features/player/player.tscn")
const STEP: float = 1.0 / 60.0

class ProbeState extends State:
	var entered: int = 0
	var exited: int = 0
	var reentrant_target: StringName = &""
	var physics_target: StringName = &""

	func enter(_previous: State) -> void:
		entered += 1
		if reentrant_target != &"":
			request_transition(reentrant_target)

	func exit() -> void:
		exited += 1

	func physics_update(_delta: float) -> void:
		if physics_target != &"":
			request_transition(physics_target)

var _failures: int = 0
var _player: Player
var _floor: StaticBody2D


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	_test_machine()
	var world := Node2D.new()
	root.add_child(world)
	_floor = StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000.0, 40.0)
	collider.shape = shape
	_floor.add_child(collider)
	_floor.position.y = 20.0
	world.add_child(_floor)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector2(0.0, -40.0)
	world.add_child(_player)
	_player.set_process(false)
	await _steps(30)
	_check(_player.is_on_floor(), "O jogador deve pousar na plataforma.")
	_check(_player.state_machine.current_state.name == &"Idle", "Pouso deve terminar em Idle.")

	Input.action_press(&"move_right")
	await _steps(12)
	_check(_player.velocity.x > 0.0, "Run deve mover o corpo para a direita.")
	_check(_player.state_machine.current_state.name == &"Run", "Entrada deve selecionar Run.")
	Input.action_release(&"move_right")
	await _steps(12)
	_check(is_zero_approx(_player.velocity.x), "Idle deve desacelerar até parar.")

	# Remover o piso produz saída de borda real, sem teletransportar o jogador.
	_floor.position.y = 1000.0
	await _steps(2)
	_check(not _player.is_on_floor(), "O jogador deve estar no ar.")
	Input.action_press(&"jump")
	await _steps(1)
	_check(_player.velocity.y < -300.0, "Salto durante coyote time deve funcionar.")
	_check(_player.state_machine.current_state.name == &"Jump", "Salto deve selecionar Jump.")
	_check(not _player.try_jump(), "Não deve haver salto duplo.")
	Input.action_release(&"jump")
	await _steps(15)
	_check(not _player.try_jump(), "Coyote consumido não pode reativar após o ápice.")

	# Mesma velocidade inicial: soltar salto deve aplicar maior gravidade.
	_player.velocity.y = -200.0
	_player.jump_held = true
	_player.apply_gravity(STEP)
	var held_velocity := _player.velocity.y
	_player.velocity.y = -200.0
	_player.jump_held = false
	_player.apply_gravity(STEP)
	_check(_player.velocity.y > held_velocity, "Soltar salto deve reduzir a altura.")
	_player.velocity.y = _player.max_fall_speed
	_player.apply_gravity(STEP)
	_check(_player.velocity.y == _player.max_fall_speed, "Queda deve respeitar velocidade terminal.")

	Input.action_press(&"dash")
	await _steps(1)
	_check(_player.state_machine.current_state.name == &"Dash", "Entrada deve selecionar Dash.")
	_check(_player.is_invulnerable(), "Dash deve ativar invulnerabilidade.")
	_check(_player.velocity == Vector2(_player.dash_speed, 0.0), "Dash deve suspender gravidade.")
	_check(not _player.can_dash(), "Dash não pode reentrar.")
	Input.action_release(&"dash")
	await _steps(12)
	_check(not _player.is_invulnerable(), "Fim do dash deve remover invulnerabilidade.")
	_check(not _player.can_dash(), "Cooldown deve continuar após dash.")
	await _steps(30)
	_check(_player.can_dash(), "Cooldown deve liberar novo dash.")

	# Interrupção por outro estado também executa a limpeza de exit().
	_player.state_machine.transition_to(&"Dash")
	_player.state_machine.transition_to(&"Jump")
	_check(not _player.is_invulnerable(), "Interrupção deve remover invulnerabilidade.")
	Input.action_press(&"attack")
	await _steps(1)
	_check(_player.state_machine.current_state.name == &"Attack", "Entrada de ataque no ar deve selecionar Attack.")
	await _steps(30)
	_check(_player.state_machine.current_state.name != &"Attack", "Segurar ataque não deve encadear ou repetir o combo.")
	_check(not _player.sword_hitbox.active, "Fim do ataque por entrada deve limpar a hitbox.")
	Input.action_release(&"attack")
	world.queue_free()
	await process_frame
	print("Player controller: %d falha(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _steps(count: int) -> void:
	for index: int in range(count):
		await physics_frame
		# physics_frame é emitido antes de _physics_process dos nós.
		await process_frame


func _test_machine() -> void:
	var machine := StateMachine.new()
	var first := ProbeState.new()
	var second := ProbeState.new()
	first.name = "First"
	second.name = "Second"
	first.reentrant_target = &"Second"
	machine.add_child(first)
	machine.add_child(second)
	machine.initial_state = first
	root.add_child(machine)
	_check(machine.start(), "Máquina válida deve iniciar.")
	_check(machine.current_state == first, "enter não deve causar transição recursiva.")
	_check(machine.previous_state == null, "Estado anterior inicial deve ser nulo.")
	_check(not machine.start(), "Inicialização duplicada deve ser rejeitada.")
	_check(not machine.transition_to(&"Missing"), "Destino inexistente deve ser rejeitado.")
	_check(not machine.transition_to(&"First"), "Autotransição deve ser rejeitada.")
	second.request_transition(&"Second")
	_check(machine.current_state == first, "Estado inativo não pode solicitar transição.")
	first.physics_target = &"Second"
	machine.physics_update(STEP)
	_check(machine.current_state == second, "Pedido físico deve ser aplicado após callback.")
	_check(machine.previous_state == first, "Máquina deve guardar estado anterior.")
	_check(first.exited == 1 and second.entered == 1, "exit/enter devem ocorrer uma única vez.")
	machine.queue_free()
