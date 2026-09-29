extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _tone(loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.mix_rate = 8000
	stream.data = PackedByteArray()
	var samples := PackedByteArray()
	samples.resize(800)
	stream.data = samples
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = 800
	return stream


func _run() -> void:
	var audio := root.get_node("AudioManager")
	for bus: StringName in [&"Master", &"BGM", &"SFX", &"Glitch"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "Bus ausente: " + bus)
	var exploration := _tone(true)
	var memory := _tone(true)
	audio.transition_music(exploration, 0.0)
	var original: AudioStreamPlayer = audio._music[0]
	audio.transition_music(memory, 0.2)
	await create_timer(0.05).timeout
	var gain := original.volume_db
	audio.transition_music(exploration, 0.1)
	_check(original.volume_db == gain, "Inverter fade deve preservar ganho atual.")
	paused = true
	await create_timer(0.2).timeout
	paused = false
	_check(audio._music.size() == 1 and audio._music[0] == original, "Retorno deve reutilizar voz e limpar saída durante pausa.")
	_check(is_zero_approx(original.volume_db), "Destino deve chegar ao ganho nominal.")
	audio.transition_music(exploration, 0.1)
	_check(audio._music.size() == 1, "Destino repetido não duplica vozes.")
	var shot := _tone(false)
	for index: int in range(30):
		var voice: AudioStreamPlayer = audio.play_sfx(shot, -4.0, 0.04, &"Glitch")
		_check(voice.pitch_scale >= 0.96 and voice.pitch_scale <= 1.04, "Pitch fora da margem.")
		_check(voice.bus == &"Glitch", "Estática deve usar Glitch.")
	_check(audio._sfx.size() == 24, "Polifonia deve ser limitada.")
	await create_timer(0.4).timeout
	_check(audio._sfx.is_empty(), "SFX terminados devem liberar vozes.")
	audio.stop_music(0.05)
	await create_timer(0.1).timeout
	_check(audio._music.is_empty(), "Fade para silêncio deve remover BGM.")
	_check(audio.play_sfx(null) == null, "Asset ausente deve ser ignorado.")
	print("audio_manager_test: %d falhas" % _failures)
	quit(0 if _failures == 0 else 1)
