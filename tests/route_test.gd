extends SceneTree
## Drives real input across the authored main routes. It never teleports the player.
## Passing is route evidence, not a substitute for human difficulty/feel playtests.
const Catalog=preload("res://scripts/campaign.gd")
const Spikes=preload("res://scripts/spikes.gd")
const Patrol=preload("res://scripts/patrol.gd")
var qa_path: String="user://qa_route_test.json"
var settings_path: String="user://qa_route_test_settings.cfg"
var game
var trace: Array=[]
var stage_start: int=0
var collect_route: bool=false
var relic_target: int=0
var detour: int=0
var detour_age: int=0
var detour_attempts: int=0
var capture_folder: String=""
var capture_locale: String="en"
var original_locale: String=""
var single_stage: bool=false
var movie_log: String=""
var movie_events: Array=[]
var movie_stages: Array=[]
var movie_draw_start: int=0
var capture_records: Array=[]
var scheduled_captures: Dictionary={}
const CAPTURE_STAGES={0:.35,3:.30,4:.40,6:.50,8:.50,11:.96}

func _initialize() -> void:
	var arguments:=OS.get_cmdline_user_args()
	for i in range(arguments.size()):
		var argument: String=arguments[i]
		if argument=="--collect": collect_route=true
		elif argument=="--screenshots" and i+1<arguments.size(): capture_folder=arguments[i+1]
		elif argument=="--capture-locale" and i+1<arguments.size(): capture_locale=arguments[i+1]
		elif argument=="--single-stage": single_stage=true
		elif argument=="--movie-log" and i+1<arguments.size(): movie_log=arguments[i+1]
		elif argument.is_valid_int(): stage_start=clampi(int(argument),0,Catalog.COUNT-1)
	if collect_route:
		qa_path="user://qa_collect_route.json"
		settings_path="user://qa_collect_route_settings.cfg"
	if not movie_log.is_empty():
		qa_path="user://qa_movie_route.json"
		settings_path="user://qa_movie_route_settings.cfg"
	_run.call_deferred()

func _run() -> void:
	_clean_qa()
	if not movie_log.is_empty():
		# Windows may stop presenting an occluded native window. MovieWriter
		# still advances audio/time, so force a fresh viewport render each tick.
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
		process_frame.connect(_force_movie_draw)
		movie_draw_start=Engine.get_frames_drawn()
	if not capture_folder.is_empty() or not movie_log.is_empty():
		if DisplayServer.get_name()=="headless":
			printerr("Store screenshots require an actual renderer")
			quit(1)
			return
		if not capture_folder.is_empty(): DirAccess.make_dir_recursive_absolute(capture_folder)
		original_locale=root.get_node("I18n").current
		root.get_node("I18n").set_language(capture_locale,false)
	game=load("res://scenes/main.tscn").instantiate()
	game.profile_path=qa_path
	game.settings_path=settings_path
	root.add_child(game)
	game.audio.music_muted=true
	game.audio.muted=movie_log.is_empty()
	AudioServer.set_bus_mute(0,movie_log.is_empty())
	if not capture_folder.is_empty() or not movie_log.is_empty():
		game.set_preference("vsync",false)
		Engine.max_fps=240
	if not movie_log.is_empty():
		# start_run/resume reapply preferences, so persist the isolated recording
		# setting rather than only changing the Audio node's transient mute.
		game.set_preference("music_muted",true)
	game.profile.data["unlocked"]=11
	var stage_end: int=stage_start+1 if single_stage else Catalog.COUNT
	for stage_index in range(stage_start,stage_end):
		game.play_stage(stage_index)
		var movie_stage: Dictionary={"stage":stage_index+1,"start_frame":Engine.get_process_frames()}
		relic_target=0
		detour=0
		detour_age=0
		detour_attempts=0
		game.player.jumped.connect(func() -> void: _log("actual jump %s" % game.player.position))
		var phase:=0
		var phase_age:=0
		var airborne_seen:=false
		var long_hop:=false
		var dash_used:=false
		var support_before: String=""
		trace.clear()
		for frame in range(9000):
			await physics_frame
			if game.mode=="paused" and game.hud.pause_reason_key=="FOCUS_PAUSED":
				for wait_frame in range(3): await physics_frame
				game.hud.resume_requested.emit()
			if game.mode=="complete":
				if collect_route and game.collected_relic_ids.size()!=3:
					print("COLLECT FAIL %02d: reached the goal without all three lightseeds" % (stage_index+1))
					await _finish(1)
					return
				print("ROUTE PASS %02d: %.2fs, %d lights, %d lightseeds" % [stage_index+1,game.elapsed,game.coins,game.collected_relic_ids.size()])
				movie_stage.merge({"end_frame":Engine.get_process_frames(),"elapsed":game.elapsed,"deaths":game.deaths,"lightseeds":game.collected_relic_ids.size()})
				movie_stages.append(movie_stage)
				break
			if game.deaths>0:
				print("ROUTE FAIL %02d at %s frame %d; recent actions: %s" % [stage_index+1,game.player.position,frame,trace])
				await _finish(1)
				return
			var p=game.player
			if not capture_folder.is_empty() and CAPTURE_STAGES.has(stage_index) and not scheduled_captures.has(stage_index):
				var progress: float=(p.position.x-game.stage_data["spawn"].x)/(game.stage_data["finish"].x-game.stage_data["spawn"].x)
				if progress>=CAPTURE_STAGES[stage_index]:
					scheduled_captures[stage_index]=true
					_take_screenshot.call_deferred(stage_index)
			phase_age+=1
			if phase==0 and not p.is_on_floor() and p.velocity.y < -650:
				phase=1
				phase_age=0
				airborne_seen=true
				long_hop=true
				_log("spring launch %s" % p.position)
			var support=null
			for island in game.world.get_children():
				if island is AnimatableBody2D and island.visible and absf(p.position.y-island.position.y)<3 and p.position.x>=island.position.x-11 and p.position.x<=island.position.x+island.size.x+11:
					support=island
					break
			# Collection detours steer and jump using the same public input actions.
			# The test never changes position, velocity, abilities, hazards or timers.
			if collect_route and _collect_detour(support):
				phase=0
				airborne_seen=false
				dash_used=false
				continue
			if support!=null and p.is_on_floor():
				if support.name!=support_before:
					support_before=support.name
					_log("land %s %s" % [support.name,p.position])
				if airborne_seen:
					phase=0
					airborne_seen=false
					dash_used=false
			if phase>0 and p.velocity.y<0: airborne_seen=true
			if phase==1 and airborne_seen and p.velocity.y>=-20:
				Input.action_release("jump")
				phase=2
				phase_age=0
			elif phase==2 and phase_age>=2 and long_hop and p.air_jump_enabled and p.air_jump_left and not p.is_on_floor():
				Input.action_press("jump")
				phase=3
				phase_age=0
				_log("air jump %s" % p.position)
			elif phase==3 and phase_age>5 and p.velocity.y>=-100:
				Input.action_release("jump")
				if p.dash_enabled and p.dash_ready and not dash_used:
					Input.action_press("dash")
					dash_used=true
					_log("dash %s" % p.position)
				phase=4
			elif phase==4:
				Input.action_release("dash")
			var wait:=false
			if stage_index==0:
				var moving=game.world.get_node("MovingIsland")
				if p.position.x>2930 and p.position.x<3060 and moving.position.x>3110: wait=true
				if support!=null and support.name=="MovingIsland" and p.position.x>=moving.position.x+57 and moving.position.x<3150: wait=true
			if wait: Input.action_release("move_right")
			else: Input.action_press("move_right")
			if support!=null and p.is_on_floor() and phase==0:
				var edge: bool=p.position.x>=support.position.x+support.size.x-47
				var danger:=false
				for node in game.world.get_children():
					if node is Spikes and absf(node.position.y-p.position.y)<4 and node.position.x-p.position.x<=60 and node.position.x+node.width>p.position.x:
						danger=true
					if node is Patrol and not node.defeated and absf(node.position.y-p.position.y)<22 and node.position.x-p.position.x>0 and node.position.x-p.position.x<95:
						danger=true
				if (edge or danger) and not wait:
					Input.action_press("jump")
					phase=1
					phase_age=0
					long_hop=false
					if edge:
						for target in game.stage_data["platforms"]:
							if target.position.x<=support.position.x+support.size.x-10: continue
							var drop: float=target.position.y-support.position.y
							var disc: float=p.jump_speed*p.jump_speed+2*p.gravity*drop
							var reach: float=0 if disc<0 else p.run_speed*(p.jump_speed+sqrt(disc))/p.gravity
							long_hop=disc<0 or target.position.x-p.position.x+24>reach-15
							break
					_log("jump %s edge=%s" % [p.position,edge])
			if frame==8999:
				print("ROUTE TIMEOUT %02d at %s, recent: %s" % [stage_index+1,p.position,trace])
				await _finish(1)
				return
		Input.action_release("jump")
		Input.action_release("move_right")
		Input.action_release("dash")
	print("COLLECT RESULT: all requested stages completed with all three lightseeds using actual input" if collect_route else "ROUTE RESULT: all requested main routes completed with actual input")
	if not capture_folder.is_empty():
		var wanted:=0
		for index in CAPTURE_STAGES:
			if index>=stage_start: wanted+=1
		print("STORE CAPTURE RESULT: %d/%d rendered gameplay screenshots" % [capture_records.size(),wanted])
		var file:=FileAccess.open(capture_folder.path_join("capture-manifest.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"producer":"TQ","locale":capture_locale,"version":ProjectSettings.get_setting("application/config/version"),"method":"actual rendered gameplay driven with input actions; no teleportation or image overlays","captures":capture_records},"  "))
		file.close()
		if capture_records.size()!=wanted:
			await _finish(1)
			return
	await _finish(0)

func _take_screenshot(index: int) -> void:
	await RenderingServer.frame_post_draw
	if game.current_level!=index or game.mode!="playing": return
	var picture:=root.get_texture().get_image()
	if picture.get_size()!=Vector2i(1920,1080):
		printerr("Store capture has unexpected dimensions ",picture.get_size())
		return
	var filename: String="stage-%02d.png" % (index+1)
	if picture.save_png(capture_folder.path_join(filename))==OK:
		capture_records.append({"file":filename,"stage":index+1,"seconds":game.elapsed,"lights":game.coins,"lightseeds":game.collected_relic_ids.size(),"player":[game.player.position.x,game.player.position.y],"width":picture.get_width(),"height":picture.get_height()})

func _collect_detour(support: Node) -> bool:
	while relic_target<3 and relic_target in game.collected_relic_ids and detour==0:
		relic_target+=1
	if relic_target>=3: return false
	var p=game.player
	var target: Vector2=game.stage_data["relics"][relic_target]
	if detour==0:
		if support==null or not p.is_on_floor(): return false
		var rect:=Rect2(support.position,support.size)
		if target.x<rect.position.x or target.x>rect.end.x or absf(target.x-p.position.x)>support.size.x+30: return false
		detour=1
		detour_age=0
		detour_attempts=0
		_log("detour %d approach from %s" % [relic_target,p.position])
	detour_age+=1
	_steer_to(target.x)
	Input.action_release("dash")
	if detour==5:
		# Step off the left side of a one-way perch and land back on its host.
		# This avoids treating a small optional perch as the next main-route island.
		var host=null
		for island in game.world.get_children():
			if island is AnimatableBody2D and not island.one_way and target.x>=island.base_position.x and target.x<=island.base_position.x+island.size.x:
				host=island
				break
		if host!=null:
			if not host.is_crumbling or (host.collapse_left<0 and host.restore_left<=0):
				_steer_to(target.x-82)
			if p.is_on_floor() and support==host:
				_log("detour returned to main island %s" % p.position)
				relic_target+=1
				detour=0
		return true
	if detour==1:
		if p.is_on_floor() and absf(p.position.x-target.x)<=90:
			Input.action_press("jump")
			detour=2
			detour_age=0
			detour_attempts+=1
			_log("detour ground jump %s" % p.position)
	elif detour==2 and detour_age>8 and p.velocity.y>=-20:
		Input.action_release("jump")
		detour=3
		detour_age=0
	elif detour==3 and detour_age>=2:
		if not relic_target in game.collected_relic_ids and p.air_jump_enabled and p.air_jump_left and not p.is_on_floor():
			Input.action_press("jump")
			_log("detour air jump %s" % p.position)
		detour=4
		detour_age=0
	elif detour==4 and detour_age>8 and p.velocity.y>=0:
		Input.action_release("jump")
	if detour in [3,4] and p.is_on_floor():
		Input.action_release("jump")
		if relic_target in game.collected_relic_ids:
			_log("detour collected %d and landed %s" % [relic_target,p.position])
			if support!=null and support.one_way:
				detour=5
			else:
				relic_target+=1
				detour=0
		elif detour_attempts<3:
			detour=1
			detour_age=0
		else:
			_log("detour unable to reach %s from %s" % [target,p.position])
	if detour_age>300:
		_log("detour stuck %d at %s, target %s" % [detour,p.position,target])
	return true

func _steer_to(x: float) -> void:
	var p=game.player
	var distance: float=x-p.position.x
	var stopping: float=p.velocity.x*p.velocity.x/(2*p.acceleration)+4
	Input.action_release("move_left")
	Input.action_release("move_right")
	if absf(distance)>maxf(5,stopping) or p.velocity.x*distance<0:
		Input.action_press("move_right" if distance>0 else "move_left")

func _log(message: String) -> void:
	if not movie_log.is_empty():
		movie_events.append({"frame":Engine.get_process_frames(),"stage":game.current_level+1,"event":message})
	trace.append(message)
	if trace.size()>16: trace.pop_front()

func _finish(code: int) -> void:
	if not movie_log.is_empty():
		var drawn: int=Engine.get_frames_drawn()-movie_draw_start
		var processed: int=Engine.get_process_frames()
		if drawn<processed-3:
			printerr("Movie capture lost fresh rendered frames: ",drawn," / ",processed)
			code=1
		var file:=FileAccess.open(movie_log,FileAccess.WRITE)
		if file==null:
			printerr("Could not write gameplay recording markers: ",movie_log)
			code=1
		else:
			file.store_string(JSON.stringify({"producer":"TQ","version":ProjectSettings.get_setting("application/config/version"),"locale":capture_locale,"fps":Engine.get_physics_ticks_per_second(),"rendered_frames":drawn,"process_frames":processed,"driver_sha256":FileAccess.get_sha256("res://tests/route_test.gd"),"music_bus_muted":AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"sfx_bus_muted":AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"method":"Godot Movie Maker, fresh viewport render each tick, actual input actions at normal gameplay speed; no teleportation, altered physics or staged hazards; SFX retained, music mixed in edit","result":code,"stages":movie_stages,"events":movie_events},"  "))
			file.close()
	for action in ["jump","move_left","move_right","dash"]: Input.action_release(action)
	game.audio.stop_all()
	game.queue_free()
	for i in range(3): await physics_frame
	OS.delay_msec(180)
	if not original_locale.is_empty(): root.get_node("I18n").set_language(original_locale,false)
	_clean_qa()
	quit(code)

func _force_movie_draw() -> void:
	RenderingServer.force_draw(false,1.0/60.0)

func _clean_qa() -> void:
	assert(qa_path.begins_with("user://qa_") and settings_path.begins_with("user://qa_"))
	for path in [qa_path,settings_path]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
