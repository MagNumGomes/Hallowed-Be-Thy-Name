extends Node
## Slot único. O carregamento é aplicado pela cena após inicializar o jogador.

const SAVE_PATH := "user://memory.json"
const OPTIONS_PATH := "user://options.cfg"
var pending: Dictionary = {}
var glitch_enabled: bool = true
var volume: float = 0.8


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(OPTIONS_PATH) == OK:
		glitch_enabled = bool(config.get_value("ui", "glitch", true))
		var stored: Variant = config.get_value("audio", "volume", 0.8)
		if (stored is float or stored is int) and is_finite(float(stored)):
			volume = clampf(float(stored), 0.0, 1.0)
	apply_volume()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)


func save_options() -> Error:
	apply_volume()
	var config := ConfigFile.new()
	config.set_value("ui", "glitch", glitch_enabled)
	config.set_value("audio", "volume", volume)
	return config.save(OPTIONS_PATH)


func read_memory() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_length() > 16384:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return {}
	if data.get("version") != 1 or not data.get("scene") is String:
		return {}
	var scene: String = data.scene
	if not scene.begins_with("res://") or not scene.ends_with(".tscn") or not ResourceLoader.exists(scene, "PackedScene"):
		return {}
	for key: String in ["x", "y", "health", "durability", "fragments"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int):
			return {}
		if not is_finite(float(value)) or absf(float(value)) > 1000000000.0:
			return {}
	if data.health <= 0 or data.durability < 0 or data.fragments < 0:
		return {}
	return data


func save_player(player: Player, scene_path: String) -> Error:
	if not is_instance_valid(player) or player.health <= 0 or player.level_transition_active:
		return ERR_UNAVAILABLE
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	var data := {"version": 1, "scene": scene_path,
		"x": player.global_position.x, "y": player.global_position.y,
		"health": player.health, "fragments": player.fragments,
		"durability": player.grappling_hook.get_durability()}
	# Escreve primeiro em arquivo temporário para preservar o slot em caso de falha.
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)


func apply_pending(player: Player) -> void:
	if pending.is_empty():
		return
	player.reset_at(Vector2(pending.x, pending.y), false)
	player.health = clampf(float(pending.health), 1.0, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
	player.fragments = int(pending.fragments)
	player.grappling_hook.restore_durability(int(pending.durability))
	pending = {}
