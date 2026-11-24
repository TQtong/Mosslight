extends RefCounted
## Opt-in release-binary smoke check: Mosslight.exe --headless -- --qa-smoke
## It uses a dedicated save and does not modify the player's journey or preferences.

static func run(game: Node, capture_folder: String = "") -> void:
	var tree: SceneTree=game.get_tree()
	AudioServer.set_bus_mute(0,true)
	game.audio.music_muted=true
	game.audio.muted=true
	game.profile.reset_defaults()
	game.profile.data["unlocked"]=11
	game._refresh_campaign_ui()
	var failures:=0
	var i18n=tree.root.get_node("I18n")
	for locale in i18n.locales:
		i18n.set_language(locale,false)
		if not "\nTQ\n" in i18n.text("CREDITS_BODY"): failures+=1
	game.set_preference("music_volume",37.0)
	if absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))-.37)>.001: failures+=1
	if DisplayServer.get_name()!="headless":
		var original_size:=DisplayServer.window_get_size()
		game.set_preference("fullscreen",true)
		for frame in range(8): await tree.process_frame
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_FULLSCREEN:
			failures+=1
			printerr("NATIVE FAIL fullscreen")
		game.set_preference("fullscreen",false)
		game.set_preference("vsync",false)
		for frame in range(8): await tree.process_frame
		if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED or DisplayServer.window_get_size()!=original_size:
			failures+=1
			printerr("NATIVE FAIL window restore")
		if DisplayServer.window_get_vsync_mode()!=DisplayServer.VSYNC_DISABLED:
			failures+=1
			printerr("NATIVE FAIL VSync")
		game.set_preference("vsync",true)
	game.request_stage(0)
	if game.mode!="chapter" or game.hud.overlay.get_node("ChapterStory").text!=i18n.text("STORY_1"): failures+=1
	if not capture_folder.is_empty():
		i18n.set_language("zh_CN",false)
		DirAccess.make_dir_recursive_absolute(capture_folder)
		await _capture(tree,capture_folder.path_join("chapter-story.png"))
	game.begin_chapter()
	for frame in range(8): await tree.physics_frame
	if not game.hud.guide_panel.visible: failures+=1
	if not capture_folder.is_empty(): await _capture(tree,capture_folder.path_join("guidepost.png"))
	if not capture_folder.is_empty():
		i18n.set_language("zh_CN",false)
		DirAccess.make_dir_recursive_absolute(capture_folder)
		game.show_title()
		await _capture(tree,capture_folder.path_join("title.png"))
		game.hud.show_settings()
		await _capture(tree,capture_folder.path_join("settings-zh.png"))
		game.hud._show_controls()
		await _capture(tree,capture_folder.path_join("controls-zh.png"))
		i18n.set_language("en",false)
		await _capture(tree,capture_folder.path_join("controls-en.png"))
		game.hud._back_controls()
		await _capture(tree,capture_folder.path_join("settings-en.png"))
		i18n.set_language("zh_CN",false)
		game.hud.show_map()
		await _capture(tree,capture_folder.path_join("map.png"))
	for index in range(12):
		game.play_stage(index)
		for frame in range(8): await tree.physics_frame
		if game.audio.active_track!=game.audio.CHAPTER_TRACKS[index/4]:
			failures+=1
			printerr("NATIVE FAIL chapter score ",index/4+1)
		if not game.player.is_on_floor() or game.player.dead or game.world.get_node_or_null("Goal")==null:
			failures+=1
			printerr("NATIVE FAIL stage ",index+1)
		if not capture_folder.is_empty() and index in [0,5,10]:
			var platform: Rect2=game.stage_data["platforms"][3]
			game.player.respawn(platform.position+Vector2(90,0))
			game.camera.position.x=game.player.position.x+130
			game.camera.reset_smoothing()
			await _capture(tree,capture_folder.path_join("chapter-%d.png" % (index/4+1)))
	if game.audio.music_player.stream.get_length()<39.9: failures+=1
	if game.audio.players.size()!=4: failures+=1
	if tree.root.get_node("I18n").locales.size()!=10: failures+=1
	game.player.respawn(game.stage_data["finish"]-Vector2(180,0))
	game.camera.position.x=game.stage_data["finish"].x
	game.camera.reset_smoothing()
	if not capture_folder.is_empty(): await _capture(tree,capture_folder.path_join("beacon-dark.png"))
	game.player.respawn(game.stage_data["finish"])
	for frame in range(118): await tree.physics_frame
	if game.mode!="complete" or not game.world.get_node("Goal").active: failures+=1
	if not capture_folder.is_empty(): await _capture(tree,capture_folder.path_join("beacon-lit.png"))
	for frame in range(65): await tree.physics_frame
	if game.hud.screen!="complete" or game.background.dawn<.99: failures+=1
	if not capture_folder.is_empty():
		game.next_stage()
		await _capture(tree,capture_folder.path_join("ending.png"))
		for index in range(12):
			game.profile.data["levels"][str(index)]={"relics":3,"relic_ids":[0,1,2],"completed":true}
		game.next_stage()
		await _capture(tree,capture_folder.path_join("ending-all.png"))
		game.show_credits()
		await _capture(tree,capture_folder.path_join("credits.png"))
	print("NATIVE RESULT: %s · twelve stages, story, guidance, beacon, four scores, settings, ten languages and producer TQ from exported data" % ("PASS" if failures==0 else "FAIL"))
	game.audio.stop_all()
	OS.delay_msec(300)
	for frame in range(4): await tree.process_frame
	assert(game.profile_path=="user://qa_native_launch.json")
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.profile_path+suffix))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.settings_path+suffix))
	tree.quit(1 if failures else 0)

static func _capture(tree: SceneTree,path: String) -> void:
	for frame in range(6): await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
