extends SceneTree
const Prefs=preload("res://scripts/preferences.gd")
const SETTINGS="user://qa_preferences.cfg"
const JOURNEY="user://qa_preferences_journey.json"
var game
var checks: int=0
var failures: int=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_clean(SETTINGS)
	_clean(JOURNEY)
	var legacy:=ConfigFile.new()
	legacy.set_value("settings","muted",true)
	legacy.set_value("settings","music_muted",true)
	legacy.set_value("records","best_seconds",12.5)
	legacy.set_value("legacy","keep","TQ")
	legacy.save(SETTINGS)
	await _new_game()
	check(game.audio.muted and game.audio.music_muted,"Legacy mute choices survive settings migration")
	check(game.preferences.values["music_volume"]==75,"Missing volume has a validated default")
	game.set_preference("music_muted",false)
	game.set_preference("music_volume",25.0)
	game.set_preference("sfx_volume",80.0)
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))-.25)<.001,"Music volume reaches its actual audio bus")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))-.8)<.001,"Effects volume is independent")
	game.hud.show_settings()
	var slider=game.hud.overlay.get_node("Volume_music_volume")
	var slider_id: int=slider.get_instance_id()
	slider.value=22
	check(game.preferences.values["music_volume"]==22,"Settings slider updates the saved value")
	check(game.hud.overlay.get_node("Value_music_volume").text=="22%","Volume percentage updates immediately")
	check(game.hud.overlay.get_node("Volume_music_volume").get_instance_id()==slider_id,"Dragging a slider does not rebuild or lose the control")
	game.hud.overlay.get_node("Toggle_vsync").pressed.emit()
	check(not game.preferences.values["vsync"],"VSync toggle updates its setting")
	game.hud.overlay.get_node("Toggle_reduced_motion").pressed.emit()
	var before: float=game.background.clock
	await frames(10)
	check(game.background.reduced_motion and game.background.clock==before,"Reduced motion freezes decorative background animation")
	check(game.hud.hud_art.reduced_motion,"Reduced motion reaches the UI decorations")
	game.hud.overlay.get_node("ControlsButton").pressed.emit()
	game.hud.overlay.get_node("Bind_jump").pressed.emit()
	_send_key(KEY_Z,true)
	await frames(3)
	_send_key(KEY_Z,false)
	check(game.preferences.bindings["jump"]==KEY_Z and game.hud.pending_action.is_empty(),"Keyboard capture rebinds jump through the real input event")
	check(game.hud.overlay.get_node("Bind_jump").text=="Z","Binding label reflects the selected key")
	check(game.preferences.rebind("jump",KEY_D)==ERR_ALREADY_IN_USE,"Duplicate primary keys are rejected")
	check(game.preferences.rebind("jump",KEY_ENTER)==ERR_UNAVAILABLE,"Menu safety keys are reserved")
	game.hud._back_controls()
	game.hud._back_settings()
	game.start_run()
	await frames(7)
	_send_key(KEY_Z,true)
	await frames(4)
	check(game.player.velocity.y<0,"The rebound key actually makes the player jump")
	_send_key(KEY_Z,false)
	await frames(55)
	_send_key(KEY_SPACE,true)
	await frames(3)
	check(game.player.is_on_floor(),"The old primary key no longer triggers jump")
	_send_key(KEY_SPACE,false)
	game.preferences.rebind("move_left",KEY_W)
	var w:=InputEventKey.new()
	w.physical_keycode=KEY_W
	check(InputMap.event_is_action(w,"move_left") and not InputMap.event_is_action(w,"jump"),"A new primary takes priority over another action's convenience key")
	var joy:=InputEventJoypadButton.new()
	joy.button_index=JOY_BUTTON_A
	check(InputMap.event_is_action(joy,"jump"),"Controller jump remains bound after keyboard changes")
	game.pause_run()
	game.hud.show_settings()
	game.hud.overlay.get_node("ControlsButton").pressed.emit()
	game.hud.overlay.get_node("ResetBindings").pressed.emit()
	check(game.preferences.bindings==Prefs.PRIMARY,"Reset restores all default keyboard bindings")
	game.hud.overlay.get_node("Bind_jump").pressed.emit()
	_send_key(KEY_ESCAPE,true)
	await frames(2)
	_send_key(KEY_ESCAPE,false)
	check(game.hud.pending_action.is_empty() and game.hud.screen=="controls","Escape cancels a capture without leaving its menu")
	game.profile.complete(0,42.0,0,0,12)
	game.set_preference("assist",true)
	check(Engine.time_scale==1,"Paused menus stay responsive in relaxed mode")
	game.start_run()
	await frames(60)
	check(Engine.time_scale==.8 and game.run_assisted,"Relaxed mode actually slows gameplay and marks the run")
	check(game.elapsed>.9 and game.elapsed<1.2,"Elapsed time compensates for slow motion")
	game.set_preference("assist",false)
	check(Engine.time_scale==1 and game.run_assisted,"Disabling assistance does not clear the run's assisted status")
	game.pause_run()
	game.audio.stop_all()
	game.queue_free()
	await frames(3)
	OS.delay_msec(180)
	await _new_game()
	check(game.preferences.values["music_volume"]==22 and game.preferences.values["sfx_volume"]==80,"Volume choices survive a fresh game instance")
	check(not game.preferences.values["vsync"] and game.preferences.values["reduced_motion"],"Video and motion choices survive a fresh game instance")
	check(game.save_data.get_value("legacy","keep","")=="TQ" and game.save_data.get_value("records","best_seconds",0)==12.5,"Saving new settings preserves legacy sections")
	game.continue_journey()
	await frames(5)
	check(game.run_assisted and not game.preferences.values["assist"],"Continue restores the assisted run marker independently of the current option")
	game.player.respawn(game.stage_data["finish"])
	await frames(6)
	var record: Dictionary=game.profile.level_record(0)
	check(record.get("best_time",0)==42.0 and float(record.get("assist_time",0))>0,"Assisted completion never replaces the ordinary record")
	check(game.hud.assisted and game.mode=="complete","Completion UI retains the assisted indicator")
	var fresh=Prefs.new(SETTINGS)
	fresh.load_settings()
	check(fresh.values["music_volume"]==22,"The on-disk settings can be loaded independently")
	check(fresh.set_option("music_volume",999)==OK and fresh.values["music_volume"]==100,"Out-of-range volume is clamped")
	check(fresh.set_option("assist","wrong type")==ERR_INVALID_PARAMETER,"Invalid option types are rejected")
	# Recover a previous valid generation when the main settings file is missing.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	var recovered=Prefs.new(SETTINGS)
	recovered.load_settings()
	check(recovered.recovered_backup and recovered.values["music_volume"]==22,"A missing primary settings file recovers its validated backup")
	var damaged:=ConfigFile.new()
	damaged.set_value("settings","assist","invalid")
	damaged.set_value("settings","music_volume",-10)
	damaged.set_value("bindings","jump",KEY_ESCAPE)
	damaged.save(SETTINGS)
	var sanitized=Prefs.new(SETTINGS)
	sanitized.load_settings()
	check(not sanitized.values["assist"] and sanitized.values["music_volume"]==0,"Malformed saved options fall back or clamp safely")
	check(sanitized.bindings["jump"]==KEY_SPACE and sanitized.bindings["pause"]==KEY_ESCAPE,"Saved bindings cannot steal Escape from the menu")
	game.audio.stop_all()
	game.queue_free()
	await frames(3)
	OS.delay_msec(180)
	Engine.time_scale=1
	_clean(SETTINGS)
	_clean(JOURNEY)
	print("SETTINGS RESULT: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)

func _new_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.settings_path=SETTINGS
	game.profile_path=JOURNEY
	root.add_child(game)
	await frames(3)

func _send_key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)

func _clean(path: String) -> void:
	assert(path.begins_with("user://qa_"))
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(condition: bool,description: String) -> void:
	checks+=1
	if not condition: failures+=1
	print(("PASS " if condition else "FAIL ")+description)
