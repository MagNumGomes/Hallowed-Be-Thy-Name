extends SceneTree
## Verifica ciclo de morte, portais e volumes de memória com física real.

const PLAYER_SCENE := preload("res://features/player/player.tscn")
var _failures: int = 0
var _respawns: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _steps(count: int = 4) -> void:
	for index: int in range(count):
		await physics_frame
		await process_frame


func _trigger(world: Node2D, manager: LevelManager, kind: LevelTrigger.Kind,
		at: Vector2, intensity: float = 0.7) -> LevelTrigger:
	var trigger := LevelTrigger.new()
	trigger.manager = manager
	trigger.kind = kind
	trigger.position = at
	trigger.memory_intensity = intensity
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(80, 100)
	shape.shape = rectangle
	trigger.add_child(shape)
	world.add_child(trigger)
	return trigger


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.gravity = 0.0
	var manager := LevelManager.new()
	manager.player = player
	manager.fade_duration = 0.01
	world.add_child(manager)
	manager.player_respawned.connect(func(_at: Vector2) -> void: _respawns += 1)
	_check(manager.checkpoint_position == Vector2.ZERO, "Sem marcador, spawn inicial deve ser a posição do jogador.")
	var spawn := Marker2D.new()
	spawn.position = Vector2(200, 0)
	world.add_child(spawn)
	var checkpoint := _trigger(world, manager, LevelTrigger.Kind.CHECKPOINT, spawn.position)
	checkpoint.destination = spawn
	checkpoint.checkpoint_id = &"tower"
	player.position = spawn.position
	await _steps()
	_check(manager.checkpoint_id == &"tower", "Entrada física deve ativar checkpoint.")
	player.grappling_hook.try_activate()
	var durability := player.grappling_hook.get_durability()
	player.position = Vector2(400, 0)
	player.hurtbox.receive_hit(999, &"test", Vector2(50, -100), null, &"enemy")
	_check(manager.transitioning, "Morte deve travar transição imediatamente.")
	manager.respawn()
	_check(not manager.transition_to(Vector2.ZERO), "Pedidos concorrentes devem ser rejeitados.")
	await manager.transition_finished
	_check(_respawns == 1 and player.health == player.max_health, "Morte deve produzir um único respawn com vida cheia.")
	_check(player.position == spawn.position and player.velocity == Vector2.ZERO, "Respawn deve limpar posição, velocidade e recuo.")
	_check(not player.level_transition_active and not player.sword_hitbox.active, "Respawn deve liberar controle sem golpe residual.")
	_check(player.grappling_hook.get_durability() == durability, "Respawn deve preservar desgaste.")
	var room := _trigger(world, manager, LevelTrigger.Kind.MEMORY, Vector2(600, 0), 0.4)
	var strong_room := _trigger(world, manager, LevelTrigger.Kind.MEMORY, Vector2(600, 0), 0.9)
	var destination := Marker2D.new()
	destination.position = Vector2(600, 0)
	world.add_child(destination)
	var portal := _trigger(world, manager, LevelTrigger.Kind.TRANSITION, Vector2(400, 0))
	portal.destination = destination
	player.health = 50.0
	player.position = portal.position
	await manager.transition_finished
	_check(player.position == destination.position and player.health == 50, "Portal deve preservar vida e reposicionar.")
	_check(manager.checkpoint_id == &"tower" and is_equal_approx(manager.memory_intensity, 0.9), "Portal deve preservar checkpoint e resolver salas sobrepostas.")
	strong_room.queue_free()
	await _steps()
	_check(is_equal_approx(manager.memory_intensity, 0.4), "Remover sala deve recuperar intensidade da sala restante.")
	manager.memory_effects_strength = 0.0
	_check(is_zero_approx(float(manager._material.get_shader_parameter(&"glitch_intensity"))), "Preferência zero deve desligar glitch.")
	manager.respawn()
	await manager.transition_finished
	_check(manager.memory_intensity == 0.0, "Respawn fora da memória deve limpar shader.")
	room.queue_free()
	var pit := _trigger(world, manager, LevelTrigger.Kind.RESPAWN, Vector2(800, 0))
	player.position = pit.position
	await manager.transition_finished
	_check(_respawns == 3 and player.position == spawn.position, "Volume de queda deve usar checkpoint.")
	world.queue_free()
	await process_frame
	print("LevelManager: %d falha(s)." % _failures)
	quit(0 if _failures == 0 else 1)
