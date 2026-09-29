extends Node
## Música persistente e vozes pontuais. O volume de Master pertence a SaveGame.

const MAX_SFX_VOICES: int = 24
var _music: Array[AudioStreamPlayer] = []
var _fades: Dictionary = {}
var _sfx: Array[AudioStreamPlayer] = []
var _target: AudioStream
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.randomize()


## null faz fade out para silêncio. Repetir o destino não reinicia a faixa.
## Os recursos BGM devem ter loop ativado na importação.
func transition_music(stream: AudioStream, duration: float = 2.0) -> void:
	if stream == _target:
		return
	_target = stream
	var incoming: AudioStreamPlayer
	for voice: AudioStreamPlayer in _music:
		if voice.stream == stream:
			incoming = voice
	if stream != null and incoming == null:
		incoming = AudioStreamPlayer.new()
		incoming.bus = &"BGM"
		incoming.stream = stream
		incoming.volume_db = -80.0
		add_child(incoming)
		_music.append(incoming)
		incoming.play()
	# Interrompe os tweens mantendo o ganho atual, inclusive ao voltar à mesma área.
	for voice: AudioStreamPlayer in _music.duplicate():
		if _fades.has(voice):
			(_fades[voice] as Tween).kill()
			_fades.erase(voice)
		var gain: float = 1.0 if voice == incoming else 0.0
		if duration <= 0.0:
			_set_gain(gain, voice)
			_finish_fade(voice, voice != incoming)
		else:
			var tween := create_tween()
			_fades[voice] = tween
			tween.tween_method(_set_gain.bind(voice), db_to_linear(voice.volume_db), gain, duration)
			tween.tween_callback(_finish_fade.bind(voice, voice != incoming))


func stop_music(duration: float = 2.0) -> void:
	transition_music(null, duration)


func _set_gain(gain: float, voice: AudioStreamPlayer) -> void:
	voice.volume_db = linear_to_db(maxf(gain, 0.0001))


func _finish_fade(voice: AudioStreamPlayer, remove: bool) -> void:
	_fades.erase(voice)
	if remove:
		_music.erase(voice)
		voice.stop()
		voice.queue_free()


## WAV/OGG sem loop. Variação 0.04 equivale a pitch entre 0.96 e 1.04.
## Retorna null se não houver recurso ou se a rota não for SFX/Glitch.
func play_sfx(stream: AudioStream, volume_db: float = 0.0,
		pitch_variation: float = 0.04, bus: StringName = &"SFX") -> AudioStreamPlayer:
	if stream == null or (bus != &"SFX" and bus != &"Glitch"):
		return null
	if _sfx.size() >= MAX_SFX_VOICES:
		var oldest: AudioStreamPlayer = _sfx.pop_front()
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.bus = bus
	voice.volume_db = volume_db
	var spread := clampf(pitch_variation, 0.0, 0.15)
	voice.pitch_scale = _random.randf_range(1.0 - spread, 1.0 + spread)
	add_child(voice)
	_sfx.append(voice)
	voice.finished.connect(func() -> void:
		_sfx.erase(voice)
		voice.queue_free()
	)
	voice.play()
	return voice
