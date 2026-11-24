extends SceneTree
## Save-state classification and the real acknowledgement flow, using QA files only.
const Profile=preload("res://scripts/profile.gd")
const Prefs=preload("res://scripts/preferences.gd")
const PATH="user://qa_load_notice.json"
const SETTINGS="user://qa_load_notice.cfg"
var game
var failures:=0
var checks:=0
var capture_folder: String=""
var captures: Array=[]

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==1: capture_folder=args[0]
	_run.call_deferred()

func _run() -> void:
	var i18n=root.get_node("I18n")
	var original_locale: String=i18n.current
	i18n.set_language("en",false)
	if not capture_folder.is_empty():
		assert(DisplayServer.get_name()!="headless")
		DirAccess.make_dir_recursive_absolute(capture_folder)
		root.size=Vector2i(1920,1080)
	_clean()
	await _new_game()
	check(game.hud.screen=="menu" and not game.profile.used_defaults_after_damage and not game.preferences.used_defaults_after_damage,"A first launch shows no damage notice")
	await _dispose()
	for damaged_part in ["profile","settings","both"]:
		_clean()
		_seed()
		if damaged_part in ["profile","both"]: _damage(PATH)
		if damaged_part in ["settings","both"]: _damage(SETTINGS)
		await _new_game()
		check(game.profile.recovered_backup==(damaged_part in ["profile","both"]) and game.preferences.recovered_backup==(damaged_part in ["settings","both"]),damaged_part+": the correct data source reports recovery")
		check(game.hud.screen=="load_notice" and game.hud.load_notice_kind=="backup",damaged_part+": a backup notice is visible before play")
		check(game.hud.overlay.get_node("LoadNoticeBody").text==i18n.text("SAVE_RECOVERED_BODY"),damaged_part+": the notice explains possible loss of recent changes")
		var elapsed: float=game.elapsed
		await frames(20)
		check(game.mode=="menu" and game.elapsed==elapsed and not game.player.controls_enabled,damaged_part+": reading the notice does not start or time the journey")
		if damaged_part=="profile":
			await key(KEY_ENTER)
			check(game.hud.screen=="menu" and game.mode=="menu","Enter acknowledges the notice without beginning the journey")
		elif damaged_part=="settings":
			await key(KEY_ESCAPE)
			check(game.hud.screen=="menu" and game.mode=="menu","Escape acknowledges the notice and returns to the title")
		else:
			await joy(JOY_BUTTON_B)
			check(game.hud.screen=="menu" and game.mode=="menu","Controller B acknowledges the notice without starting play")
		check(game.profile.data["unlocked"]==4 and game.preferences.values["music_volume"]==31.0,"Acknowledgement preserves recovered progress and options")
		await _dispose()
	_clean()
	_seed()
	_damage(PATH)
	_damage(PATH+".bak")
	_damage(SETTINGS)
	_damage(SETTINGS+".bak")
	await _new_game()
	check(game.profile.used_defaults_after_damage and game.preferences.used_defaults_after_damage,"Unreadable primary and backup data report the fallback state")
	check(game.hud.screen=="load_notice" and game.hud.load_notice_kind=="defaults","Unreadable data gets a different notice from a restored backup")
	check(game.hud.overlay.get_node("LoadNoticeBody").text==i18n.text("SAVE_DEFAULTS_BODY"),"The fallback notice describes only affected data using starting values")
	await joy(JOY_BUTTON_A)
	check(game.hud.screen=="menu" and game.mode=="menu","Controller A confirms the focused acknowledgement button")
	await key(KEY_ENTER)
	check(game.mode=="chapter","A fresh Enter opens the new journey's story")
	await key(KEY_ENTER)
	await frames(4)
	check(game.mode=="playing" and game.player.is_on_floor(),"A new journey remains playable after acknowledging damage")
	game.pause_run()
	game.set_preference("music_volume",75.0)
	game.profile.load_profile(12)
	game.preferences.load_settings()
	check(not game.profile.recovered_backup and not game.profile.used_defaults_after_damage and not game.preferences.recovered_backup and not game.preferences.used_defaults_after_damage,"Loading repaired primary data clears stale recovery flags")
	for code in ["zh_TW","ja","ko"]:
		i18n.set_language(code,false)
		game.show_title()
		game.hud.show_load_notice("backup")
		await _capture("backup-"+code)
		game.hud.show_load_notice("defaults")
		await _capture("defaults-"+code)
		game.show_title()
		await _capture("title-"+code)
	i18n.set_language(original_locale,false)
	await _dispose()
	_clean()
	if not capture_folder.is_empty():
		var file:=FileAccess.open(capture_folder.path_join("capture-manifest.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"producer":"TQ","packed_resources":not FileAccess.file_exists("res://tests/campaign_test.gd"),"display_backend":DisplayServer.get_name(),"rendering_driver":RenderingServer.get_current_rendering_driver_name(),"captures":captures},"  "))
		file.close()
	print("RECOVERY RESULT: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)

func _seed() -> void:
	var profile=Profile.new(PATH)
	profile.data["unlocked"]=4
	profile.save_profile()
	profile.save_profile()
	var prefs=Prefs.new(SETTINGS)
	prefs.set_option("music_volume",31.0)
	prefs.save_settings()

func _damage(path: String) -> void:
	assert(path.begins_with("user://qa_load_notice"))
	var file:=FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string("{broken" if ".json" in path else "[broken")
	file.close()

func _new_game() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	game.profile_path=PATH
	game.settings_path=SETTINGS
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	await frames(4)

func _dispose() -> void:
	game.audio.stop_all()
	game.queue_free()
	await frames(3)
	OS.delay_msec(200)

func _capture(name: String) -> void:
	if capture_folder.is_empty(): return
	for i in range(3): await process_frame
	RenderingServer.force_draw(false,1.0/60.0)
	var picture:=root.get_texture().get_image()
	check(picture.get_size()==Vector2i(1920,1080),name+": native 1080p capture")
	var saved: Error=picture.save_png(capture_folder.path_join(name+".png"))
	check(saved==OK,name+": screenshot saved")
	captures.append({"file":name+".png","locale":root.get_node("I18n").current,"font":root.get_node("I18n").CJK_FONT.resource_path,"size":[picture.get_width(),picture.get_height()]})

func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.pressed=pressed
		Input.parse_input_event(event)
		for i in range(3): await process_frame

func joy(button: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new()
		event.device=74
		event.button_index=button
		event.pressed=pressed
		Input.parse_input_event(event)
		for i in range(3): await process_frame

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(condition: bool,description: String) -> void:
	checks+=1
	if not condition: failures+=1
	print(("PASS " if condition else "FAIL ")+description)

func _clean() -> void:
	for path in [PATH,SETTINGS]:
		assert(path.begins_with("user://qa_load_notice"))
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
