extends SceneTree
const Catalog=preload("res://scripts/campaign.gd")
const Profile=preload("res://scripts/profile.gd")
const QA_PATH="user://qa_campaign_test.json"
var game
var checks: int=0
var failures: int=0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_clean(QA_PATH)
	game=load("res://scenes/main.tscn").instantiate()
	game.profile_path=QA_PATH
	game.settings_path="user://qa_campaign_test_settings.cfg"
	root.add_child(game)
	game.audio.music_muted=true
	game.audio.muted=true
	game.profile.data["unlocked"]=11
	var ids: Array=[]
	for index in range(Catalog.COUNT):
		var data:=Catalog.stage(index)
		check(not data["id"] in ids,"Stage %02d has a unique identity" % (index+1))
		ids.append(data["id"])
		check(data["platforms"].size()>=9 and data["relics"].size()==3,"Stage %02d has a route and three lightseeds" % (index+1))
		game.play_stage(index)
		await frames(8)
		check(game.player.is_on_floor() and not game.player.dead,"Stage %02d spawns safely on its starting island" % (index+1))
		check(game.background.biome==index/4,"Stage %02d uses its chapter palette" % (index+1))
		check(game.player.air_jump_enabled==(index>=4) and game.player.dash_enabled==(index>=8),"Stage %02d exposes the intended abilities" % (index+1))
		game.player.respawn(data["finish"])
		await frames(6)
		check(game.mode=="complete" and game.profile.level_record(index).get("completed",false),"Stage %02d goal records completion" % (index+1))
	check(game.profile.finished(12),"Completing the final arch finishes the campaign")
	game.next_stage()
	check(game.mode=="ending" and game.hud.screen=="ending","Final completion opens the story ending")
	game.show_title()
	game.hud.show_map()
	await frames(2)
	check(game.hud.overlay.get_node("Stage_11").disabled==false,"Completed campaign retains selectable stages")
	game.play_stage(4)
	await frames(8)
	Input.action_press("jump")
	await frames(15)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(3)
	check(game.player.velocity.y < -400 and not game.player.air_jump_left,"Second chapter enables an actual mid-air jump")
	Input.action_release("jump")
	game.play_stage(8)
	await frames(7)
	game.player.position.y-=100
	await frames(2)
	Input.action_press("dash")
	await frames(3)
	check(game.player.dash_left>0 and absf(game.player.velocity.x)>600,"Third chapter enables an actual aerial dash")
	Input.action_release("dash")
	game.play_stage(6)
	await frames(7)
	game.player.respawn(game.stage_data["coins"][0]+Vector2(0,15))
	await frames(5)
	game.player.respawn(game.stage_data["relics"][0]+Vector2(0,15))
	await frames(5)
	game.player.respawn(game.stage_data["checkpoints"][0])
	await frames(5)
	game.pause_run()
	var at: Vector2=game.respawn_at
	var coins: int=game.coins
	var relics: int=game.collected_relic_ids.size()
	check(coins>0 and relics>0 and game.checkpoint_active,"Actual overlaps record pickups and a checkpoint")
	game.audio.stop_all()
	game.queue_free()
	await frames(3)
	OS.delay_msec(180)
	game=load("res://scenes/main.tscn").instantiate()
	game.profile_path=QA_PATH
	game.settings_path="user://qa_campaign_test_settings.cfg"
	root.add_child(game)
	game.audio.music_muted=true
	game.audio.muted=true
	game.continue_journey()
	await frames(6)
	check(game.current_level==6 and game.respawn_at==at,"Fresh game instance resumes the saved stage and checkpoint")
	check(game.coins==coins and game.collected_relic_ids.size()==relics,"Fresh game instance restores collected objects")
	check(not game.world.has_node("Coin_00") and not game.world.has_node("Relic_0"),"Restored pickups are absent from the new world")
	game.start_run()
	await frames(4)
	check(game.collected_relic_ids.size()==relics and not game.world.has_node("Relic_0"),"Lightseeds stay collected when replaying a stage")
	game.profile.data["unlocked"]=0
	game.show_title()
	game.hud.show_map()
	check(game.hud.overlay.get_node("Stage_11").disabled,"Locked stages are disabled in the map")
	var previous: int=game.current_level
	game.play_stage(11)
	check(game.current_level==previous,"Direct requests cannot bypass stage locks")
	game.audio.stop_all()
	game.queue_free()
	await frames(3)
	OS.delay_msec(180)
	_clean(QA_PATH)
	await _save_recovery()
	print("CAMPAIGN RESULT: %d/%d passed" % [checks-failures,checks])
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_campaign_test_settings.cfg"+suffix))
	quit(1 if failures else 0)

func _save_recovery() -> void:
	var path: String="user://qa_save_recovery.json"
	_clean(path)
	var p=Profile.new(path)
	p.data["unlocked"]=3
	check(p.save_profile()==OK,"Initial campaign save succeeds")
	p.data["unlocked"]=5
	check(p.save_profile()==OK,"Campaign save atomically replaces an existing generation")
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	var recovered=Profile.new(path)
	recovered.load_profile(12)
	check(recovered.recovered_backup and recovered.data["unlocked"]==3,"Truncated campaign data recovers from the prior valid generation")
	recovered.data["unlocked"]=4
	check(recovered.save_profile()==OK,"Recovered campaign can be saved normally")
	var loaded=Profile.new(path)
	loaded.load_profile(12)
	check(loaded.data["unlocked"]==4,"Recovered save survives a subsequent reload")
	file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string('{"version":1,"unlocked":4,"last_level":{},"levels":{},"active_run":{}}')
	file.close()
	loaded.load_profile(12)
	check(loaded.recovered_backup,"Wrong field types are recovered without a runtime error")
	_clean(path)

func _clean(path: String) -> void:
	assert(path.begins_with("user://qa_"))
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func check(condition: bool, description: String) -> void:
	checks+=1
	if not condition: failures+=1
	print(("PASS " if condition else "FAIL ")+description)
