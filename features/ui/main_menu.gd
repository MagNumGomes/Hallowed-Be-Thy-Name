extends Control

const UI_THEME = preload("res://features/ui/decayed_theme.gd")
@export_file("*.tscn") var game_scene: String = "res://world/levels/ui_demo.tscn"
var _opening: bool = false


func _ready() -> void:
	theme = UI_THEME.create()
	%Start.pressed.connect(_start_game)
	%Load.pressed.connect(_load_game)
	%Options.pressed.connect(_show_options)
	%Quit.pressed.connect(func() -> void: get_tree().quit())
	%Back.pressed.connect(_close_options)
	%Glitch.button_pressed = SaveGame.glitch_enabled
	%Volume.value = SaveGame.volume
	%Glitch.toggled.connect(_toggle_glitch)
	%Volume.value_changed.connect(_change_volume)
	_toggle_glitch(SaveGame.glitch_enabled)
	var memory := SaveGame.read_memory()
	%Load.disabled = memory.is_empty() or memory.get("scene") != game_scene
	%Status.text = "MEMÓRIA AUSENTE OU INCOMPATÍVEL" if %Load.disabled else "MEMÓRIA RECUPERÁVEL"
	%Start.grab_focus()


func _start_game() -> void:
	SaveGame.pending = {}
	_open_game(game_scene)


func _load_game() -> void:
	var memory := SaveGame.read_memory()
	if memory.is_empty() or memory.get("scene") != game_scene:
		%Status.text = "FALHA: MEMÓRIA AUSENTE OU CORROMPIDA"
		return
	SaveGame.pending = memory
	_open_game(game_scene)


func _open_game(path: String) -> void:
	if _opening:
		return
	_opening = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_opening = false
		SaveGame.pending = {}
		%Status.text = "FALHA AO ABRIR CENA (%d)" % error


func _show_options() -> void:
	%MainButtons.hide()
	%OptionsPanel.show()
	%Glitch.grab_focus()


func _close_options() -> void:
	var error := SaveGame.save_options()
	%Status.text = "OPÇÕES REGISTRADAS" if error == OK else "FALHA AO SALVAR OPÇÕES (%d)" % error
	%OptionsPanel.hide()
	%MainButtons.show()
	%Options.grab_focus()


func _toggle_glitch(enabled: bool) -> void:
	SaveGame.glitch_enabled = enabled
	(%Title.material as ShaderMaterial).set_shader_parameter("enabled", enabled)


func _change_volume(value: float) -> void:
	SaveGame.volume = value
	SaveGame.apply_volume()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and %OptionsPanel.visible:
		_close_options()
		get_viewport().set_input_as_handled()
