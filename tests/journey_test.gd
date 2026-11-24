extends SceneTree
## Story flow, contextual input prompts, persistent introductions and final payoff.
## Goal overlaps here are fixture-based; route_test --collect proves traversal.
const Profile=preload("res://scripts/profile.gd")
const Beacon=preload("res://scripts/beacon.gd")
const PATH="user://qa_journey_flow.json"
const SETTINGS="user://qa_journey_flow.cfg"
var game
var checks:=0
var failures:=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_clean()
	var i18n=root.get_node("I18n")
	var initial_locale: String=i18n.current
	i18n.set_language("en",false)
	game=load("res://scenes/main.tscn").instantiate()
	game.profile_path=PATH
	game.settings_path=SETTINGS
	root.add_child(game)
	await frames(4)
	await key(KEY_ENTER)
	check(game.mode=="chapter" and game.hud.screen=="chapter","Title Enter opens the first chapter without skipping its story")
	check(not game.player.controls_enabled and game.world.process_mode==Node.PROCESS_MODE_DISABLED,"Chapter story holds gameplay safely")
	var time_before: float=game.elapsed
	await frames(20)
	check(game.elapsed==time_before,"Reading the story does not consume run time")
	check(game.hud.overlay.get_node("ChapterStory").text==i18n.text("STORY_1"),"The first story is localized from the catalog")
	await key(KEY_ENTER)
	check(game.mode=="playing" and game.player.controls_enabled,"A fresh Enter confirms the chapter and begins gameplay")
	var saved=Profile.new(PATH)
	saved.load_profile(12)
	check(saved.chapter_seen(0),"Confirmed chapter introductions persist to disk")
	await frames(4)
	check(game.hud.guide_panel.visible and game.hud.guide_body.text.contains("Space"),"The starting world sign supplies live movement and jump guidance")
	game.rebind_key("jump",KEY_Z)
	await frames(3)
	check(game.hud.guide_body.text.contains("Z"),"Guidance follows a rebound keyboard key")
	var stick:=InputEventJoypadMotion.new()
	stick.axis=JOY_AXIS_LEFT_X
	stick.axis_value=.5
	Input.parse_input_event(stick)
	await frames(3)
	check(game.hud.using_gamepad and game.hud._prompt("jump")=="A" and not game.hud.guide_body.text.contains("Space"),"Controller input switches guidance and ability prompts to controller buttons")
	stick=InputEventJoypadMotion.new()
	stick.axis=JOY_AXIS_LEFT_X
	stick.axis_value=0
	Input.parse_input_event(stick)
	await key(KEY_Z)
	check(not game.hud.using_gamepad and game.hud.guide_body.text.contains("Z"),"Keyboard input restores the rebound keyboard prompts")
	game.pause_run()
	game.profile.data["unlocked"]=11
	game.request_stage(4)
	check(game.mode=="chapter" and game.hud.chapter_index==1,"First entry to chapter two opens its story")
	await key(KEY_ENTER)
	await frames(5)
	check(game.player.air_jump_enabled and game.hud.guide_body.text.contains("Z"),"Second chapter teaches the actual double-jump binding")
	game.play_stage(7)
	await frames(8)
	game.player.respawn(game.stage_data["finish"])
	await frames(6)
	game.next_stage()
	check(game.mode=="chapter" and game.hud.chapter_index==2,"The normal next-stage path opens chapter three's story")
	await key(KEY_ENTER)
	await frames(5)
	check(game.player.dash_enabled and game.hud.guide_body.text.contains("Shift"),"Third chapter teaches the available dash binding")
	game.show_title()
	game.continue_journey()
	await frames(5)
	check(game.mode=="playing" and game.current_level==8,"Continue skips an already confirmed introduction and restores the journey")
	game.play_stage(11)
	await frames(8)
	var beacon=game.world.get_node("Goal")
	check(beacon is Beacon,"The final destination uses the lantern tower")
	game.player.respawn(game.stage_data["finish"])
	await frames(6)
	check(beacon.active and game.mode=="complete" and game.hud.screen=="rekindling","Final overlap starts the beacon-lighting sequence")
	check(game.profile.finished(12),"Completion is saved before the lighting sequence finishes")
	time_before=game.elapsed
	await frames(180)
	check(game.hud.screen=="complete" and beacon.light_progress>=.999 and game.background.dawn>=.999,"The tower lights, dawn returns, and the results screen follows")
	check(game.elapsed==time_before,"The ending sequence does not alter the final time")
	game.next_stage()
	check(game.hud.overlay.get_node("StoryBody").text==i18n.text("ENDING_BODY"),"The standard ending preserves optional collection opportunities")
	for index in range(12):
		game.profile.data["levels"][str(index)]={"relic_ids":[0,1,2],"relics":3,"completed":true}
	game.profile.save_profile()
	game.next_stage()
	check(game.profile.lightseed_count()==36 and game.hud.overlay.get_node("StoryBody").text==i18n.text("ENDING_ALL"),"All thirty-six lightseeds unlock the full collection epilogue")
	game.play_stage(11)
	await frames(8)
	game.set_preference("reduced_motion",true)
	beacon=game.world.get_node("Goal")
	var still_clock: float=beacon.clock
	game.player.respawn(game.stage_data["finish"])
	await frames(6)
	check(beacon.light_progress==1 and beacon.clock==still_clock,"Reduced motion lights the beacon without moving decoration")
	game.show_title()
	await frames(180)
	check(game.mode=="menu" and game.hud.screen=="menu","An old lighting callback cannot replace a later menu")
	game.profile.data["seen_chapters"].erase(1)
	game.request_stage(4)
	await key(KEY_ESCAPE)
	check(game.mode=="menu" and not game.profile.chapter_seen(1),"Leaving a story does not mark an unread chapter as confirmed")
	# Backward compatibility: profiles made before story cards existed.
	var legacy: Dictionary=game.profile.data.duplicate(true)
	legacy.erase("seen_chapters")
	var file:=FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	saved=Profile.new(PATH)
	saved.load_profile(12)
	check(saved.chapter_seen(0) and saved.chapter_seen(1) and saved.chapter_seen(2),"Legacy completed chapters migrate without repeating introductions")
	i18n.set_language(initial_locale,false)
	game.audio.stop_all()
	game.queue_free()
	await frames(4)
	OS.delay_msec(200)
	_clean()
	print("JOURNEY RESULT: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)

func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.physical_keycode=code
		event.keycode=code
		event.pressed=pressed
		Input.parse_input_event(event)
		await frames(2)

func _clean() -> void:
	for path in [PATH,SETTINGS]:
		assert(path.begins_with("user://qa_"))
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(condition: bool,description: String) -> void:
	checks+=1
	if not condition: failures+=1
	print(("PASS " if condition else "FAIL ")+description)
