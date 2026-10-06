extends RefCounted
## PCM original gerado localmente; sem dependências ou assets externos.

static func tone(frequency: float, duration: float, ambient: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i: int in count:
		var t := float(i) / stream.mix_rate
		var envelope := 0.12 if ambient else sin(PI * float(i) / count) * exp(-5.0 * t / duration) * 0.5
		var wave := sin(TAU * frequency * t) + sin(TAU * frequency * 1.5 * t) * 0.3
		bytes.encode_s16(i * 2, int(wave * envelope * 24000))
	stream.data = bytes
	if ambient:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
