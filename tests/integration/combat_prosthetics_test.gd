extends SceneTree
## godot --headless --path . --script res://tests/integration/combat_prosthetics_test.gd

const PLAYER_SCENE := preload("res://features/player/player.tscn")

class Enemy extends CharacterBody2D:
	var health: float = 100.0
	var impacts: int = 0
	var last_type: StringName
	var last_impulse: Vector2

	func on_impact(amount: float, kind: StringName, impulse: Vector2, _source: Node) -> void:
		health -= amount
		impacts += 1
		last_type = kind
		last_impulse = impulse

	func _physics_process(_delta: float) -> void:
		move_and_slide()

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _steps(count: int = 3) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame


func _shape(parent: Node, size: Vector2) -> void:
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collider.shape = rectangle
	parent.add_child(collider)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var enemy := Enemy.new()
	enemy.position = Vector2(35, 0)
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	enemy.add_to_group(&"grapple_enemies")
	_shape(enemy, Vector2(16, 32))
	# Duas hurtboxes para a mesma vítima não podem duplicar o dano.
	for index: int in range(2):
		var hurtbox := Hurtbox.new()
		hurtbox.receiver = enemy
		hurtbox.collision_layer = 32
		hurtbox.collision_mask = 0
		_shape(hurtbox, Vector2(16, 32))
		hurtbox.impacted.connect(enemy.on_impact)
		enemy.add_child(hurtbox)
	world.add_child(enemy)
	await _steps()
	_check(player.state_machine.transition_to(&"Attack"), "Attack deve estar registrado na cena.")
	var attack := player.state_machine.current_state as AttackState
	player.sword_hitbox.scan_overlaps()
	_check(enemy.impacts == 0, "Preparação não pode causar dano.")
	player.state_machine.physics_update(0.11)
	player.sword_hitbox.scan_overlaps()
	player.sword_hitbox.scan_overlaps()
	_check(enemy.impacts == 1 and enemy.health == 88.0, "Leve 1 deve acertar apenas uma vez por vítima.")
	_check(enemy.last_type == &"nanotube_slash" and enemy.last_impulse.x > 0.0, "Impacto deve transportar tipo e recuo.")
	player.attack_pressed = true
	player.state_machine.physics_update(0.12)
	_check(not player.sword_hitbox.active, "Recuperação deve fechar a hitbox.")
	player.attack_pressed = false
	player.state_machine.physics_update(0.20)
	_check(attack.combo_index == 1, "Segundo toque deve agendar leve 2.")
	player.state_machine.physics_update(0.11)
	player.sword_hitbox.scan_overlaps()
	_check(enemy.impacts == 2 and enemy.health == 76.0, "Leve 2 deve permitir novo impacto.")
	player.attack_pressed = true
	player.state_machine.physics_update(0.32)
	player.attack_pressed = false
	_check(attack.combo_index == 2, "Terceiro toque deve selecionar pesado.")
	player.state_machine.physics_update(0.23)
	player.sword_hitbox.scan_overlaps()
	_check(enemy.health == 46.0 and enemy.last_type == &"nanotube_heavy", "Pesado deve causar 30 de dano com tipo próprio.")
	player.state_machine.physics_update(0.60)
	_check(player.state_machine.current_state.name == &"Jump" and not player.sword_hitbox.active, "Fim sem piso deve retornar a Jump e limpar hitbox.")
	enemy.position.x = -35.0
	player.facing_direction = -1.0
	player.state_machine.transition_to(&"Attack")
	await _steps()
	player.state_machine.physics_update(0.11)
	player.sword_hitbox.scan_overlaps()
	_check(enemy.impacts == 4 and enemy.last_impulse.x < 0.0, "Virar deve espelhar a área da espada e o recuo.")
	player.state_machine.transition_to(&"Dash")
	_check(not player.sword_hitbox.active, "Interrupção por dash deve fechar o golpe.")
	_check(not player.hurtbox.receive_hit(10, &"physical", Vector2(100, 0), enemy, &"enemy"), "Dash deve rejeitar impactos.")
	player.state_machine.transition_to(&"Jump")
	player.velocity = Vector2.ZERO
	_check(not player.hurtbox.receive_hit(10, &"physical", Vector2.ZERO, enemy, &"player"), "Aliados não causam dano.")
	_check(player.hurtbox.receive_hit(10, &"physical", Vector2(100, -50), enemy, &"enemy"), "Hurtbox deve aceitar dano inimigo.")
	_check(player.health == 90.0, "Impacto deve reduzir a vida do protagonista.")
	player._physics_process(0.01)
	_check(player.velocity.x >= 100.0, "Recuo não pode ser apagado pela locomoção.")
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO

	# Gancho: alvo móvel, parede bloqueadora, âncora, quebra e reparo.
	var hook := player.grappling_hook
	enemy.position = Vector2(180, 0)
	await _steps()
	_check(hook.fire_at(enemy.global_position), "Disparo válido deve ser aceito.")
	_check(hook.is_attached() and hook.get_durability() == 90, "Gancho deve prender inimigo e consumir 10.")
	hook.physics_update(0.02)
	_check(enemy.velocity.x < 0.0, "Gancho deve puxar inimigo em direção ao protagonista.")
	await _steps()
	_check(enemy.position.x < 180.0, "Corpo inimigo deve se deslocar de fato.")
	hook.release()
	enemy.velocity = Vector2.ZERO
	_check(not hook.fire_at(enemy.position) and hook.get_durability() == 90, "Cooldown deve rejeitar disparo sem consumir.")
	hook.physics_update(1.0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(90, 0)
	_shape(wall, Vector2(12, 100))
	world.add_child(wall)
	await _steps()
	_check(hook.fire_at(enemy.position) and not hook.is_attached(), "Parede comum deve bloquear o inimigo sem ancorar.")
	_check(hook.get_durability() == 80, "Disparo bloqueado também consome integridade.")
	wall.add_to_group(&"grapple_anchors")
	hook.physics_update(1.0)
	_check(hook.fire_at(wall.position) and hook.is_attached(), "Ruína marcada deve servir de âncora.")
	hook.physics_update(0.02)
	_check(player.velocity.x > 0.0, "Âncora deve puxar o portador.")
	wall.queue_free()
	await _steps()
	hook.physics_update(0.02)
	_check(not hook.is_attached(), "Remover alvo deve soltar o gancho sem erro.")
	hook.repair(100)
	for index: int in range(9):
		hook.physics_update(1.0)
		_check(hook.fire_at(Vector2(0, -300)), "Disparo sem alvo deve ser aceito e consumir.")
	_check(hook.get_durability() == 10, "Nove disparos devem deixar 10 de integridade.")
	hook.physics_update(1.0)
	_check(hook.fire_at(enemy.position) and hook.is_attached(), "Último disparo deve produzir efeito mesmo ao quebrar.")
	_check(hook.is_broken() and hook.get_durability() == 0, "Integridade zero deve ativar trava.")
	hook.release()
	hook.physics_update(1.0)
	_check(not hook.fire_at(enemy.position), "Trava deve persistir após cooldown.")
	_check(hook.repair(5), "Reparo deve restaurar integridade.")
	_check(hook.fire_at(enemy.position) and hook.get_durability() == 0, "Integridade inferior ao custo permite um último disparo.")
	hook.release()
	world.queue_free()
	await process_frame
	print("Combat/prosthetics: %d falha(s)." % _failures)
	quit(0 if _failures == 0 else 1)
