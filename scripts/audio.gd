extends Node
## A fixed pool crossfades original chapter scores, independent of gameplay time.
const TRACKS := {"skybound":"res://assets/music/skybound.wav","woods":"res://assets/music/moss_and_fireflies.wav","ruins":"res://assets/music/steps_of_amber.wav","stars":"res://assets/music/a_path_through_stars.wav"}
const CHAPTER_TRACKS := ["woods","ruins","stars"]
const CROSSFADE_SECONDS := 1.25

var muted: bool = false:
	set(value):
		muted = value
		_set_bus_muted("SFX", value)
var music_muted: bool = false:
	set(value):
		music_muted = value
		_set_bus_muted("Music", value)
var sounds: Dictionary = {}
var music_player: AudioStreamPlayer
var victory_player: AudioStreamPlayer
var context: String = "menu"
var target_music_db: float = -13.0
var mix_db: float=-55.0
var mix_from_db: float=-55.0
var mix_elapsed: float=0.0
var chapter: int=0
var active_track: String="skybound"
var players: Dictionary={}
var weights: Dictionary={}
var fade_from: Dictionary={}
var positions: Dictionary={}
var fade_elapsed: float=CROSSFADE_SECONDS
var running: bool=false

func _exit_tree() -> void:
	stop_all()
	sounds.clear()

func stop_all() -> void:
	running=false
	for voice in get_children():
		if voice is AudioStreamPlayer:
			if voice.has_meta("score_key"): positions[voice.get_meta("score_key")]=voice.get_playback_position()
			voice.stop()

func _ready() -> void:
	sounds["jump"] = _tone(340, 650, 0.11, 0.16)
	sounds["coin"] = _tone(920, 1500, 0.14, 0.13)
	sounds["death"] = _tone(230, 80, 0.26, 0.16)
	sounds["checkpoint"] = _tone(520, 1040, 0.33, 0.13)
	sounds["finish"] = _tone(660, 1320, 0.65, 0.13)
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_set_bus_muted("Music", music_muted)
	_set_bus_muted("SFX", muted)
	for key in TRACKS:
		var track:=load(TRACKS[key]) as AudioStreamWAV
		if track==null:
			push_error("Cannot load score: "+key)
			continue
		track.loop_mode=AudioStreamWAV.LOOP_FORWARD
		track.loop_begin=0
		track.loop_end=int(round(track.get_length()*track.mix_rate))
		var voice:=AudioStreamPlayer.new()
		voice.name="Score_"+key
		voice.bus=&"Music"
		voice.stream=track
		voice.volume_db=-80.0
		voice.set_meta("score_key",key)
		add_child(voice)
		players[key]=voice
		weights[key]=1.0 if key==active_track else 0.0
		positions[key]=0.0
	if not players.has(active_track): return
	music_player=players[active_track]
	victory_player = AudioStreamPlayer.new()
	victory_player.name = "VictoryMusic"
	victory_player.bus = &"Music"
	victory_player.stream = load("res://assets/music/victory.wav")
	victory_player.volume_db = -8.0
	add_child(victory_player)
	music_player.play()
	running=true
	fade_from=weights.duplicate()
	_apply_music_mix()

func set_context(value: String,chapter_index: int=-1) -> void:
	var changed := context != value
	if chapter_index>=0: chapter=clampi(chapter_index,0,2)
	context = value
	_apply_music_mix()
	_select_track("skybound" if context=="menu" else CHAPTER_TRACKS[chapter])
	if not is_instance_valid(victory_player):
		return
	if not context in ["complete","ending"]:
		victory_player.stop()
	elif context=="complete" and changed and not music_muted:
		victory_player.play()

func _apply_music_mix() -> void:
	match context:
		"playing": target_music_db = -10.0
		"paused": target_music_db = -22.0
		"complete": target_music_db = -24.0
		"ending": target_music_db = -21.0
		"chapter": target_music_db = -16.0
		_: target_music_db = -13.0
	mix_from_db=mix_db
	mix_elapsed=0

func _select_track(key: String) -> void:
	if not players.has(key) or (key==active_track and running): return
	active_track=key
	music_player=players[key]
	if not music_player.playing: music_player.play(float(positions[key]))
	fade_from=weights.duplicate()
	fade_elapsed=0
	running=true

func _process(delta: float) -> void:
	if not running: return
	# Soundtrack transitions keep real duration when relaxed mode slows physics.
	var real_delta:=delta/maxf(Engine.time_scale,.01)
	mix_elapsed=minf(.55,mix_elapsed+real_delta)
	mix_db=lerpf(mix_from_db,target_music_db,smoothstep(0,.55,mix_elapsed))
	fade_elapsed=minf(CROSSFADE_SECONDS,fade_elapsed+real_delta)
	var blend:=smoothstep(0,CROSSFADE_SECONDS,fade_elapsed)
	for key in players:
		weights[key]=lerpf(float(fade_from[key]),1.0 if key==active_track else 0.0,blend)
		var voice: AudioStreamPlayer=players[key]
		var gain:=sqrt(float(weights[key]))
		voice.volume_db=mix_db+linear_to_db(gain) if gain>.00001 else -80.0
		if fade_elapsed>=CROSSFADE_SECONDS and key!=active_track and voice.playing:
			positions[key]=voice.get_playback_position()
			voice.stop()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")

func _set_bus_muted(bus_name: String, value: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_mute(index, value)

func set_volumes(music_percent: float, effects_percent: float) -> void:
	for item in [["Music",music_percent],["SFX",effects_percent]]:
		var index:=AudioServer.get_bus_index(item[0])
		if index>=0:
			var gain: float=clampf(float(item[1])/100.0,0,1)
			AudioServer.set_bus_volume_db(index,-80.0 if gain<=0 else linear_to_db(gain))

func play(sound_name: String) -> void:
	if muted or not sounds.has(sound_name):
		return
	var voice := AudioStreamPlayer.new()
	voice.bus = &"SFX"
	voice.stream = sounds[sound_name]
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func _tone(from_hz: float, to_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / samples
		phase += TAU * lerpf(from_hz, to_hz, t) / sample_rate
		var envelope := sin(PI * t) * (1.0 - t)
		var value := (sin(phase) + sin(phase * 2) * 0.12) * envelope * volume
		data.encode_s16(i * 2, int(value * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream
