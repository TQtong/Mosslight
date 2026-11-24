extends RefCounted
## Native, opt-in input/display/lifecycle checks. All files use the QA namespace.
const Navigation=preload("res://scripts/qa_navigation.gd")

static func run(game: Node,folder: String,soak_seconds: int=0) -> void:
	var tree: SceneTree=game.get_tree()
	var report: Dictionary={"checks":0,"failures":0,"display":DisplayServer.get_name(),"devices":[],"resolutions":[]}
	AudioServer.set_bus_mute(0,true)
	game.profile.reset_defaults()
	game.profile.data["unlocked"]=11
	game._refresh_campaign_ui()
	if not folder.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	for device in Input.get_connected_joypads():
		report["devices"].append({"id":device,"name":Input.get_joy_name(device)})
	print("PHYSICAL CONTROLLERS: ",report["devices"])
	game.set_preference("vsync",false)
	var navigation: Dictionary=await Navigation.run(game)
	report["checks"]+=navigation["checks"]
	report["failures"]+=navigation["failures"]
	if DisplayServer.get_name()!="headless":
		tree.root.get_node("I18n").set_language("zh_CN",false)
		var original_size:=DisplayServer.window_get_size()
		for wanted in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1024,768),Vector2i(1280,800),Vector2i(1920,800),Vector2i(1920,1080)]:
			game.show_title()
			DisplayServer.window_set_size(wanted)
			for frame in range(12): await tree.process_frame
			var actual:=DisplayServer.window_get_size()
			var logical: Vector2=tree.root.get_visible_rect().size
			_check(report,actual==wanted,"Window accepts %dx%d" % [wanted.x,wanted.y])
			_check(report,logical.is_equal_approx(Vector2(1280,720)),"Logical play area stays 1280x720 at %s" % wanted)
			game.hud.show_settings()
			for frame in range(3): await tree.process_frame
			_check(report,_layout_inside(game.hud.root),"Settings controls stay inside the play area at %s" % wanted)
			if not folder.is_empty(): _check(report,await _capture(tree,folder.path_join("settings-%dx%d.png" % [wanted.x,wanted.y]),wanted),"Captured native settings at %s" % wanted)
			var muted: bool=game.audio.music_muted
			await Navigation.click(tree,game.hud.overlay.get_node("MusicToggle").get_global_rect().get_center())
			_check(report,game.audio.music_muted!=muted,"Mouse input hits the correct control through the viewport transform at %s" % wanted)
			await Navigation.click(tree,game.hud.overlay.get_node("MusicToggle").get_global_rect().get_center())
			game.current_level=(report["resolutions"].size()*2)%12
			game.start_run()
			await Navigation.frames(tree,8)
			_check(report,game.player.is_on_floor() and not game.player.dead,"Gameplay starts safely at %s" % wanted)
			if not folder.is_empty(): _check(report,await _capture(tree,folder.path_join("gameplay-%dx%d.png" % [wanted.x,wanted.y]),wanted),"Captured native gameplay at %s" % wanted)
			game.pause_run("FOCUS_PAUSED")
			if not folder.is_empty() and wanted in [Vector2i(1024,768),Vector2i(1920,800)]: await _capture(tree,folder.path_join("pause-%dx%d.png" % [wanted.x,wanted.y]),wanted)
			report["resolutions"].append({"requested":[wanted.x,wanted.y],"actual":[actual.x,actual.y],"logical":[logical.x,logical.y]})
		DisplayServer.window_set_size(original_size)
		for frame in range(8): await tree.process_frame
	if soak_seconds>0:
		game.set_preference("vsync",true)
		Engine.max_fps=60
		report["soak"]=await _soak(game,soak_seconds,report)
	if not folder.is_empty():
		var file:=FileAccess.open(folder.path_join("platform-report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("PLATFORM RESULT: %d/%d passed" % [report["checks"]-report["failures"],report["checks"]])
	game.audio.stop_all()
	OS.delay_msec(300)
	for frame in range(4): await tree.process_frame
	for path in [game.profile_path,game.settings_path]:
		assert(path.begins_with("user://qa_"))
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	tree.quit(1 if report["failures"] else 0)

static func _soak(game: Node,seconds: int,report: Dictionary) -> Dictionary:
	var tree: SceneTree=game.get_tree()
	var i18n=tree.root.get_node("I18n")
	var started:=Time.get_ticks_msec()
	var deadline:=started+seconds*1000
	var next_step:=started
	var step:=0
	var cycle:=0
	var baseline: int=-1
	var samples: Array=[]
	var audio_ids: Dictionary={}
	for key in game.audio.players: audio_ids[key]=game.audio.players[key].get_instance_id()
	print("SOAK START: ",seconds," seconds; engine clock ",started/1000.0)
	while Time.get_ticks_msec()<deadline:
		await tree.process_frame
		if Time.get_ticks_msec()<next_step: continue
		next_step=Time.get_ticks_msec()+200
		match step%8:
			0: game.play_stage(cycle%12)
			1:
				Input.action_press("move_right")
				Input.action_press("jump")
			2:
				Input.action_release("move_right")
				Input.action_release("jump")
				game.pause_run()
			3: game.hud.show_settings()
			4: game.hud._show_controls()
			5:
				game.hud.show_language()
				i18n.set_language(i18n.locales[cycle%10],false)
			6: game.show_title()
			7:
				cycle+=1
				if cycle%12==0:
					game.current_level=0
					game.show_title()
					i18n.set_language("en",false)
					await Navigation.frames(tree,5)
					var count:=tree.get_node_count()
					if baseline<0: baseline=count
					var sample: Dictionary={"cycle":cycle,"seconds":(Time.get_ticks_msec()-started)/1000.0,"nodes":count,"fps":Performance.get_monitor(Performance.TIME_FPS)}
					samples.append(sample)
					print("SOAK SAMPLE: ",JSON.stringify(sample))
		step+=1
	for action in ["move_left","move_right","jump","dash"]: Input.action_release(action)
	game.current_level=0
	game.show_title()
	i18n.set_language("en",false)
	await Navigation.frames(tree,6)
	var final_count:=tree.get_node_count()
	_check(report,baseline>0 and final_count<=baseline+2,"Repeated world/UI/language rebuilds return to the baseline node count")
	var stable: bool=game.audio.players.size()==4
	for key in audio_ids: stable=stable and game.audio.players[key].get_instance_id()==audio_ids[key]
	_check(report,stable,"The soundtrack pool stays fixed through the lifecycle soak")
	_check(report,cycle>=seconds/3,"The native soak continuously exercised stages and menus")
	return {"duration_seconds":(Time.get_ticks_msec()-started)/1000.0,"start_seconds":started/1000.0,"cycles":cycle,"baseline_nodes":baseline,"final_nodes":final_count,"samples":samples}

static func _layout_inside(node: Node) -> bool:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Slider or node is Label):
		var rect: Rect2=node.get_global_rect()
		if rect.position.x<-.5 or rect.position.y<-.5 or rect.end.x>1280.5 or rect.end.y>720.5: return false
	for child in node.get_children():
		if not _layout_inside(child): return false
	return true

static func _capture(tree: SceneTree,path: String,wanted: Vector2i) -> bool:
	for frame in range(3): await tree.process_frame
	await RenderingServer.frame_post_draw
	var screenshot:=tree.root.get_texture().get_image()
	var content:=screenshot.get_size()
	if content.x>wanted.x or content.y>wanted.y:
		printerr("Unexpected viewport size: ",content," for window ",wanted)
		return false
	# Godot's root texture excludes OS letterboxing. Reconstruct that client area
	# with an unchanged copy of its actual rendered pixels, without resampling.
	if content!=wanted:
		var client:=Image.create(wanted.x,wanted.y,false,screenshot.get_format())
		client.fill(Color.BLACK)
		client.blit_rect(screenshot,Rect2i(Vector2i.ZERO,content),(wanted-content)/2)
		screenshot=client
	return screenshot.save_png(path)==OK

static func _check(report: Dictionary,condition: bool,description: String) -> void:
	report["checks"]+=1
	if not condition: report["failures"]+=1
	print(("PASS " if condition else "FAIL ")+description)
