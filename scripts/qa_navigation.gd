extends RefCounted
## Explicit opt-in QA. Input events exercise the same GUI routing as a player.

static func run(game: Node) -> Dictionary:
	var result: Dictionary={"checks":0,"failures":0}
	var tree: SceneTree=game.get_tree()
	var i18n=tree.root.get_node("I18n")
	var old_locale: String=i18n.current
	var old_language_path: String=i18n.preferences_path
	i18n.preferences_path="user://qa_navigation_language.cfg"
	i18n.set_language("en",false)
	for name in ["title","settings","controls","language","locked map","unlocked map","chapter","results","pause"]:
		_setup(game,name)
		await frames(tree,3)
		var controls:=_expected_controls(game)
		var focused=tree.root.gui_get_focus_owner()
		check(result,focused!=null and focused in controls,name+": opens with a visible focused control")
		var expected: Dictionary={}
		for control in controls: expected[control.get_instance_id()]=control
		var seen: Dictionary={}
		var tab_trace: Array=[]
		for index in range(controls.size()):
			focused=tree.root.gui_get_focus_owner()
			if focused!=null:
				seen[focused.get_instance_id()]=true
				tab_trace.append(focused.text if focused is Button else str(focused.name))
			await key(tree,KEY_TAB)
		check(result,_covers(expected,seen),name+": Tab visits every enabled control")
		if not _covers(expected,seen): print("TAB TRACE ",name," ",tab_trace)
		seen.clear()
		for index in range(controls.size()):
			focused=tree.root.gui_get_focus_owner()
			if focused!=null: seen[focused.get_instance_id()]=true
			await key(tree,KEY_TAB,true)
		check(result,_covers(expected,seen),name+": Shift-Tab visits every enabled control")
		# Breadth-first exploration discovers nodes only through real D-pad events.
		var queue: Array=[]
		focused=tree.root.gui_get_focus_owner()
		if focused!=null: queue.append(focused)
		seen.clear()
		if focused!=null: seen[focused.get_instance_id()]=true
		while not queue.is_empty():
			var anchor: Control=queue.pop_front()
			for direction in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
				anchor.grab_focus()
				await joy(tree,direction)
				var next=tree.root.gui_get_focus_owner()
				if next!=null and expected.has(next.get_instance_id()) and not seen.has(next.get_instance_id()):
					seen[next.get_instance_id()]=true
					queue.append(next)
		check(result,_covers(expected,seen),name+": controller D-pad reaches every enabled control")
	game.show_title()
	game.hud.show_settings()
	await joy(tree,JOY_BUTTON_A)
	check(result,game.hud.screen=="controls","Controller confirm opens the focused settings action")
	if game.hud.screen!="controls":
		print("CONFIRM DIAGNOSTIC ",game.hud.screen," focus=",tree.root.gui_get_focus_owner())
		game.hud._show_controls()
	game.hud.overlay.get_node("Bind_jump").pressed.emit()
	await joy(tree,JOY_BUTTON_B)
	check(result,game.hud.screen=="controls" and game.hud.pending_action.is_empty(),"Controller cancel safely ends keyboard capture")
	await joy(tree,JOY_BUTTON_B)
	check(result,game.hud.screen=="settings","Controller cancel returns to settings")
	await joy(tree,JOY_BUTTON_B)
	check(result,game.hud.screen=="menu","Controller cancel returns to the parent title")
	game.hud.show_language()
	game.hud.overlay.get_node("Language_de").grab_focus()
	await joy(tree,JOY_BUTTON_A)
	check(result,i18n.current=="de" and game.hud.screen=="language","Controller confirm switches language without leaving its page")
	var language:=ConfigFile.new()
	language.load(i18n.preferences_path)
	check(result,language.get_value("language","locale","")=="de","Language choice is saved to the isolated QA preference")
	i18n.set_language("en",false)
	game.start_run()
	await frames(tree,8)
	game.set_preference("music_muted",false)
	await click(tree,game.hud.music_button.get_global_rect().get_center())
	check(result,game.audio.music_muted and tree.root.gui_get_focus_owner()==null,"Clicking a gameplay audio icon leaves movement without GUI focus")
	await key(tree,KEY_SPACE)
	await frames(tree,3)
	check(result,game.audio.music_muted and game.player.velocity.y<0,"Jump after an audio click jumps without toggling music again")
	await joy(tree,JOY_BUTTON_START)
	check(result,game.mode=="paused","Controller Start pauses gameplay")
	await joy(tree,JOY_BUTTON_B)
	check(result,game.mode=="playing" and tree.root.gui_get_focus_owner()==null,"Controller cancel resumes and releases all menu focus")
	# OS focus events and disconnect signals are simulated here, not hardware tests.
	var held:=InputEventKey.new()
	held.keycode=KEY_D
	held.physical_keycode=KEY_D
	held.pressed=true
	Input.parse_input_event(held)
	await frames(tree,3)
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames(tree,3)
	var stopped_at: Vector2=game.player.position
	var stopped_time: float=game.elapsed
	check(result,game.mode=="paused" and game.hud.pause_reason_key=="FOCUS_PAUSED","Losing window focus pauses and explains the reason")
	check(result,not Input.is_action_pressed("move_right") and game.player.velocity.x==0,"Focus loss clears held movement actions")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await frames(tree,10)
	check(result,game.mode=="paused" and game.player.position==stopped_at and game.elapsed==stopped_time,"Returning focus does not resume or advance the paused run")
	held.pressed=false
	Input.parse_input_event(held)
	await key(tree,KEY_ESCAPE)
	check(result,game.mode=="playing","The player explicitly resumes after returning focus")
	Input.joy_connection_changed.emit(1,false)
	check(result,game.mode=="playing","An unrelated controller disconnect does not interrupt keyboard play")
	var stick:=InputEventJoypadMotion.new()
	stick.device=0
	stick.axis=JOY_AXIS_LEFT_X
	stick.axis_value=.5
	Input.parse_input_event(stick)
	await frames(tree,3)
	Input.joy_connection_changed.emit(0,false)
	await frames(tree,3)
	check(result,game.mode=="paused" and game.hud.pause_reason_key=="CONTROLLER_PAUSED","Disconnecting the active input device pauses and explains the reason")
	check(result,not Input.is_action_pressed("move_right"),"A disconnected controller cannot leave a held movement action")
	Input.joy_connection_changed.emit(0,true)
	await frames(tree,3)
	check(result,game.mode=="paused","Controller reconnection waits for an explicit resume")
	stick.axis_value=0
	Input.parse_input_event(stick)
	game.show_title()
	i18n.set_language(old_locale,false)
	i18n.preferences_path=old_language_path
	if FileAccess.file_exists("user://qa_navigation_language.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_navigation_language.cfg"))
	print("NAVIGATION RESULT: %d/%d passed" % [result["checks"]-result["failures"],result["checks"]])
	return result

static func _setup(game: Node,screen: String) -> void:
	game.show_title()
	match screen:
		"settings": game.hud.show_settings()
		"controls": game.hud._show_controls()
		"language": game.hud.show_language()
		"locked map","unlocked map":
			game.profile.data["unlocked"]=11 if screen=="unlocked map" else 0
			game._refresh_campaign_ui()
			game.hud.show_map()
		"chapter": game.hud.show_chapter(1)
		"results": game.hud.show_complete(10,20,42,1,true)
		"pause":
			game.start_run()
			game.pause_run()

static func _expected_controls(game: Node) -> Array[Control]:
	var controls: Array[Control]=[]
	for node in game.hud.overlay.find_children("*","Control",true,false):
		if not node.is_visible_in_tree(): continue
		if node is BaseButton and not node.disabled: controls.append(node)
		elif node is Slider: controls.append(node)
	return controls

static func _covers(expected: Dictionary,seen: Dictionary) -> bool:
	for id in expected:
		if not seen.has(id):
			var control: Control=expected[id]
			print("UNREACHED ",control.name," ",control.text if control is Button else "slider")
			return false
	return not expected.is_empty()

static func key(tree: SceneTree,code: int,shift: bool=false) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=code
		event.physical_keycode=code
		event.shift_pressed=shift
		event.pressed=pressed
		Input.parse_input_event(event)
		await ui_frames(tree,2)

static func joy(tree: SceneTree,button: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventJoypadButton.new()
		event.device=0
		event.button_index=button
		event.pressed=pressed
		Input.parse_input_event(event)
		await ui_frames(tree,2)

static func click(tree: SceneTree,at: Vector2) -> void:
	var client:=tree.root.get_final_transform()*at
	var motion:=InputEventMouseMotion.new()
	motion.position=client
	motion.global_position=client
	Input.parse_input_event(motion)
	await ui_frames(tree,2)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=client
		event.global_position=client
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await ui_frames(tree,2)

static func ui_frames(tree: SceneTree,count: int) -> void:
	# UI input is settled by rendered frames; physics may catch up multiple ticks.
	for index in range(count): await tree.process_frame

static func frames(tree: SceneTree,count: int) -> void:
	for index in range(count): await tree.physics_frame

static func check(result: Dictionary,condition: bool,description: String) -> void:
	result["checks"]+=1
	if not condition: result["failures"]+=1
	print(("PASS " if condition else "FAIL ")+description)
