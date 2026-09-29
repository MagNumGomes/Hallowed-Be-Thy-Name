extends SceneTree
## godot --headless --path . --script res://tests/integration/enemies_test.gd

const PLAYER_SCENE := preload("res://features/player/player.tscn")
const BASE_SCENE := preload("res://features/enemies/enemy_base.tscn")
const ZEALOT_SCENE := preload("res://features/enemies/zealot_melee.tscn")
const HOLOGRAM_SCENE := preload("res://features/enemies/corrupted_hologram.tscn")
const PROJECTILE_SCENE := preload("res://features/combat/ranged/energy_projectile.tscn")

var _failures: int = 0
var _deaths: int = 0
var _shots: int = 0


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


func _world() -> Node2D:
	var world := Node2D.new()
	root.add_child(world)
	return world


func _player(world: Node2D, at: Vector2) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = at
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	return player


func _wall(world: Node2D, at: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	return wall


func _projectile(world: Node2D, shooter: Node2D = null) -> EnergyProjectile:
	var projectile := PROJECTILE_SCENE.instantiate() as EnergyProjectile
	projectile.speed = 5000.0
	projectile.wobble_amplitude = 0.0
	projectile.configure(shooter, Vector2.RIGHT)
	world.add_child(projectile)
	return projectile


func _run() -> void:
	await _test_perception_and_damage()
	await _test_patrol_and_melee()
	await _test_projectiles()
	await _test_hologram()
	print("Enemies: %d falha(s)." % _failures)
	quit(0 if _failures == 0 else 1)


func _test_perception_and_damage() -> void:
	var world := _world()
	var player := _player(world, Vector2(120, 0))
	var enemy := BASE_SCENE.instantiate() as EnemyBase
	enemy.gravity = 0.0
	world.add_child(enemy)
	var wall := _wall(world, Vector2(60, 0), Vector2(4, 100))
	await _steps()
	_check(enemy.health == 60.0 and enemy.health_bar.value == 60.0, "Base deve iniciar com vida e barra sincronizadas.")
	_check(enemy.target == null, "World deve bloquear a visão mesmo dentro da área.")
	wall.queue_free()
	await _steps()
	_check(enemy.target == player, "Área e raio devem detectar jogador sem obstáculos.")
	player.position.x = 800.0
	await _steps()
	_check(enemy.target == null, "Sair do alcance deve limpar o alvo.")
	player.position.x = 35.0
	player.sword_hitbox.position.x = -30.0
	await _steps()
	player.sword_hitbox.begin_strike(12.0, &"nanotube_slash", Vector2.ZERO, -1.0)
	player.sword_hitbox.scan_overlaps()
	player.sword_hitbox.scan_overlaps()
	_check(enemy.health == 48.0 and enemy.health_bar.value == 48.0, "Espada real deve reduzir vida e barra apenas uma vez.")
	player.sword_hitbox.end_strike()
	_check(not enemy.hurtbox.receive_hit(10, &"test", Vector2.ZERO, player, &"player"), "Recuperação deve rejeitar novo impacto.")
	await _steps(12)
	_check(not enemy.hurtbox.receive_hit(10, &"test", Vector2.ZERO, player, &"enemy"), "Equipe inimiga deve rejeitar fogo amigo.")
	_check(enemy.hurtbox.receive_hit(5, &"test", Vector2(100, -50), player, &"player"), "Hurtbox deve aceitar novo golpe após recuperação.")
	enemy.set_physics_process(false)
	enemy.velocity = Vector2.ZERO
	enemy._physics_process(0.01)
	_check(enemy.velocity.x >= 100 and enemy.velocity.y <= -50, "Recuo não pode ser apagado pela IA.")
	enemy.position = Vector2.ZERO
	enemy.velocity = Vector2.ZERO
	player.position = Vector2(180, 0)
	await _steps()
	_check(player.grappling_hook.fire_at(enemy.position), "Gancho deve aceitar o inimigo real.")
	_check(player.grappling_hook.is_attached(), "Base deve registrar grupo e camada do gancho.")
	player.grappling_hook.physics_update(0.02)
	enemy._physics_process(0.02)
	_check(enemy.position.x > 0, "Puxão deve ter prioridade sobre IA e mover o corpo.")
	player.grappling_hook.release()
	enemy.set_physics_process(true)
	player.queue_free()
	await _steps()
	_check(enemy.target == null, "Remover jogador deve limpar referência sem erro.")
	await _steps(12)
	enemy.defeated.connect(func() -> void: _deaths += 1)
	_check(enemy.hurtbox.receive_hit(999, &"test", Vector2.ZERO, null, &"player"), "Dano letal deve ser aceito.")
	_check(enemy.dead and enemy.health == 0 and not enemy.health_bar.visible, "Morte deve travar ações e ocultar barra imediatamente.")
	_check(not enemy.hurtbox.receive_hit(999, &"test", Vector2.ZERO, null, &"player"), "Morte deve rejeitar dano duplicado.")
	_check(_deaths == 1, "Defeated deve ser emitido uma única vez.")
	await _steps()
	_check(not is_instance_valid(enemy), "Inimigo morto deve sair da árvore.")
	world.queue_free()
	await process_frame


func _test_patrol_and_melee() -> void:
	var world := _world()
	_wall(world, Vector2(0, 26), Vector2(1000, 20))
	var zealot := ZEALOT_SCENE.instantiate() as ZealotMelee
	zealot.patrol_distance = 20.0
	world.add_child(zealot)
	await _steps(24)
	_check(zealot.facing_direction < 0 and absf(zealot.position.x) < 24.0, "Patrulha deve inverter no limite local.")
	var player := _player(world, Vector2(100, 0))
	await _steps(3)
	_check(zealot.state == ZealotMelee.BehaviorState.WINDUP and not zealot.melee_hitbox.active, "Avistar jogador deve preparar golpe sem dano imediato.")
	for index: int in range(90):
		await _steps(1)
		if player.health < player.max_health:
			break
	_check(player.health == 82.0, "Investida deve alcançar jogador e causar 18 de dano.")
	_check(zealot.state == ZealotMelee.BehaviorState.RECOVERY and not zealot.melee_hitbox.active, "Acerto deve encerrar hitbox e iniciar recuperação.")
	await _steps(10)
	_check(player.health == 82.0, "Recuperação não pode repetir dano.")
	zealot.hurtbox.receive_hit(999, &"test", Vector2.ZERO, player, &"player")
	_check(not zealot.melee_hitbox.active, "Morte deve fechar golpe.")
	world.queue_free()
	await process_frame


func _test_projectiles() -> void:
	var world := _world()
	var player := _player(world, Vector2(100, 0))
	var wall := _wall(world, Vector2(50, 0), Vector2(2, 80))
	await _steps()
	var projectile := _projectile(world)
	await _steps(3)
	_check(not is_instance_valid(projectile) and player.health == 100.0, "Projétil rápido deve colidir com parede fina antes da vítima.")
	wall.queue_free()
	await _steps()
	var source := Node2D.new()
	world.add_child(source)
	projectile = _projectile(world, source)
	source.queue_free()
	await _steps(3)
	_check(player.health == 88.0 and not is_instance_valid(projectile), "Projétil deve causar dano uma vez mesmo após remoção da fonte.")
	player._hit_remaining = 0.0
	player.set_dash_invulnerable(true)
	projectile = _projectile(world)
	await _steps(3)
	_check(player.health == 88.0 and not is_instance_valid(projectile), "Dash deve rejeitar dano e consumir projétil no contato.")
	player.set_dash_invulnerable(false)
	# Nascimento dentro de parede também é contato, não uma fuga pela borda.
	wall = _wall(world, Vector2.ZERO, Vector2(8, 80))
	await _steps()
	projectile = _projectile(world)
	await _steps()
	_check(not is_instance_valid(projectile) and player.health == 88.0, "Projétil originado dentro de World deve ser consumido.")
	wall.queue_free()
	player.queue_free()
	await _steps()
	projectile = _projectile(world)
	projectile.wobble_amplitude = 12.0
	projectile._phase = 0.0
	projectile.lifetime = 0.2
	await _steps(2)
	_check(absf(projectile.position.y) > 0.1 and absf(projectile.position.y) <= 24.0, "Instabilidade deve oscilar transversalmente com amplitude limitada.")
	await _steps(15)
	_check(not is_instance_valid(projectile), "Vida útil deve remover projétil sem colisão.")
	world.queue_free()
	await process_frame


func _test_hologram() -> void:
	var world := _world()
	var player := _player(world, Vector2(200, 0))
	var hologram := HOLOGRAM_SCENE.instantiate() as CorruptedHologram
	hologram.attack_windup = 0.05
	hologram.fire_interval = 0.2
	hologram.spread_degrees = 0.0
	world.add_child(hologram)
	hologram.projectile_fired.connect(func(_projectile: EnergyProjectile) -> void: _shots += 1)
	var wall := _wall(world, Vector2(100, 0), Vector2(4, 80))
	await _steps(20)
	_check(_shots == 0, "Holograma não pode disparar através de paredes.")
	var initial_alpha := hologram.visuals.modulate.a
	await _steps(5)
	_check(not is_equal_approx(initial_alpha, hologram.visuals.modulate.a), "Holograma deve oscilar transparência.")
	_check(hologram.health_bar.modulate.a == 1.0 and not hologram.hurtbox.invulnerable, "Transparência não deve afetar barra nem tornar inimigo invulnerável.")
	wall.queue_free()
	await _steps(20)
	_check(_shots >= 1 and _shots <= 2, "Linha de visão deve permitir disparos com cooldown.")
	_check(hologram.position.y == 0.0, "Holograma deve permanecer flutuando.")
	hologram.hurtbox.receive_hit(999, &"test", Vector2.ZERO, player, &"player")
	await _steps(2)
	_check(not is_instance_valid(hologram), "Morte deve remover holograma.")
	var particles := world.get_node_or_null("GlitchDeath") as CPUParticles2D
	_check(is_instance_valid(particles) and particles.one_shot and particles.amount > 0, "Morte deve produzir partículas independentes do inimigo.")
	await _steps(65)
	_check(not is_instance_valid(particles), "Efeito de morte deve se remover após terminar.")
	world.queue_free()
	await process_frame
