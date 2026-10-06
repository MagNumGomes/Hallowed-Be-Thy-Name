extends Node2D
## Primeiro percurso da torre: vestíbulo, arsenal e câmara de memória.

const ACTOR_VISUAL = preload("res://features/player/tower_actor_visual.gd")
const SOUND = preload("res://world/levels/tower_sound.gd")
const TITLES := ["01 / VESTÍBULO DOS ESQUECIDOS", "02 / ARSENAL DOS DEVOTOS", "03 / MEMÓRIA DO COMBATENTE"]
const SPAWNS := [Vector2(120, 580), Vector2(1730, 580), Vector2(3330, 580)]
const RELICS := [Vector2(1040, 440), Vector2(2630, 425), Vector2(4240, 440)]
var player: Player
var manager: LevelManager
var camera: Camera2D
var heading: Label
var objective: Label
var notice: Label
var platforms: Array[Rect2] = []
var anchors: Array[Vector2] = []
var collected: Array[int] = []
var defeated_ids: Array[int] = []
var enemies: Array[EnemyBase] = []
var room: int = -1
var completed: bool = false
var chime: AudioStreamWAV
var impact: AudioStreamWAV
var swing: AudioStreamWAV
var notice_time: float = 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("080e18"))
	chime = SOUND.tone(660, 0.7)
	impact = SOUND.tone(90, 0.18)
	swing = SOUND.tone(220, 0.12)
	var saved: Dictionary = SaveGame.pending.get("world", {}) if SaveGame.pending.get("world", {}) is Dictionary else {}
	collected = _read_ids(saved.get("collected", []), 3)
	defeated_ids = _read_ids(saved.get("defeated", []), 5)
	completed = saved.get("completed", false) == true
	_build_geometry()
	player = preload("res://features/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = SPAWNS[0]
	player.get_node("Visuals").set_script(ACTOR_VISUAL)
	add_child(player)
	SaveGame.apply_pending(player)
	# O slot pode ter sido editado ou gravado durante uma queda.
	if player.position.y > 640 or player.position.y < 0 or player.position.x < 40 or player.position.x > 4440:
		player.reset_at(SPAWNS[0])
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8
	player.add_child(camera)
	manager = LevelManager.new()
	manager.name = "LevelManager"
	manager.player = player
	manager.memory_effects_strength = 0.22 if SaveGame.glitch_enabled else 0.0
	manager.exploration_music = SOUND.tone(55, 4, true)
	manager.memory_music = SOUND.tone(82, 4, true)
	add_child(manager)
	var checkpoint := clampi(int(saved.get("checkpoint", 0)), 0, 2) if saved.get("checkpoint", 0) is float or saved.get("checkpoint", 0) is int else 0
	manager.activate_checkpoint(StringName(str(checkpoint)), SPAWNS[checkpoint])
	_build_interface()
	manager.checkpoint_activated.connect(_checkpoint)
	manager.player_respawned.connect(func(_at: Vector2) -> void: _message("MEMÓRIA RESTAURADA · Retorno ao último santuário"))
	manager.transition_finished.connect(_finish_arrival)
	player.get_node("StateMachine/Attack").strike_started.connect(func(_index: int) -> void: AudioManager.play_sfx(swing, -10))
	player.hurtbox.impacted.connect(func(_a: float, _k: StringName, _i: Vector2, _s: Node) -> void: AudioManager.play_sfx(impact, -6))
	player.grappling_hook.fired.connect(func(_end: Vector2, attached: bool) -> void: AudioManager.play_sfx(chime if attached else swing, -16))
	_build_encounters()
	_build_triggers()
	_update_room()
	_message("A torre ainda se lembra de você. Encontre os três fragmentos.")

func _build_geometry() -> void:
	for sector: int in range(3):
		var x := sector * 1600.0
		_platform(Rect2(x, 620, 1280, 100))
		_solid(Rect2(x - 30, -100, 30, 850))
		_solid(Rect2(x + 1280, -100, 30, 850))
		# Degraus de 50 px: alcançáveis mesmo sem a prótese.
		_platform(Rect2(x + 480, 570, 130, 18))
		_platform(Rect2(x + 630, 520, 140, 18))
		_platform(Rect2(x + 805, 470, 290, 20))
		_anchor(Vector2(x + 690, 360))
		_anchor(Vector2(x + 990, 320))
		_world_label(Vector2(x + 70, 270), TITLES[sector], 24, Color("ac9770"))
		_world_label(Vector2(x + 70, 305), ["Toda ascensão exige uma lembrança.", "A fé sobreviveu aos seus criadores.", "Não era um deus. Era um de nós."][sector], 15, Color("708690"))
		_world_label(Vector2(x + 70, 540), "SANTUÁRIO / R reparar", 13, Color("75d9c8"))
		_world_label(Vector2(x + 610, 390), "Mire no anel · segure E", 14, Color("75d9c8"))
		_world_label(Vector2(x + 1090, 525), "W / subir" if sector < 2 else "W / recordar", 15, Color("dcc694"))
		if sector > 0:
			_world_label(Vector2(x + 40, 480), "W / voltar", 14, Color("ac9770"))

func _solid(rect: Rect2, layer: int = 1) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _platform(rect: Rect2) -> void:
	platforms.append(rect)
	_solid(rect)

func _anchor(at: Vector2) -> void:
	anchors.append(at)
	var body := _solid(Rect2(at - Vector2(16, 16), Vector2(32, 32)), 8)
	body.add_to_group("grapple_anchors")

func _world_label(at: Vector2, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	add_child(label)

func _build_encounters() -> void:
	var positions := [Vector2(770, 599), Vector2(2210, 599), Vector2(2580, 440), Vector2(3860, 599), Vector2(4210, 440)]
	for id: int in range(5):
		if id in defeated_ids:
			continue
		var ranged := id == 2 or id == 4
		var scene: PackedScene = preload("res://features/enemies/corrupted_hologram.tscn") if ranged else preload("res://features/enemies/zealot_melee.tscn")
		var enemy := scene.instantiate() as EnemyBase
		enemy.position = positions[id]
		enemy.get_node("Visuals").set_script(ACTOR_VISUAL)
		enemy.set_meta("sector", int(positions[id].x / 1600))
		add_child(enemy)
		enemies.append(enemy)
		enemy.defeated.connect(func() -> void:
			defeated_ids.append(id)
			AudioManager.play_sfx(impact, -8)
			_update_objective()
		)
		if enemy is CorruptedHologram:
			enemy.projectile_fired.connect(func(_projectile: EnergyProjectile) -> void: AudioManager.play_sfx(swing, -18, 0.12, &"Glitch"))

func _area(at: Vector2, size: Vector2) -> Area2D:
	var area := Area2D.new()
	area.position = at
	area.collision_layer = 0
	area.collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	return area

func _build_triggers() -> void:
	for sector: int in range(3):
		var checkpoint := _area(SPAWNS[sector], Vector2(90, 80))
		checkpoint.body_entered.connect(func(body: Node2D) -> void:
			if body == player:
				manager.activate_checkpoint(StringName(str(sector)), SPAWNS[sector])
		)
		if sector not in collected:
			var relic := _area(RELICS[sector], Vector2(34, 44))
			relic.body_entered.connect(func(body: Node2D) -> void:
				if body == player and sector not in collected:
					collected.append(sector)
					player.fragments += 1
					AudioManager.play_sfx(chime, -5)
					_message(["FRAGMENTO I · Nós construímos a torre para guardar os nomes.", "FRAGMENTO II · As máquinas aprenderam a rezar antes de aprender a morrer.", "FRAGMENTO III · O combatente esquecido tinha o seu rosto."][sector])
					_update_objective()
					relic.queue_free()
					queue_redraw()
			)
	var memory := _area(Vector2(4000, 400), Vector2(800, 440))
	memory.set_meta("memory_intensity", 0.35)
	manager.register_memory_room(memory)

func _build_interface() -> void:
	var hud := preload("res://features/ui/hud.tscn").instantiate() as GameHUD
	hud.player = player
	add_child(hud)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -880
	panel.offset_right = -24
	panel.offset_top = 24
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.07, 0.94)
	style.border_color = Color("53645e")
	style.border_width_top = 1
	style.content_margin_left = 24
	style.content_margin_top = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	heading = Label.new()
	heading.modulate = Color("d3bc89")
	column.add_child(heading)
	objective = Label.new()
	column.add_child(objective)
	notice = Label.new()
	notice.modulate = Color("8be4d0")
	column.add_child(notice)
	var help := Label.new()
	help.text = "A/D mover · Espaço pular · Shift dash · J atacar · E + mouse gancho\nW portal · R reparar · F5 salvar · Esc menu"
	help.add_theme_font_size_override("font_size", 13)
	column.add_child(help)

func _checkpoint(_id: StringName, _at: Vector2) -> void:
	_repair()
	_message("SANTUÁRIO ATIVADO · Vida e prótese restauradas · F5 registra o progresso")

func _read_ids(value: Variant, count: int) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item: Variant in value:
			if (item is int or item is float) and is_finite(float(item)) and item >= 0 and item < count and float(item) == floor(float(item)):
				if not result.has(int(item)):
					result.append(int(item))
	return result

func _finish_arrival() -> void:
	_update_room()
	# Overlaps são atualizados durante o fade, quando o manager ainda rejeita checkpoints.
	if player.position.distance_to(SPAWNS[room]) < 80:
		manager.activate_checkpoint(StringName(str(room)), SPAWNS[room])

func _repair() -> void:
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.grappling_hook.restore_durability(player.grappling_hook.get_max_durability())
	AudioManager.play_sfx(chime, -12)

func _message(text: String) -> void:
	notice.text = text
	notice_time = 7.0

func _update_room() -> void:
	room = clampi(int(player.position.x / 1600), 0, 2)
	camera.limit_left = room * 1600
	camera.limit_right = room * 1600 + 1280
	camera.limit_top = 0
	camera.limit_bottom = 720
	camera.reset_smoothing()
	heading.text = TITLES[room]
	for enemy: EnemyBase in enemies:
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT if enemy.get_meta("sector") == room else Node.PROCESS_MODE_DISABLED
	_update_objective()

func _update_objective() -> void:
	if not is_instance_valid(objective):
		return
	objective.text = "TORRE RESTAURADA · Percurso concluído · Esc para retornar" if completed else "Recupere as memórias: %d/3 · Combatentes libertados: %d/5" % [collected.size(), defeated_ids.size()]

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if clampi(int(player.position.x / 1600), 0, 2) != room:
		_update_room()
	if player.position.y > 760:
		manager.respawn()
	notice_time = maxf(0, notice_time - delta)
	notice.modulate.a = minf(1, notice_time)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://features/ui/main_menu.tscn")
	if not event is InputEventKey or not event.pressed or event.echo or manager.transitioning or player.health <= 0:
		return
	match event.physical_keycode:
		KEY_F5:
			var state := {"collected": collected, "defeated": defeated_ids, "checkpoint": int(String(manager.checkpoint_id)), "completed": completed}
			var error := SaveGame.save_player(player, scene_file_path, state)
			_message("MEMÓRIA REGISTRADA" if error == OK else "FALHA AO REGISTRAR (%d)" % error)
		KEY_R:
			if player.position.distance_to(SPAWNS[room]) < 100:
				_repair()
				_message("VIDA E PRÓTESE RESTAURADAS")
			else:
				_message("Aproxime-se de um santuário para reparar.")
		KEY_W:
			_use_portal()

func _use_portal() -> void:
	var local_x := player.position.x - room * 1600
	if player.position.y < 510:
		return
	if local_x < 90 and room > 0:
		manager.transition_to(Vector2((room - 1) * 1600 + 1120, 580))
	elif local_x > 1100:
		if room < 2:
			manager.transition_to(SPAWNS[room + 1])
		elif collected.size() == 3 and defeated_ids.size() == 5:
			completed = true
			_update_objective()
			_message("SEU NOME FOI DEVOLVIDO À TORRE · Fim do primeiro percurso · F5 salvar")
			AudioManager.play_sfx(chime)
		else:
			_message("O altar exige três memórias e a libertação dos cinco guardiões.")

func _draw() -> void:
	for sector: int in range(3):
		var x := sector * 1600.0
		draw_rect(Rect2(x, 0, 1280, 720), Color("0b1420"))
		# Alvenaria, contrafortes e vitrais da catedral-máquina.
		for row: int in range(12):
			for col: int in range(17):
				var brick := Rect2(x + col * 80 - (40 if row % 2 else 0), row * 54, 78, 52)
				draw_rect(brick, Color("101c29") if (row + col) % 3 else Color("13202b"))
		for col: int in range(6):
			var cx := x + 80 + col * 220
			draw_rect(Rect2(cx - 28, 40, 56, 580), Color("192832"))
			draw_rect(Rect2(cx - 20, 44, 8, 570), Color("23343c"))
			draw_rect(Rect2(cx - 36, 584, 72, 36), Color("2b3b40"))
			var arch := PackedVector2Array([Vector2(cx + 45, 360), Vector2(cx + 45, 150), Vector2(cx + 80, 95), Vector2(cx + 115, 150), Vector2(cx + 115, 360)])
			draw_colored_polygon(arch, Color("183a43") if sector != 2 else Color("30243f"))
			draw_polyline(arch, Color("455250"), 3, true)
			draw_line(Vector2(cx + 80, 110), Vector2(cx + 80, 360), Color("526059"), 2)
			for bar: int in range(3):
				draw_line(Vector2(cx + 47, 200 + bar * 50), Vector2(cx + 113, 200 + bar * 50), Color("364d51"), 2)
		# Santuário e porta de elevador.
		draw_circle(Vector2(x + 120, 580), 36, Color(0.15, 0.65, 0.58, 0.12))
		draw_arc(Vector2(x + 120, 580), 25, 0, TAU, 32, Color("76d9c5"), 2, true)
		draw_rect(Rect2(x + 109, 564, 22, 56), Color("456164"))
		draw_line(Vector2(x + 120, 558), Vector2(x + 120, 596), Color("abffe0"), 3)
		draw_rect(Rect2(x + 1130, 440, 100, 180), Color("303c42"))
		draw_rect(Rect2(x + 1140, 451, 80, 169), Color("081019"))
		for bar: int in range(5):
			draw_line(Vector2(x + 1148 + bar * 16, 455), Vector2(x + 1148 + bar * 16, 616), Color("7c7259"), 2)
		draw_circle(Vector2(x + 1180, 432), 9, Color("ddbb79"))
	for rect: Rect2 in platforms:
		draw_rect(rect, Color("28383e"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("849181"))
		for i: int in range(int(rect.size.x / 36)):
			draw_line(rect.position + Vector2(i * 36, 5), rect.position + Vector2(i * 36, rect.size.y), Color("17262e"), 2)
	for at: Vector2 in anchors:
		draw_line(Vector2(at.x, 0), at, Color("4c615c"), 2)
		draw_circle(at, 24, Color(0.2, 0.9, 0.8, 0.08))
		draw_arc(at, 14, 0, TAU, 32, Color("8bf2d6"), 3, true)
		draw_circle(at, 4, Color("e0ffe5"))
	for id: int in range(3):
		if id not in collected:
			var at: Vector2 = RELICS[id]
			draw_circle(at, 22, Color(0.95, 0.7, 0.3, 0.1))
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -14), at + Vector2(9, 0), at + Vector2(0, 14), at + Vector2(-9, 0)]), Color("f5d298"))

func _exit_tree() -> void:
	AudioManager.stop_music(0.3)
