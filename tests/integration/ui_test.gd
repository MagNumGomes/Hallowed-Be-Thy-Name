extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var save := root.get_node("SaveGame")
	var had_save := FileAccess.file_exists(save.SAVE_PATH)
	var backup := FileAccess.get_file_as_bytes(save.SAVE_PATH) if had_save else PackedByteArray()
	var demo: Node = load("res://world/levels/ui_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var player: Player = demo.get_node("Player")
	var hud: GameHUD = demo.get_node("HUD")
	player.health = 42.0
	player.health_changed.emit(42.0, player.max_health)
	player.fragments = 17
	player.grappling_hook.restore_durability(10)
	_check(hud.health_bar.value == 42, "HUD não acompanha vida")
	_check(hud.get_node("%Fragments").text.ends_with("000017"), "HUD não acompanha fragmentos")
	_check("RUPTURA" in hud.get_node("%ProstheticStatus").text, "Aviso ausente")
	_check(save.save_player(player, "res://world/levels/ui_demo.tscn") == OK, "Falha ao salvar")
	_check(save.save_player(player, "res://world/levels/ui_demo.tscn") == OK, "Falha ao substituir slot")
	var memory: Dictionary = save.read_memory()
	_check(not memory.is_empty(), "Save válido rejeitado")
	player.fragments = 0
	player.grappling_hook.restore_durability(0)
	_check("QUEBRADA" in hud.get_node("%ProstheticStatus").text, "Estado quebrado ausente")
	save.pending = memory
	save.apply_pending(player)
	_check(player.fragments == 17 and player.health == 42 and player.grappling_hook.get_durability() == 10, "Round-trip perdeu estado")
	var replacement := ProstheticBase.new()
	demo.add_child(replacement)
	hud.set_active_prosthetic(replacement, "TESTE")
	player.grappling_hook.restore_durability(0)
	_check(hud.durability_bar.value == 100, "Prótese anterior controla HUD")
	var file := FileAccess.open(save.SAVE_PATH, FileAccess.WRITE)
	file.store_string('{"version":1,"scene":5}')
	file.close()
	_check(save.read_memory().is_empty(), "Save inválido aceito")
	var menu: Node = load("res://features/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check(menu.get_node("%Load").disabled, "Slot inválido habilitado")
	menu.get_node("%Options").pressed.emit()
	_check(menu.get_node("%OptionsPanel").visible, "Opções não abriu")
	menu.queue_free()
	demo.queue_free()
	await process_frame
	if had_save:
		file = FileAccess.open(save.SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else:
		DirAccess.remove_absolute(save.SAVE_PATH)
	print("UI: %d falhas" % failures)
	quit(0 if failures == 0 else 1)
