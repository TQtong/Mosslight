extends Node2D
## Coordinates the run. Actor scripts only report events; this owns score/state.

const PlayerActor = preload("res://scripts/player.gd")
const Island = preload("res://scripts/platform.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Spikes = preload("res://scripts/spikes.gd")
const Marker = preload("res://scripts/marker.gd")
const Burst = preload("res://scripts/burst.gd")
const Layout = preload("res://scripts/level_layout.gd")
const Scenery = preload("res://scripts/background.gd")
const Interface = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/audio.gd")
const SAVE_FILE := "user://mosslight.cfg"
const Campaign = preload("res://scripts/campaign.gd")
const Profile = preload("res://scripts/profile.gd")
const Relic = preload("res://scripts/relic.gd")
const Patrol = preload("res://scripts/patrol.gd")
const Spring = preload("res://scripts/spring.gd")
const NativeQA = preload("res://scripts/native_qa.gd")
const Preferences = preload("res://scripts/preferences.gd")
const Guidepost=preload("res://scripts/guidepost.gd")
const Beacon=preload("res://scripts/beacon.gd")
const PlatformQA=preload("res://scripts/qa_platform.gd")
@export var profile_path: String = Profile.DEFAULT_PATH
@export var settings_path: String = Preferences.DEFAULT_PATH
var profile
var preferences
var run_assisted: bool = false
var windowed_size := Vector2i(1152,648)
var windowed_position := Vector2i.ZERO
var current_level: int = 0
var stage_data: Dictionary = Campaign.stage(0)
var collected_coin_ids: Array = []
var collected_relic_ids: Array = []
var checkpoint_index: int = -1
var save_warning_shown: bool = false

var world: Node2D
var player: CharacterBody2D
var camera: Camera2D
var background: Node2D
var hud: CanvasLayer
var audio: Node
var mode: String = "menu"
var coins: int = 0
var deaths: int = 0
var elapsed: float = 0.0
var best_seconds: float = 0.0
var respawn_at: Vector2 = Layout.SPAWN
var respawn_left: float = 0.0
var checkpoint_active: bool = false
var save_data := ConfigFile.new()
var quitting: bool = false
var pending_restore: bool=false
var guideposts: Array=[]
var finish_sequence: int=0

func _ready() -> void:
	var arguments:=OS.get_cmdline_user_args()
	var platform_qa: bool="--qa-platform" in arguments or "--qa-soak" in arguments
	var native_qa: bool="--qa-smoke" in arguments or "--qa-capture" in arguments or platform_qa
	if native_qa:
		profile_path="user://qa_platform_launch.json" if platform_qa else "user://qa_native_launch.json"
		settings_path="user://qa_platform_launch.cfg" if platform_qa else "user://qa_native_launch.cfg"
	get_tree().auto_accept_quit = false
	Input.joy_connection_changed.connect(_joy_connection_changed)
	I18n.changed.connect(_update_window_title)
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_min_size(Vector2i(960,540))
	_update_window_title()
	preferences=Preferences.new(settings_path)
	preferences.load_settings()
	save_data=preferences.config
	_configure_inputs()
	best_seconds = float(save_data.get_value("records", "best_seconds", 0.0))
	profile = Profile.new(profile_path)
	profile.load_profile(Campaign.COUNT)
	if profile_path == Profile.DEFAULT_PATH and not FileAccess.file_exists(profile_path) and best_seconds > 0:
		profile.complete(0,best_seconds,0,0,Campaign.COUNT)
	if profile_path==Profile.DEFAULT_PATH:
		current_level=int(profile.data["last_level"])
		stage_data=Campaign.stage(current_level)
		respawn_at=stage_data["spawn"]
		best_seconds=float(profile.level_record(current_level).get("assist_time" if bool(preferences.values["assist"]) else "best_time",0))
	audio = Sound.new()
	audio.name = "Sound"
	audio.muted = bool(save_data.get_value("settings", "muted", false))
	audio.music_muted = bool(save_data.get_value("settings", "music_muted", false))
	add_child(audio)
	var scenery_layer := CanvasLayer.new()
	scenery_layer.layer = -10
	add_child(scenery_layer)
	background = Scenery.new()
	scenery_layer.add_child(background)
	hud = Interface.new()
	hud.name = "HUD"
	add_child(hud)
	hud.start_requested.connect(continue_journey)
	hud.restart_requested.connect(start_run)
	hud.pause_requested.connect(pause_run)
	hud.resume_requested.connect(resume_run)
	hud.menu_requested.connect(show_title)
	hud.mute_requested.connect(toggle_sound)
	hud.music_requested.connect(toggle_music)
	hud.quit_requested.connect(quit_game)
	hud.stage_requested.connect(request_stage)
	hud.chapter_requested.connect(begin_chapter)
	hud.next_requested.connect(next_stage)
	hud.credits_requested.connect(show_credits)
	hud.setting_requested.connect(set_preference)
	hud.binding_requested.connect(rebind_key)
	hud.bindings_reset_requested.connect(reset_bindings)
	hud.configure_preferences(preferences)
	hud.set_muted(audio.muted)
	hud.set_music_muted(audio.music_muted)
	_refresh_campaign_ui()
	_create_world()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	player.controls_enabled = false
	_apply_preferences()
	hud.show_menu(best_seconds)
	hud.update_run(coins, Layout.coins().size(), elapsed, deaths, 0)
	if profile.used_defaults_after_damage or preferences.used_defaults_after_damage:
		hud.show_load_notice("defaults")
	elif profile.recovered_backup or preferences.recovered_backup:
		hud.show_load_notice("backup")
	if native_qa:
		var folder: String=""
		var capture_arg: int=arguments.find("--qa-platform" if platform_qa else "--qa-capture")
		if capture_arg>=0 and capture_arg+1<arguments.size(): folder=arguments[capture_arg+1]
		if platform_qa:
			var duration:=0
			var soak_arg: int=arguments.find("--qa-soak")
			if soak_arg>=0 and soak_arg+1<arguments.size(): duration=clampi(int(arguments[soak_arg+1]),60,1800)
			PlatformQA.run(self,folder,duration)
		else: NativeQA.run(self,folder)

func _process(delta: float) -> void:
	if mode == "playing":
		elapsed += delta / maxf(Engine.time_scale,.01)
		if respawn_left > 0:
			respawn_left -= delta
			if respawn_left <= 0:
				player.respawn(respawn_at)
				camera.position.x = respawn_at.x
				camera.reset_smoothing()
		camera.position.x = clampf(player.position.x + 130, 640, int(stage_data["width"]) - 640)
		var progress := clampf((player.position.x - stage_data["spawn"].x) / (stage_data["finish"].x - stage_data["spawn"].x), 0, 1)
		hud.update_run(coins, stage_data["coins"].size(), elapsed, deaths, progress)
		_update_guidance()
	background.camera_x = camera.get_screen_center_position().x
	var goal=world.get_node_or_null("Goal")
	background.dawn=goal.light_progress if goal is Beacon and goal.active else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F11:
		set_preference("fullscreen",not bool(preferences.values["fullscreen"]))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if mode == "playing":
			pause_run()
		elif mode == "paused":
			resume_run()
		elif mode in ["ending","credits"]:
			show_title()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry") and mode == "playing":
		player.die()
	elif event.is_action_pressed("mute"):
		toggle_sound()
	elif event.is_action_pressed("music"):
		toggle_music()
	elif event.is_action_pressed("begin"):
		if mode == "menu" and hud.screen=="menu":
			continue_journey()
		elif mode == "complete" and hud.screen=="complete":
			next_stage()
		elif mode=="chapter": begin_chapter()

func continue_journey() -> void:
	request_stage(int(profile.data["last_level"]),true)

func request_stage(index: int,restore_run: bool=false) -> void:
	if index<0 or index>int(profile.data["unlocked"]) or index>=Campaign.COUNT: return
	current_level=index
	if profile.chapter_seen(index/4):
		start_run(restore_run)
		return
	pending_restore=restore_run
	stage_data=Campaign.stage(index)
	respawn_at=stage_data["spawn"]
	_create_world()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	player.controls_enabled=false
	mode="chapter"
	_apply_preferences()
	audio.set_context("chapter",index/4)
	hud.show_chapter(index/4)

func begin_chapter() -> void:
	if mode!="chapter": return
	profile.remember_chapter(current_level/4)
	_check_save_error()
	start_run(pending_restore)

func play_stage(index: int) -> void:
	if index<0 or index>int(profile.data["unlocked"]) or index>=Campaign.COUNT:
		return
	current_level = index
	start_run()

func next_stage() -> void:
	if current_level >= Campaign.COUNT-1:
		mode = "ending"
		audio.set_context("ending",2)
		hud.show_ending(profile.lightseed_count())
		return
	request_stage(current_level+1)

func show_credits() -> void:
	var from_ending: bool=mode in ["ending","complete"] and current_level==Campaign.COUNT-1
	mode = "credits"
	world.process_mode = Node.PROCESS_MODE_DISABLED
	audio.set_context("ending" if from_ending else "menu")
	hud.show_credits()

func start_run(restore_run: bool = false) -> void:
	finish_sequence+=1
	profile.remember_chapter(current_level/4)
	stage_data = Campaign.stage(current_level)
	coins = 0
	deaths = 0
	elapsed = 0.0
	respawn_left = 0.0
	checkpoint_active = false
	respawn_at = stage_data["spawn"]
	collected_coin_ids = []
	collected_relic_ids = profile.level_record(current_level).get("relic_ids",[]).duplicate()
	checkpoint_index = -1
	run_assisted=bool(preferences.values["assist"])
	var active: Dictionary = profile.data["active_run"]
	if restore_run and not active.is_empty() and int(active.get("level",-1))==current_level:
		for coin_id in active["coins"]:
			if int(coin_id)>=0 and int(coin_id)<stage_data["coins"].size() and not int(coin_id) in collected_coin_ids: collected_coin_ids.append(int(coin_id))
		for relic_id in active["relics"]:
			if int(relic_id)>=0 and int(relic_id)<3 and not int(relic_id) in collected_relic_ids: collected_relic_ids.append(int(relic_id))
		coins = collected_coin_ids.size()
		elapsed = clampf(float(active.get("elapsed",0)),0,86400)
		deaths = int(active.get("deaths",0))
		checkpoint_index = clampi(int(active.get("checkpoint",-1)),-1,stage_data["checkpoints"].size()-1)
		checkpoint_active = checkpoint_index>=0
		run_assisted=run_assisted or bool(active.get("assisted",false))
		if checkpoint_active: respawn_at=stage_data["checkpoints"][checkpoint_index]+Vector2(30,0)
	else:
		profile.begin_level(current_level)
	_create_world()
	mode = "playing"
	audio.set_context("playing",int(stage_data["chapter"]))
	_apply_preferences()
	player.controls_enabled = true
	hud.clear_overlay()
	hud.toast_left = 0
	hud.clear_guide()
	hud.set_checkpoint(checkpoint_active)
	_refresh_campaign_ui()
	_check_save_error()
	# Release menu focus so gamepad/keyboard movement doesn't navigate a button.
	get_viewport().gui_release_focus()

func pause_run(reason: String="") -> void:
	if mode != "playing":
		return
	mode = "paused"
	audio.set_context("paused")
	_apply_preferences()
	_persist_run()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_pause(reason)

func resume_run() -> void:
	if mode != "paused":
		return
	mode = "playing"
	audio.set_context("playing")
	_apply_preferences()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	hud.clear_overlay()
	get_viewport().gui_release_focus()

func show_title() -> void:
	finish_sequence+=1
	if mode in ["playing","paused"]: _persist_run()
	coins = 0
	deaths = 0
	elapsed = 0
	respawn_left = 0
	checkpoint_active = false
	stage_data = Campaign.stage(current_level)
	respawn_at = stage_data["spawn"]
	collected_coin_ids = []
	collected_relic_ids = []
	checkpoint_index = -1
	_create_world()
	mode = "menu"
	audio.set_context("menu")
	_apply_preferences()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	player.controls_enabled = false
	hud.toast_left = 0
	hud.clear_guide()
	hud.set_checkpoint(false)
	hud.update_run(0, stage_data["coins"].size(), 0, 0, 0)
	_refresh_campaign_ui()
	hud.show_menu(best_seconds)

func toggle_sound() -> void:
	set_preference("muted",not audio.muted)

func toggle_music() -> void:
	set_preference("music_muted",not audio.music_muted)

func set_preference(key: String,value: Variant) -> void:
	preferences.set_option(key,value)
	_apply_preferences()
	hud.refresh_preferences()
	_check_save_error()

func rebind_key(action: String,keycode: int) -> void:
	var result: Error=preferences.rebind(action,keycode)
	hud.binding_result(result)
	_check_save_error()

func reset_bindings() -> void:
	var result: Error=preferences.reset_bindings()
	hud.binding_result(result,true)
	_check_save_error()

func _apply_preferences() -> void:
	if not is_instance_valid(audio) or not is_instance_valid(hud): return
	audio.muted=bool(preferences.values["muted"])
	audio.music_muted=bool(preferences.values["music_muted"])
	audio.set_volumes(float(preferences.values["music_volume"]),float(preferences.values["sfx_volume"]))
	hud.set_muted(audio.muted)
	hud.set_music_muted(audio.music_muted)
	if mode in ["playing","paused"] and bool(preferences.values["assist"]): run_assisted=true
	hud.set_assisted(run_assisted)
	Engine.time_scale=.8 if mode=="playing" and bool(preferences.values["assist"]) else 1.0
	background.reduced_motion=bool(preferences.values["reduced_motion"])
	var goal=world.get_node_or_null("Goal") if is_instance_valid(world) else null
	if goal is Beacon: goal.reduced_motion=bool(preferences.values["reduced_motion"])
	_apply_window_preferences()

func _apply_window_preferences() -> void:
	if DisplayServer.get_name()=="headless": return
	var fullscreen: bool=preferences.values["fullscreen"]
	var current:=DisplayServer.window_get_mode()
	if fullscreen and current!=DisplayServer.WINDOW_MODE_FULLSCREEN:
		windowed_size=DisplayServer.window_get_size()
		windowed_position=DisplayServer.window_get_position()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and current==DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(windowed_size)
		DisplayServer.window_set_position(windowed_position)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(preferences.values["vsync"]) else DisplayServer.VSYNC_DISABLED)

func _exit_tree() -> void:
	Engine.time_scale=1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and mode=="playing" and not quitting and is_instance_valid(hud):
		pause_run("FOCUS_PAUSED")
		_neutralize_input()

func _update_window_title() -> void:
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_title(I18n.text("TITLE"))

func _joy_connection_changed(device: int,connected: bool) -> void:
	if not connected and mode=="playing" and not quitting and hud.using_gamepad and hud.active_joypad==device:
		pause_run("CONTROLLER_PAUSED")
		_neutralize_input()

func _neutralize_input() -> void:
	for action in ["move_left","move_right","jump","dash"]: Input.action_release(action)
	if is_instance_valid(player): player.velocity.x=0

func quit_game() -> void:
	if quitting:
		return
	quitting = true
	Engine.time_scale=1.0
	if mode in ["playing","paused"]: _persist_run()
	if is_instance_valid(audio):
		audio.stop_all()
	# Let the audio thread drain before releasing the looping stream.
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()

func _create_world() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	guideposts.clear()
	var index := 0
	for rect in stage_data["platforms"]:
		var platform := Island.new()
		platform.name = "Island_%02d" % index
		platform.biome = int(stage_data["chapter"])
		platform.is_crumbling = index in stage_data["crumble"]
		platform.configure(rect)
		for movement in stage_data["movers"]:
			if int(movement.get("index",-1))==index:
				platform.travel = float(movement["travel"])
				platform.vertical_travel = bool(movement.get("vertical",false))
		world.add_child(platform)
		index += 1
	for rect in stage_data["bonus"]:
		var perch := Island.new()
		perch.configure(rect)
		perch.one_way = true
		perch.biome = int(stage_data["chapter"])
		world.add_child(perch)
	for movement in stage_data["movers"]:
		if not movement.has("rect"): continue
		var moving := Island.new()
		moving.name = "MovingIsland"
		moving.configure(movement["rect"],float(movement["travel"]))
		world.add_child(moving)
	for coin_id in range(stage_data["coins"].size()):
		if coin_id in collected_coin_ids: continue
		var coin := Pickup.new()
		coin.name = "Coin_%02d" % coin_id
		coin.position = stage_data["coins"][coin_id]
		coin.collected.connect(_on_coin_collected.bind(coin_id))
		world.add_child(coin)
	for relic_id in range(stage_data["relics"].size()):
		if relic_id in collected_relic_ids: continue
		var relic := Relic.new()
		relic.name = "Relic_%d" % relic_id
		relic.position = stage_data["relics"][relic_id]
		relic.collected.connect(_on_relic_collected.bind(relic_id))
		world.add_child(relic)
	for at in stage_data["spikes"]:
		var hazard := Spikes.new()
		hazard.position = at
		world.add_child(hazard)
	for i in range(stage_data["checkpoints"].size()):
		var checkpoint := Marker.new()
		checkpoint.name = "Checkpoint" if i==0 else "Checkpoint_%d" % i
		checkpoint.position = stage_data["checkpoints"][i]
		checkpoint.active = i<=checkpoint_index
		checkpoint.reached.connect(_on_checkpoint_reached.bind(i))
		world.add_child(checkpoint)
	for spec in stage_data["enemies"]:
		var enemy := Patrol.new()
		enemy.position = spec["at"]
		enemy.distance = float(spec["range"])
		enemy.speed = float(spec["speed"])
		world.add_child(enemy)
	for at in stage_data["springs"]:
		var spring := Spring.new()
		spring.position = at
		world.add_child(spring)
	for spec in stage_data.get("lessons",[]):
		var signpost:=Guidepost.new()
		signpost.position=_guidepost_position(spec["at"])
		signpost.kind=spec["kind"]
		world.add_child(signpost)
		guideposts.append({"node":signpost,"lesson":spec})
	var goal=Beacon.new() if current_level==Campaign.COUNT-1 else Marker.new()
	goal.name = "Goal"
	if goal is Marker: goal.is_goal = true
	goal.position = stage_data["finish"]
	goal.reached.connect(_on_goal_reached)
	world.add_child(goal)
	player = PlayerActor.new()
	player.name = "Player"
	player.position = respawn_at
	player.air_jump_enabled = bool(stage_data["air_jump"])
	player.dash_enabled = bool(stage_data["dash"])
	player.died.connect(_on_player_died)
	player.jumped.connect(func() -> void: audio.play("jump"))
	player.dashed.connect(func() -> void: audio.play("jump"); _add_burst(player.position-Vector2(0,20),Color("a5e5d4")))
	player.landed.connect(func() -> void:
		if mode == "playing":
			_add_burst(player.position, Color("b9d3ab"))
	)
	world.add_child(player)
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(clampf(respawn_at.x+130,640,int(stage_data["width"])-640),360)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = int(stage_data["width"])
	camera.limit_top = 0
	camera.limit_bottom = 720
	world.add_child(camera)
	camera.reset_smoothing()
	background.biome = int(stage_data["chapter"])
	background.dawn=0

func _guidepost_position(at: Vector2) -> Vector2:
	# Keep the board clear of the light trail while staying on its authored island.
	for island in stage_data["platforms"]:
		if at.x<island.position.x or at.x>island.end.x or absf(at.y-island.position.y)>2: continue
		for distance in range(0,76,5):
			for direction in [-1,1]:
				var candidate:=at+Vector2(distance*direction,0)
				if candidate.x<island.position.x+44 or candidate.x>island.end.x-44: continue
				var clear:=true
				for light in stage_data["coins"]:
					if absf(light.y-(candidate.y-60))<30 and absf(light.x-candidate.x)<52: clear=false
				if clear: return candidate
	return at

func _update_guidance() -> void:
	if player.dead: return
	var nearest: Dictionary={}
	var distance:=245.0
	for entry in guideposts:
		var signpost=entry["node"]
		var horizontal: float=absf(player.position.x-signpost.position.x)
		if horizontal<distance and absf(player.position.y-signpost.position.y)<185:
			distance=horizontal
			nearest=entry
	for entry in guideposts:
		var highlight: bool=not nearest.is_empty() and entry==nearest
		if entry["node"].highlighted!=highlight:
			entry["node"].highlighted=highlight
			entry["node"].queue_redraw()
	if not nearest.is_empty():
		var lesson: Dictionary=nearest["lesson"]
		hud.show_guide(lesson["title"],lesson["body"],lesson["actions"])

func _on_coin_collected(at: Vector2, coin_id: int = -1) -> void:
	if mode != "playing":
		return
	coins += 1
	if coin_id>=0: collected_coin_ids.append(coin_id)
	audio.play("coin")
	_add_burst(at, Color("f9da92"))

func _on_relic_collected(at: Vector2, relic_id: int) -> void:
	if mode!="playing" or relic_id in collected_relic_ids: return
	collected_relic_ids.append(relic_id)
	profile.record_relic(current_level,relic_id)
	audio.play("checkpoint")
	_add_burst(at,Color("b7ead0"))
	hud.set_relics(collected_relic_ids.size())
	_persist_run()

func _on_player_died() -> void:
	if mode != "playing":
		return
	deaths += 1
	respawn_left = 0.42
	audio.play("death")
	_add_burst(player.position - Vector2(0, 20), Color("c6dbb6"))
	_persist_run()

func _on_checkpoint_reached(index: int = 0) -> void:
	if mode != "playing" or index<=checkpoint_index:
		return
	checkpoint_active = true
	checkpoint_index = index
	respawn_at = stage_data["checkpoints"][index] + Vector2(30, 0)
	hud.notify("CHECKPOINT_TOAST")
	hud.set_checkpoint(true)
	audio.play("checkpoint")
	_add_burst(stage_data["checkpoints"][index] - Vector2(0,80),Color("f9da92"))
	_persist_run()

func _on_goal_reached() -> void:
	if mode != "playing":
		return
	mode = "complete"
	audio.set_context("complete")
	_apply_preferences()
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	# Marker overlaps arrive inside a physics callback. Disable bodies afterward.
	world.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	hud.update_run(coins, stage_data["coins"].size(), elapsed, deaths, 1)
	var new_best: bool = profile.complete(current_level,elapsed,coins,collected_relic_ids.size(),Campaign.COUNT,run_assisted)
	_check_save_error()
	best_seconds = float(profile.level_record(current_level).get("assist_time" if run_assisted else "best_time",elapsed))
	if new_best and current_level==0 and profile_path==Profile.DEFAULT_PATH and not run_assisted:
		save_data.set_value("records", "best_seconds", best_seconds)
		_save_preferences()
	audio.play("finish")
	_refresh_campaign_ui()
	if current_level==Campaign.COUNT-1:
		finish_sequence+=1
		var sequence:=finish_sequence
		hud.show_rekindling()
		await get_tree().create_timer(2.8).timeout
		if sequence!=finish_sequence or mode!="complete" or hud.screen!="rekindling": return
	hud.show_complete(coins, stage_data["coins"].size(), elapsed, deaths, new_best)

func _persist_run() -> void:
	profile.checkpoint(current_level,respawn_at,collected_coin_ids,collected_relic_ids,elapsed,deaths,checkpoint_index,run_assisted)
	_check_save_error()

func _check_save_error() -> void:
	var failed: bool=profile.last_error!=OK or preferences.last_error!=OK
	hud.set_save_warning(failed)
	if failed and not save_warning_shown:
		save_warning_shown=true
		hud.notify("SAVE_ERROR")

func _refresh_campaign_ui() -> void:
	var entries: Array = []
	for i in range(Campaign.COUNT):
		var info := Campaign.stage(i)
		entries.append({"name":info["name"],"chapter":info["chapter"],"unlocked":i<=int(profile.data["unlocked"]),"record":profile.level_record(i)})
	hud.configure_campaign(entries,current_level,profile.has_progress())
	hud.set_stage(stage_data["name"],current_level,bool(stage_data["air_jump"]),bool(stage_data["dash"]))
	hud.set_relics(collected_relic_ids.size())
	hud.set_assisted(run_assisted)

func _add_burst(at: Vector2, color: Color) -> void:
	if bool(preferences.values["reduced_motion"]): return
	# Can be called by a physics overlap; the visual has no collision objects.
	var effect := Burst.new()
	effect.position = at
	effect.tint = color
	world.add_child(effect)

func _save_preferences() -> void:
	var result: Error = preferences.save_settings()
	if result != OK:
		push_warning("Could not save settings or best time: %s" % error_string(result))

func _configure_inputs() -> void:
	preferences.apply_input_map()
