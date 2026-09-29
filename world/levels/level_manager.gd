class_name LevelManager
extends Node
## Ciclo de vida local de um nível. Checkpoints permanecem apenas nesta instância.

signal checkpoint_activated(id: StringName, world_position: Vector2)
signal player_respawned(world_position: Vector2)
signal transition_started()
signal transition_finished()
signal memory_intensity_changed(intensity: float)

const MEMORY_SHADER: Shader = preload("res://features/memories/shaders/glitch_memory.gdshader")

@export var player: Player
@export var initial_spawn: Marker2D
@export_range(0.0, 3.0) var fade_duration: float = 0.3
@export_group("Áudio")
@export var exploration_music: AudioStream
@export var memory_music: AudioStream
@export_range(0.0, 10.0) var music_fade_duration: float = 2.0
@export_group("")
@export_range(0.0, 1.0) var memory_effects_strength: float = 1.0:
	set(value):
		memory_effects_strength = clampf(value, 0.0, 1.0)
		_apply_memory()

var checkpoint_id: StringName = &"start"
var checkpoint_position: Vector2
var transitioning: bool = false
var memory_intensity: float = 0.0
var _rooms: Array[Area2D] = []
var _material: ShaderMaterial
var _fade: ColorRect
var _initialized: bool = false


func _ready() -> void:
	if not is_instance_valid(player):
		push_error("LevelManager: atribua Player no Inspector.")
		return
	if not player.is_node_ready():
		await player.ready
	checkpoint_position = initial_spawn.global_position if is_instance_valid(initial_spawn) else player.global_position
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var memory := ColorRect.new()
	memory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = MEMORY_SHADER
	memory.material = _material
	layer.add_child(memory)
	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	layer.add_child(_fade)
	_apply_memory()
	player.defeated.connect(respawn)
	_initialized = true
	_update_music()


## O marcador inicial define o fallback; não teleporta o jogador ao iniciar.
func activate_checkpoint(id: StringName, world_position: Vector2) -> bool:
	if not _initialized or transitioning or player.health <= 0.0 or id == &"":
		return false
	if checkpoint_id == id and checkpoint_position == world_position:
		return false
	checkpoint_id = id
	checkpoint_position = world_position
	checkpoint_activated.emit(id, world_position)
	return true


## Pode ser chamado também por um volume de queda. Pedidos concorrentes são ignorados.
func respawn() -> void:
	_request_transition(checkpoint_position, true)


## Transição entre telas/salas da mesma cena; preserva vida e checkpoint.
func transition_to(world_position: Vector2) -> bool:
	if not is_instance_valid(player) or player.health <= 0.0:
		return false
	return _request_transition(world_position, false)


func register_memory_room(room: Area2D) -> void:
	if is_instance_valid(room) and not _rooms.has(room):
		_rooms.append(room)


func _physics_process(_delta: float) -> void:
	if _initialized and not transitioning:
		_refresh_memory()


func _refresh_memory() -> void:
	var intensity: float = 0.0
	for index: int in range(_rooms.size() - 1, -1, -1):
		var room := _rooms[index]
		if not is_instance_valid(room):
			_rooms.remove_at(index)
		elif room.overlaps_body(player):
			intensity = maxf(intensity, clampf(float(room.get_meta(&"memory_intensity", 0.7)), 0.0, 1.0))
	if not is_equal_approx(intensity, memory_intensity):
		memory_intensity = intensity
		_apply_memory()
		memory_intensity_changed.emit(intensity)
		_update_music()


func _update_music() -> void:
	# Um nível sem faixas atribuídas não assume controle da música global.
	if exploration_music == null and memory_music == null:
		return
	var stream := memory_music if memory_intensity > 0.0 else exploration_music
	get_node("/root/AudioManager").transition_music(stream, music_fade_duration)


func _apply_memory() -> void:
	if _material != null:
		_material.set_shader_parameter(&"glitch_intensity", memory_intensity * memory_effects_strength)


func _request_transition(destination: Vector2, restore_health: bool) -> bool:
	if not _initialized or transitioning or not is_instance_valid(player):
		return false
	transitioning = true
	player.begin_level_transition()
	# Defere reposicionamento para fora de callbacks de colisão e sinais de combate.
	_run_transition.call_deferred(destination, restore_health)
	return true


func _run_transition(destination: Vector2, restore_health: bool) -> void:
	transition_started.emit()
	await _fade_to(1.0)
	if not is_instance_valid(player):
		await _finish_transition()
		return
	player.reset_at(destination, restore_health)
	var camera := player.get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		camera.reset_smoothing()
	# Aguarda a atualização de overlaps no destino antes de revelar a tela.
	for step: int in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame
	_refresh_memory()
	if restore_health:
		player_respawned.emit(destination)
	await _finish_transition()


func _finish_transition() -> void:
	await _fade_to(0.0)
	if is_instance_valid(player):
		player.level_transition_active = false
	transitioning = false
	transition_finished.emit()


func _fade_to(alpha: float) -> void:
	if fade_duration <= 0.0:
		_fade.color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, fade_duration)
	await tween.finished


func _exit_tree() -> void:
	if transitioning and is_instance_valid(player):
		player.level_transition_active = false
