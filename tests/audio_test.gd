extends SceneTree
## Verifies the actual mixed signal, looping, independent switches and music states.
var game
var capture: AudioEffectCapture
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var save_exists := FileAccess.file_exists("user://qa_audio_test_settings.cfg")
	var saved_bytes := FileAccess.get_file_as_bytes("user://qa_audio_test_settings.cfg") if save_exists else PackedByteArray()
	game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://qa_audio_test.json"
	game.settings_path="user://qa_audio_test_settings.cfg"
	root.add_child(game)
	await frames(40)
	var audio = game.audio
	var player_id: int = audio.music_player.get_instance_id()
	var voice_ids: Dictionary={}
	for key in audio.players: voice_ids[key]=audio.players[key].get_instance_id()
	check(audio.music_player.playing, "Background music starts on the title screen")
	check(absf(audio.music_player.stream.get_length() - 40.0) < 0.01, "Main score is 40 seconds")
	check(audio.music_player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Full-track looping is enabled")
	check(audio.music_player.stream.stereo, "Score uses stereo audio")
	check(audio.music_player.bus == &"Music", "Score is routed to the Music bus")
	game.set_preference("muted",true)
	game.set_preference("music_muted",false)
	game.hud.set_muted(true)
	game.hud.set_music_muted(false)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(0, capture)
	var peak := await capture_peak()
	check(peak > 0.001, "Native audio mixer outputs audible music (peak %.4f)" % peak)
	game.hud.music_button.pressed.emit()
	check(audio.music_muted and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music icon mutes the Music bus")
	check(audio.muted, "Music toggle preserves SFX setting")
	await capture_peak()
	peak = await capture_peak()
	check(peak < 0.00001, "Both muted buses produce silence")
	game.hud.sound_button.pressed.emit()
	check(not audio.muted and audio.music_muted, "SFX switch operates independently")
	audio.play("coin")
	peak = await capture_peak()
	check(peak > 0.001, "Effects remain audible with music disabled")
	var settings := ConfigFile.new()
	settings.load("user://qa_audio_test_settings.cfg")
	check(settings.get_value("settings", "music_muted", false) == true and settings.get_value("settings", "muted", true) == false, "Music and effects preferences are saved separately")
	game.toggle_music()
	game.start_run()
	await frames(90)
	check(audio.context == "playing" and absf(audio.music_player.volume_db + 10) < 0.1, "Gameplay fades to its music level")
	game.pause_run()
	await frames(40)
	check(audio.context == "paused" and absf(audio.music_player.volume_db + 22) < 0.1, "Pause ducks the music")
	game.resume_run()
	await frames(40)
	check(audio.context == "playing" and absf(audio.music_player.volume_db + 10) < 0.1, "Resume restores music level")
	check(audio.music_player.get_instance_id() == voice_ids["woods"], "Gameplay reuses its fixed chapter voice")
	audio.music_player.seek(audio.music_player.stream.get_length()-.06)
	OS.delay_msec(220)
	await frames(3)
	check(audio.music_player.playing and audio.music_player.get_playback_position() < 1, "Music wraps across the end of the track")
	audio.set_context("complete")
	await frames(3)
	check(audio.victory_player.playing and audio.target_music_db == -24, "Completion plays a coda over quieter background music")
	game.show_title()
	await frames(3)
	check(not audio.victory_player.playing and audio.context == "menu", "Return to title stops the coda")
	game.hud.show_language()
	game.hud.overlay.get_node("MusicToggle").pressed.emit()
	check(audio.music_muted, "Music switch is available in language settings")
	game.set_preference("music_muted",false)
	game.set_preference("muted",true)
	game.profile.data["unlocked"]=11
	check(audio.players.size()==4,"The soundtrack has one fixed voice per score")
	var previous: String=audio.active_track
	for index in range(3):
		var expected: String=audio.CHAPTER_TRACKS[index]
		game.play_stage(index*4)
		check(audio.active_track==expected,"Chapter %d selects its own score" % (index+1))
		await frames(25)
		check(float(audio.weights[expected])>0 and float(audio.weights[expected])<1 and audio.players[previous].playing,"Chapter %d crossfades while the outgoing score remains alive" % (index+1))
		var power: float=0
		for value in audio.weights.values(): power+=float(value)
		check(absf(power-1)<.0001,"Chapter %d keeps constant summed fade power" % (index+1))
		peak=await capture_peak()
		check(peak>.001 and peak<.9,"Chapter %d reaches the native mixer without clipping" % (index+1))
		await frames(70)
		var voices:=0
		for voice in audio.players.values():
			if voice.playing: voices+=1
		check(voices==1 and audio.music_player.playing,"Chapter %d stops its fully faded outgoing voices" % (index+1))
		var stream: AudioStreamWAV=audio.music_player.stream
		check(stream.get_length()>70 and stream.stereo and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Chapter %d uses a full-length stereo looping score" % (index+1))
		audio.music_player.seek(stream.get_length()-.06)
		OS.delay_msec(220)
		await frames(3)
		check(audio.music_player.playing and audio.music_player.get_playback_position()<1,"Chapter %d actually wraps at its own track boundary" % (index+1))
		audio.music_player.seek(10)
		OS.delay_msec(50)
		game.play_stage(index*4+1)
		await frames(4)
		check(audio.music_player.get_instance_id()==voice_ids[expected] and audio.music_player.get_playback_position()>9.9,"Chapter %d stage changes preserve score position and voice" % (index+1))
		previous=expected
	# Re-target a still-running fade several times, without resetting current gains.
	var no_gain_jump:=true
	for chapter in [0,1,2,0]:
		var before: Dictionary={}
		for key in audio.players: before[key]=audio.players[key].volume_db
		audio.set_context("playing",chapter)
		for key in audio.players:
			if absf(float(before[key])-audio.players[key].volume_db)>.001: no_gain_jump=false
		await frames(4)
	check(no_gain_jump,"Rapid score requests keep the current gains at each retarget")
	game.show_title()
	await frames(90)
	var pool_stable: bool=audio.players["skybound"].get_instance_id()==player_id
	var loop_count:=0
	for key in audio.players:
		pool_stable=pool_stable and audio.players[key].get_instance_id()==voice_ids[key]
		if audio.players[key].playing: loop_count+=1
	check(pool_stable and loop_count==1 and audio.active_track=="skybound","Interrupted transitions return to one menu score with no extra players")
	game.set_preference("music_muted",true)
	game.play_stage(8)
	await frames(90)
	await capture_peak()
	peak=await capture_peak()
	check(peak<.00001 and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"A muted chapter switch remains silent throughout the music bus")
	game.set_preference("music_volume",20)
	game.set_preference("music_muted",false)
	peak=await capture_peak()
	check(peak>.0001 and absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))-.2)<.001,"All score voices respect the saved music volume")
	game.set_preference("assist",true)
	game.play_stage(4)
	await frames(84)
	check(Engine.time_scale==.8 and audio.fade_elapsed>=audio.CROSSFADE_SECONDS,"Relaxed gameplay does not slow a soundtrack crossfade")
	game.pause_run()
	await frames(40)
	check(audio.active_track=="ruins" and absf(audio.mix_db+22)<.1,"Pause lowers the mix without switching chapter music")
	audio.set_context("complete")
	OS.delay_msec(120)
	await frames(3)
	var coda_at: float=audio.victory_player.get_playback_position()
	audio.set_context("ending")
	OS.delay_msec(80)
	await frames(3)
	check(audio.victory_player.playing and audio.victory_player.get_playback_position()>=coda_at,"The ending lets the existing completion coda finish without replaying it")
	audio.stop_all()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	game.queue_free()
	await frames(3)
	OS.delay_msec(180)
	await frames(3)
	if save_exists:
		var file := FileAccess.open("user://qa_audio_test_settings.cfg", FileAccess.WRITE)
		file.store_buffer(saved_bytes)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_audio_test_settings.cfg"))
	print("AUDIO RESULT: %d/%d passed" % [checks - failures, checks])
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_audio_test.json" + suffix))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_audio_test_settings.cfg"+suffix))
	quit(1 if failures else 0)

func capture_peak() -> float:
	capture.clear_buffer()
	OS.delay_msec(160)
	await frames(2)
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS " if condition else "FAIL ") + description)
