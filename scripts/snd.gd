extends Node
## Sonido y música, como en el juego web. Se usa como autoload "Snd".
## - Efectos: sintetizados por capas para el estilo HD (tools/sfx arma los .wav de assets/audio/sfx; los
##   jsfxr del juego web quedaron en assets/audio/sfx_original), con un poco de variación de tono.
## - Música: la misma canción en distintos "ánimos" (assets/audio/music), exportados del original con su
##   tempo, tono y canales. Los cambios entran a tiempo, cada medio compás, y siguen en el mismo compás.
##   En peligro (te queda un corazón) suena apagada, como debajo del agua.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const STEPS := 128  # pasos de 1/16 en las 8 vueltas de la canción
const MUSIC_VOL := 0.5
const MOODS := {
	"titulo": 96, "cartas": 104, "z0": 132, "z1": 136, "z2": 140, "intro": 120,
	"jefe": 148, "furia": 168, "final": 186, "respiro": 112, "derrota": 72, "victoria": 150,
}

var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_bus := 0
var _lp: AudioEffectLowPassFilter
var _mood := ""
var _want := ""
var _streams := {}
var _loading: Array = []  # músicas que se cargan en segundo plano desde que arranca el juego
var _duck := 1.0
var _lp_target := 20000.0
var enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus(_music_bus)
	AudioServer.set_bus_name(_music_bus, "Musica")
	AudioServer.set_bus_send(_music_bus, "Master")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_music_bus, _lp)
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(MUSIC_VOL))
	var sfx_bus := AudioServer.bus_count
	AudioServer.add_bus(sfx_bus)
	AudioServer.set_bus_name(sfx_bus, "Efectos")
	AudioServer.set_bus_send(sfx_bus, "Master")
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(0.9))
	for n in ["salto", "aterrizar", "disparo", "tajo", "clavar", "acierto", "critico", "moneda", "pisoton",
			"explotar", "dano", "alerta", "porton", "metal", "rugido", "huesos", "baba", "posesion", "dash",
			"escudo", "cargado", "poder", "oleada", "menu", "derrota", "boom", "paso"]:
		var path: String = SFX_DIR + n + ".wav"
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
	for i in 20:
		var p := AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musica"
	add_child(_music)
	# todas las músicas se cargan en segundo plano: cargarlas al cambiar de ánimo (la del jefe al entrar
	# al castillo) frenaba el juego un momento
	for m in MOODS:
		var path: String = MUSIC_DIR + m + ".ogg"
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			_loading.append(m)


## play("disparo", {"rate": 1.2, "vol": 0.5, "delay": 0.1, "vary": false})
func play(name: String, o: Dictionary = {}) -> void:
	if not enabled or not _sfx.has(name):
		return
	var delay: float = o.get("delay", 0.0)
	if delay > 0.0:
		get_tree().create_timer(delay, true, false, true).timeout.connect(_play_now.bind(name, o))
	else:
		_play_now(name, o)


func _play_now(name: String, o: Dictionary) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	var rate: float = o.get("rate", 1.0)
	if o.get("vary", true):
		rate *= 1.0 + randf_range(-0.07, 0.07)
	p.stream = _sfx[name]
	p.pitch_scale = maxf(0.05, rate)
	p.volume_db = linear_to_db(maxf(0.001, o.get("vol", 1.0)))
	p.play()


## El bombo grave de los golpes fuertes.
func boom(vol: float = 0.95) -> void:
	play("boom", {"vol": vol, "vary": false})


## Baja la música un instante (críticos, furia del jefe).
func duck() -> void:
	_duck = 0.16


# ---------------------------------------------------------------- música

## Pide un ánimo ("z0", "jefe", "" para silencio). danger = te queda poca vida.
func mood(name: String, danger: bool = false) -> void:
	_lp_target = 1500.0 if danger else 20000.0
	if name == _want:
		return
	_want = name
	if name == "":
		_music.stop()
		_mood = ""
		return
	if not _music.playing:
		_switch(0)


func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		_keep(name, load(MUSIC_DIR + name + ".ogg"))
	return _streams[name]


func _keep(name: String, s: Resource) -> void:
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_streams[name] = s
	_loading.erase(name)


func _collect() -> void:
	for i in range(_loading.size() - 1, -1, -1):
		var m: String = _loading[i]
		var path: String = MUSIC_DIR + m + ".ogg"
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_keep(m, ResourceLoader.load_threaded_get(path))
		elif st != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_loading.remove_at(i)


func _spb(name: String) -> float:
	return 60.0 / float(MOODS.get(name, 132)) / 4.0


func _switch(step: int) -> void:
	_mood = _want
	var s := _stream(_mood)
	if s == null:
		return
	_music.stream = s
	_music.play(float(step % STEPS) * _spb(_mood))


func _process(dt: float) -> void:
	if not _loading.is_empty():
		_collect()
	_duck = minf(1.0, _duck + dt * 1.1)
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(MUSIC_VOL * _duck))
	_lp.cutoff_hz = lerpf(_lp.cutoff_hz, _lp_target, minf(1.0, dt * 3.0))
	if _want == "" or _want == _mood or not _music.playing:
		if _want != "" and not _music.playing:
			_switch(0)
		return
	# el cambio entra cuando arranca el próximo medio compás (cada 8 pasos)
	var pos := _music.get_playback_position() + AudioServer.get_time_since_last_mix()
	var step := pos / _spb(_mood)
	var nxt := (floori(step / 8.0) + 1) * 8
	if float(nxt) - step < dt / _spb(_mood) + 0.05:
		_switch(nxt)
