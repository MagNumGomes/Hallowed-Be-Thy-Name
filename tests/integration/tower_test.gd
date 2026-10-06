extends SceneTree
## Exercita percurso real, colisões, portais e round-trip do progresso.

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func _run() -> void:
	var save := root.get_node("SaveGame")
	var existed := FileAccess.file_exists(save.SAVE_PATH)
	var backup := FileAccess.get_file_as_bytes(save.SAVE_PATH) if existed else PackedByteArray()
	save.pending = {}
	var tower: Node2D = load("res://world/levels/tower.tscn").instantiate()
	root.add_child(tower)
	await _frames(20)
	var player: Player = tower.player
	_check(player.is_on_floor(), "Spawn não está sobre piso")
	_check(tower.enemies.size() == 5, "Encontros ausentes")
	# Desliga IA para medir a acessibilidade geométrica isoladamente.
	for enemy: EnemyBase in tower.enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.reset_at(Vector2(435, 600))
	await _frames(8)
	for step: int in range(3):
		var target_x: float = [545.0, 695.0, 860.0][step]
		Input.action_press("jump")
		Input.action_press("move_right")
		var timeout := 100
		while player.position.x < target_x and timeout > 0:
			await _frames(1)
			timeout -= 1
		Input.action_release("move_right")
		Input.action_release("jump")
		await _frames(25)
		_check(player.is_on_floor() and player.position.y < 560 - step * 50, "Degrau %d inacessível por salto" % step)
		if step < 2:
			var edge: float = [588.0, 748.0][step]
			Input.action_press("move_right")
			timeout = 100
			while player.position.x < edge and timeout > 0:
				await _frames(1)
				timeout -= 1
			Input.action_release("move_right")
			await _frames(4)
	player.reset_at(Vector2(570, 480))
	await _frames(2)
	_check(player.grappling_hook.fire_at(Vector2(690, 360)), "Gancho não dispara")
	_check(player.grappling_hook.is_attached(), "Anel não aceita gancho")
	player.grappling_hook.release()
	for id: int in range(3):
		player.reset_at(tower.RELICS[id])
		await _frames(6)
	_check(tower.collected.size() == 3 and player.fragments == 3, "Relíquias não coletadas por colisão")
	player.reset_at(Vector2(4380, 600))
	await _frames(5)
	tower._use_portal()
	_check(not tower.completed, "Final liberado antes dos combates")
	for enemy: EnemyBase in tower.enemies:
		if is_instance_valid(enemy):
			enemy._on_impacted(1000, &"test", Vector2.ZERO, player)
	await _frames(3)
	tower._use_portal()
	_check(tower.completed, "Final não reconhece objetivos completos")
	player.reset_at(Vector2(1180, 600))
	await _frames(3)
	tower._use_portal()
	await _frames(65)
	_check(tower.room == 1 and player.position.x > 1600, "Portal não muda de setor")
	_check(tower.manager.checkpoint_id == &"1", "Checkpoint de destino não ativado")
	player.health = 1
	tower.manager.respawn()
	await _frames(65)
	_check(player.health == player.max_health and player.position.distance_to(tower.SPAWNS[1]) < 30, "Respawn incorreto")
	var state := {"collected": tower.collected, "defeated": tower.defeated_ids, "checkpoint": 1, "completed": tower.completed}
	_check(save.save_player(player, "res://world/levels/tower.tscn", state) == OK, "Save da torre falhou")
	save.pending = save.read_memory()
	tower.queue_free()
	await _frames(2)
	tower = load("res://world/levels/tower.tscn").instantiate()
	root.add_child(tower)
	await _frames(8)
	_check(tower.collected.size() == 3 and tower.enemies.is_empty() and tower.completed, "Load ressuscitou encontros/relíquias")
	_check(tower.manager.checkpoint_id == &"1", "Load perdeu checkpoint")
	tower.queue_free()
	await _frames(3)
	if existed:
		var file := FileAccess.open(save.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else:
		DirAccess.remove_absolute(save.SAVE_PATH)
	await create_timer(1.5).timeout
	print("Torre: %d falhas" % failures)
	quit(0 if failures == 0 else 1)
