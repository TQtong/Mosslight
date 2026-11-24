extends CanvasLayer
## Carved signs, compact game counters, and language changes without resetting a run.
signal start_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal mute_requested
signal music_requested
signal quit_requested
signal stage_requested(index: int)
signal next_requested
signal credits_requested
signal setting_requested(key: String,value: Variant)
signal binding_requested(action: String,keycode: int)
signal bindings_reset_requested
signal chapter_requested

const Art = preload("res://scripts/game_ui_art.gd")
const WOOD = preload("res://assets/ui/wood_sign.svg")
const FOCUS = preload("res://assets/ui/sign_focus.svg")
const SLIDER_THUMB = preload("res://assets/ui/slider_thumb.svg")
const Preferences=preload("res://scripts/preferences.gd")
const CREAM := Color("fff0c3")
const GOLD := Color("f8d58c")
const SHADOW := Color("253c31")
var root: Control
var game_hud: Control
var overlay: Control
var counter: Label
var timer: Label
var death_counter: Label
var objective: Label
var toast: Label
var sound_button: Button
var music_button: Button
var hud_art: Control
var toast_left: float = 0.0
var toast_key: String = "CHECKPOINT_TOAST"
var screen: String = "menu"
var language_return: String = "menu"
var checkpoint_lit: bool = false
var muted: bool = false
var music_muted: bool = false
var run_coins: int = 0
var run_total: int = 23
var run_elapsed: float = 0
var run_deaths: int = 0
var run_progress: float = 0
var best_seconds: float = 0
var new_best: bool = false
var campaign_entries: Array = []
var selected_stage: int = 0
var has_journey: bool = false
var stage_key: String = "LEVEL_01"
var has_air_jump: bool = false
var has_dash: bool = false
var relic_count: int = 0
var stage_label: Label
var relic_label: Label
var ability_label: Label
var save_problem: bool = false
var save_warning: Label
var preferences
var settings_return: String="menu"
var pending_action: String=""
var binding_notice: String=""
var assisted: bool=false
var toast_args: Array=[]
var chapter_index: int=0
var ending_seeds: int=0
var guide_title_key: String=""
var guide_body_key: String=""
var guide_actions: Array=[]
var guide_left: float=0
var guide_panel: Panel
var guide_title: Label
var guide_body: Label
var using_gamepad: bool=false
var key_hints: Control
var pause_button: Button
var active_joypad: int=-1
var pause_reason_key: String=""
var load_notice_kind: String=""

func _ready() -> void:
	layer = 10
	I18n.changed.connect(_rebuild)
	_rebuild()

func _input(event: InputEvent) -> void:
	var gamepad_event: bool=(event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value)>.35)
	var keyboard_event: bool=(event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if gamepad_event: active_joypad=event.device
	if (gamepad_event and not using_gamepad) or (keyboard_event and using_gamepad):
		using_gamepad=gamepad_event
		_update_control_prompts()
	if not pending_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo:
			var code: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
			if code==KEY_ESCAPE:
				pending_action=""
				binding_notice=""
				_render_screen()
			else: binding_requested.emit(pending_action,code)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			pending_action=""
			binding_notice=""
			_render_screen()
			get_viewport().set_input_as_handled()
			return
	var back: bool=event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if screen=="load_notice" and back:
		menu_requested.emit()
		get_viewport().set_input_as_handled()
	elif screen=="controls" and back:
		_back_controls()
		get_viewport().set_input_as_handled()
	elif screen=="settings" and back:
		_back_settings()
		get_viewport().set_input_as_handled()
	elif screen == "language" and back:
		_leave_language()
		get_viewport().set_input_as_handled()
	elif screen in ["map","credits","ending","chapter"] and back:
		menu_requested.emit()
		get_viewport().set_input_as_handled()
	elif screen=="paused" and event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	toast_left = maxf(0, toast_left - delta)
	toast.visible = toast_left > 0 and screen == "playing"
	ability_label.visible = toast_left<=0
	if screen=="playing": guide_left=maxf(0,guide_left-delta)
	guide_panel.visible=screen=="playing" and guide_left>0
	objective.visible=not guide_panel.visible

func _rebuild() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	root = Control.new()
	root.theme = Theme.new()
	root.theme.default_font = I18n.CJK_FONT
	root.theme.default_font_size = 18
	root.theme.set_stylebox("panel", "TooltipPanel", _wood_style())
	root.theme.set_color("font_color", "TooltipLabel", CREAM)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	game_hud = Control.new()
	game_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(game_hud)
	_panel(game_hud, Rect2(22, 20, 184, 64))
	_panel(game_hud, Rect2(554, 20, 172, 58))
	hud_art = _art(game_hud, "hud")
	counter = _label(game_hud, "", Rect2(76, 26, 116, 44), 27)
	counter.tooltip_text = I18n.text("LIGHTS")
	timer = _label(game_hud, "", Rect2(608, 25, 105, 42), 24)
	death_counter = _label(game_hud, "", Rect2(61, 90, 310, 29), 16)
	relic_label = _label(game_hud,"",Rect2(228,28,150,44),25,GOLD)
	stage_label = _label(game_hud,"",Rect2(360,88,560,35),16,CREAM,true)
	ability_label = _label(game_hud,"",Rect2(360,121,560,30),14,GOLD,true)
	music_button = _audio_button(game_hud, "music", Rect2(1036, 20, 64, 58))
	sound_button = _audio_button(game_hud, "sound", Rect2(1112, 20, 64, 58))
	pause_button = _icon_button(game_hud, "pause", Rect2(1188, 20, 64, 58), func() -> void: pause_requested.emit())
	pause_button.tooltip_text = I18n.text("PAUSE") + " ("+_key("pause")+")"
	objective = _label(game_hud, "", Rect2(270, 604, 740, 55), 19, CREAM, true)
	guide_panel=Panel.new()
	guide_panel.position=Vector2(214,570)
	guide_panel.size=Vector2(852,88)
	guide_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	guide_panel.add_theme_stylebox_override("panel",_wood_style(Color(.8,.88,.8)))
	game_hud.add_child(guide_panel)
	guide_title=_label(guide_panel,"",Rect2(18,4,816,25),17,GOLD,true)
	guide_body=_label(guide_panel,"",Rect2(22,29,808,51),16,CREAM,true)
	guide_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_update_guide_text()
	key_hints=Control.new()
	key_hints.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game_hud.add_child(key_hints)
	_build_key_hints()
	toast = _label(game_hud, _toast_text(), Rect2(265, 128, 750, 55), 29, GOLD, true)
	toast.add_theme_constant_override("outline_size", 8)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	save_warning=_label(root,I18n.text("SAVE_ERROR"),Rect2(30,0,1220,20),13,GOLD,true)
	save_warning.visible=save_problem
	set_checkpoint(checkpoint_lit)
	set_muted(muted)
	update_run(run_coins, run_total, run_elapsed, run_deaths, run_progress)
	set_stage(stage_key,selected_stage,has_air_jump,has_dash)
	set_relics(relic_count)
	_render_screen()

func configure_preferences(value: RefCounted) -> void:
	preferences=value
	_rebuild()

func set_assisted(value: bool) -> void:
	assisted=value

func show_settings() -> void:
	settings_return=screen
	screen="settings"
	_render_screen()

func _back_settings() -> void:
	screen=settings_return
	_render_screen()

func _show_controls() -> void:
	pending_action=""
	binding_notice=""
	screen="controls"
	_render_screen()

func _back_controls() -> void:
	pending_action=""
	binding_notice=""
	screen="settings"
	_render_screen()

func _key(action: String) -> String:
	if using_gamepad:
		var keys: Dictionary={"move_left":"←","move_right":"→","jump":"A","dash":"X","retry":"Y","pause":"Start"}
		if keys.has(action): return keys[action]
	return preferences.binding_name(action) if preferences else OS.get_keycode_string(Preferences.PRIMARY[action])

func _prompt(action: String) -> String:
	if using_gamepad and action in ["move_left","move_right","jump","dash","retry","pause"]: return _key(action)
	return preferences.binding_prompt(action) if preferences else _key(action)

func _build_key_hints() -> void:
	for child in key_hints.get_children():
		key_hints.remove_child(child)
		child.queue_free()
	var hint_x: float=28
	hint_x=_key_hint(_key("move_left")+" / "+_key("move_right"),"MOVE",hint_x,54)
	hint_x=_key_hint(_key("jump"),"JUMP",hint_x,73)
	_key_hint(_key("retry"),"RETRY",hint_x,34)

func _update_control_prompts() -> void:
	if not is_instance_valid(key_hints): return
	_build_key_hints()
	_update_guide_text()
	set_stage(stage_key,selected_stage,has_air_jump,has_dash)
	_refresh_audio_buttons()
	pause_button.tooltip_text=I18n.text("PAUSE")+" ("+_key("pause")+")"

func _toast_text() -> String:
	var text:=I18n.text(toast_key)
	return text % toast_args if not toast_args.is_empty() else text

func configure_campaign(entries: Array, selected: int, has_progress: bool) -> void:
	campaign_entries = entries
	selected_stage = selected
	has_journey = has_progress

func set_stage(key: String, index: int, air_jump: bool, dash: bool) -> void:
	stage_key = key
	selected_stage = index
	has_air_jump = air_jump
	has_dash = dash
	_fit_text(stage_label,"%02d · %s" % [index+1,I18n.text(key)],16)
	ability_label.text = ""
	if air_jump: ability_label.text = _key("jump")+" × 2 · " + I18n.text("DOUBLE_JUMP")
	if dash: ability_label.text += "     "+_prompt("dash")+" · " + I18n.text("DASH")
	_fit_text(ability_label,ability_label.text,14)

func set_relics(count: int) -> void:
	relic_count = count
	relic_label.text = "◆ %d / 3" % count
	relic_label.tooltip_text = I18n.text("RELICS")

func set_save_warning(value: bool) -> void:
	save_problem=value
	save_warning.visible=value

func show_map() -> void:
	screen = "map"
	_render_screen()

func show_ending(seeds: int=0) -> void:
	ending_seeds=seeds
	screen = "ending"
	_render_screen()

func show_chapter(index: int) -> void:
	chapter_index=clampi(index,0,2)
	screen="chapter"
	_render_screen()

func show_rekindling() -> void:
	screen="rekindling"
	_render_screen()

func show_guide(title_key: String,body_key: String,actions: Array=[]) -> void:
	if title_key!=guide_title_key or body_key!=guide_body_key or actions!=guide_actions:
		guide_title_key=title_key
		guide_body_key=body_key
		guide_actions=actions.duplicate()
		_update_guide_text()
	guide_left=6.0

func clear_guide() -> void:
	guide_left=0
	guide_title_key=""
	guide_body_key=""
	guide_actions=[]

func _update_guide_text() -> void:
	if not is_instance_valid(guide_title) or guide_title_key.is_empty(): return
	guide_title.text=I18n.text(guide_title_key)
	var values: Array=[]
	for action in guide_actions: values.append(_key(action))
	var text:=I18n.text(guide_body_key)
	guide_body.text=text % values if not values.is_empty() else text

func show_credits() -> void:
	screen = "credits"
	_render_screen()

func update_run(coins: int, total: int, elapsed: float, deaths: int, progress: float) -> void:
	run_coins = coins
	run_total = total
	run_elapsed = elapsed
	run_deaths = deaths
	run_progress = progress
	counter.text = "%02d / %02d" % [coins, total]
	timer.text = _time(elapsed)
	death_counter.text = "%s  %d" % [I18n.text("FALLS"), deaths]
	if assisted: death_counter.text+=" · "+I18n.text("ASSIST_SHORT")
	hud_art.progress = progress
	objective.modulate.a = 1.0 if checkpoint_lit else clampf(12 - elapsed, 0, 1)

func set_checkpoint(value: bool) -> void:
	checkpoint_lit = value
	_fit_text(objective, I18n.text("CHECKPOINT_OBJECTIVE" if value else "OBJECTIVE"), 19)

func notify(key: String,args: Array=[]) -> void:
	toast_key = key
	toast_args=args
	_fit_text(toast, _toast_text(), 29)
	toast_left = 3.5

func refresh_preferences() -> void:
	if not preferences: return
	for key in ["music_volume","sfx_volume"]:
		var value_label=overlay.get_node_or_null("Value_"+key)
		var slider=overlay.get_node_or_null("Volume_"+key)
		if value_label: value_label.text="%d%%" % int(preferences.values[key])
		if slider: slider.set_value_no_signal(float(preferences.values[key]))
	for key in ["fullscreen","vsync","assist","reduced_motion"]:
		var button=overlay.get_node_or_null("Toggle_"+key)
		if button: button.text=I18n.text("ON" if bool(preferences.values[key]) else "OFF")
	_update_motion(root,bool(preferences.values["reduced_motion"]))

func _update_motion(node: Node, reduced: bool) -> void:
	if node.get_script()==Art: node.reduced_motion=reduced
	for child in node.get_children(): _update_motion(child,reduced)

func _start_binding(action: String) -> void:
	pending_action=action
	binding_notice=""
	_render_screen()

func binding_result(result: Error, reset: bool=false) -> void:
	var action:=pending_action
	if result==OK:
		pending_action=""
		binding_notice="BINDINGS_RESET" if reset else "BINDING_SAVED"
		_rebuild()
		var button=overlay.get_node_or_null("Bind_"+action)
		if button: button.grab_focus()
	else:
		binding_notice="KEY_USED" if result==ERR_ALREADY_IN_USE else ("KEY_RESERVED" if result==ERR_UNAVAILABLE else "SAVE_ERROR")
		_render_screen()

func set_muted(value: bool) -> void:
	muted = value
	_refresh_audio_buttons()

func set_music_muted(value: bool) -> void:
	music_muted = value
	_refresh_audio_buttons()

func _refresh_audio_buttons() -> void:
	for parent in [game_hud, overlay]:
		if not is_instance_valid(parent):
			continue
		for button in parent.get_children():
			if button is Button and button.has_meta("audio_kind"):
				_update_audio_button(button)

func _update_audio_button(button: Button) -> void:
	var is_music: bool = button.get_meta("audio_kind") == "music"
	var off := music_muted if is_music else muted
	var key := ("MUSIC_OFF" if off else "MUSIC_ON") if is_music else ("SOUND_OFF" if off else "SOUND_ON")
	button.tooltip_text = I18n.text(key) + " ("+_key("music" if is_music else "mute")+")"
	for icon in button.get_children():
		icon.muted = off

func clear_overlay() -> void:
	screen = "playing"
	_render_screen()

func show_menu(best: float = 0) -> void:
	best_seconds = best
	screen = "menu"
	_render_screen()

func show_load_notice(kind: String) -> void:
	load_notice_kind=kind
	screen="load_notice"
	_render_screen()

func show_pause(reason: String="") -> void:
	pause_reason_key=reason
	screen = "paused"
	_render_screen()

func show_complete(coins: int, total: int, elapsed: float, deaths: int, record: bool) -> void:
	run_coins = coins
	run_total = total
	run_elapsed = elapsed
	run_deaths = deaths
	new_best = record
	screen = "complete"
	_render_screen()

func show_language() -> void:
	language_return = screen
	screen = "language"
	_render_screen()

func _leave_language() -> void:
	screen = language_return
	_render_screen()

func _render_screen() -> void:
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	game_hud.visible = screen == "playing"
	overlay.visible = screen != "playing"
	if screen == "playing":
		return
	var art_kind := "title" if screen=="menu" else screen
	if screen in ["map","credits","ending","settings","controls"]: art_kind="language"
	if screen=="load_notice": art_kind="chapter"
	_art(overlay, art_kind)
	_audio_button(overlay, "music", Rect2(1112, 20, 64, 58))
	_audio_button(overlay, "sound", Rect2(1188, 20, 64, 58))
	match screen:
		"menu": _title_screen()
		"paused": _pause_screen()
		"complete": _complete_screen()
		"language": _language_screen()
		"map": _map_screen()
		"ending": _story_screen(false)
		"credits": _story_screen(true)
		"settings": _settings_screen()
		"controls": _controls_screen()
		"chapter": _chapter_screen()
		"rekindling": _rekindling_screen()
		"load_notice": _load_notice_screen()
	refresh_preferences()
	_configure_focus()

func focus_controls() -> Array[Control]:
	var controls: Array[Control]=[]
	for child in overlay.find_children("*","Control",true,false):
		if child.focus_mode!=Control.FOCUS_ALL or not child.is_visible_in_tree(): continue
		if child is BaseButton and child.disabled: continue
		controls.append(child)
	return controls

func _configure_focus() -> void:
	# Rows make D-pad travel predictable and keep every visible control reachable.
	var controls:=focus_controls()
	if controls.is_empty(): return
	controls.sort_custom(func(a: Control,b: Control) -> bool:
		var ac:=a.get_global_rect().get_center()
		var bc:=b.get_global_rect().get_center()
		return ac.x<bc.x if absf(ac.y-bc.y)<1 else ac.y<bc.y
	)
	var rows: Array=[]
	for control in controls:
		if rows.is_empty() or absf(control.get_global_rect().get_center().y-rows[-1][0].get_global_rect().get_center().y)>20:
			rows.append([])
		rows[-1].append(control)
	for row_index in range(rows.size()):
		var row: Array=rows[row_index]
		for column in range(row.size()):
			var control: Control=row[column]
			control.focus_neighbor_left=control.get_path_to(row[(column+row.size()-1)%row.size()])
			control.focus_neighbor_right=control.get_path_to(row[(column+1)%row.size()])
			for side in [-1,1]:
				var adjacent: Array=rows[(row_index+rows.size()+side)%rows.size()]
				var next: Control=adjacent[0]
				var x:=control.get_global_rect().get_center().x
				for candidate in adjacent:
					if absf(candidate.get_global_rect().get_center().x-x)<absf(next.get_global_rect().get_center().x-x): next=candidate
				if side<0: control.focus_neighbor_top=control.get_path_to(next)
				else: control.focus_neighbor_bottom=control.get_path_to(next)
	for i in range(controls.size()):
		controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous=controls[i].get_path_to(controls[(i+controls.size()-1)%controls.size()])
	var focused:=get_viewport().gui_get_focus_owner()
	if focused==null or not overlay.is_ancestor_of(focused): controls[0].grab_focus()

func _load_notice_screen() -> void:
	var prefix: String="SAVE_DEFAULTS" if load_notice_kind=="defaults" else "SAVE_RECOVERED"
	var heading:=_label(overlay,I18n.text(prefix+"_TITLE"),Rect2(168,91,944,66),32,CREAM,true,true)
	heading.name="LoadNoticeTitle"
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var body:=_label(overlay,"",Rect2(245,248,790,240),23,CREAM,true)
	body.name="LoadNoticeBody"
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.text=I18n.text(prefix+"_BODY")
	var acknowledge:=_button(overlay,I18n.text("LOAD_NOTICE_OK"),Rect2(453,540,374,62),func() -> void: menu_requested.emit(),true)
	acknowledge.name="LoadNoticeOK"
	acknowledge.grab_focus()

func _chapter_screen() -> void:
	_label(overlay,I18n.text("CHAPTER_%d" % (chapter_index+1)),Rect2(168,91,944,66),34,CREAM,true,true)
	var body:=_label(overlay,"",Rect2(245,239,790,264),23,CREAM,true)
	body.name="ChapterStory"
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.text=I18n.text("STORY_%d" % (chapter_index+1))
	var begin:=_button(overlay,I18n.text("BEGIN_CHAPTER"),Rect2(453,540,374,62),func() -> void: chapter_requested.emit(),true)
	begin.name="BeginChapter"
	_button(overlay,I18n.text("TITLE_SCREEN"),Rect2(500,621,280,51),func() -> void: menu_requested.emit())
	begin.grab_focus()

func _rekindling_screen() -> void:
	_label(overlay,I18n.text("BEACON_AWAKENS"),Rect2(160,586,960,45),30,GOLD,true,true)
	_label(overlay,I18n.text("BEACON_HOME"),Rect2(160,638,960,42),18,CREAM,true)

func _settings_screen() -> void:
	if not preferences: return
	_label(overlay,I18n.text("SETTINGS"),Rect2(384,91,512,66),37,CREAM,true,true)
	_volume_row("music_volume","MUSIC_VOLUME",210)
	_volume_row("sfx_volume","SFX_VOLUME",270)
	_boolean_row("fullscreen","FULLSCREEN",328)
	_boolean_row("vsync","VSYNC",382)
	_boolean_row("assist","ASSIST_MODE",436)
	_boolean_row("reduced_motion","REDUCED_MOTION",490)
	var controls:=_button(overlay,I18n.text("KEYBOARD_CONTROLS"),Rect2(340,568,284,56),_show_controls)
	controls.name="ControlsButton"
	_button(overlay,I18n.text("BACK"),Rect2(656,568,284,56),_back_settings)
	var hint:=_label(overlay,"",Rect2(170,637,940,62),15,CREAM,true)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.text=I18n.text("ASSIST_HINT")
	controls.grab_focus()

func _volume_row(key: String,label_key: String,y: float) -> void:
	_label(overlay,I18n.text(label_key),Rect2(270,y,295,36),20)
	var slider:=HSlider.new()
	slider.name="Volume_"+key
	slider.position=Vector2(600,y+3)
	slider.size=Vector2(365,30)
	slider.min_value=0
	slider.max_value=100
	slider.step=1
	slider.value=float(preferences.values[key])
	slider.focus_mode=Control.FOCUS_ALL
	var track:=StyleBoxFlat.new()
	track.bg_color=Color("3e4d36")
	track.border_color=Color("b99b63")
	track.set_border_width_all(1)
	track.content_margin_top=4
	track.content_margin_bottom=4
	slider.add_theme_stylebox_override("slider",track)
	var fill:=track.duplicate() as StyleBoxFlat
	fill.bg_color=Color("c5a765")
	slider.add_theme_stylebox_override("grabber_area",fill)
	slider.add_theme_stylebox_override("grabber_area_highlight",fill)
	slider.add_theme_icon_override("grabber",SLIDER_THUMB)
	slider.add_theme_icon_override("grabber_highlight",SLIDER_THUMB)
	var focus:=StyleBoxFlat.new()
	focus.bg_color=Color.TRANSPARENT
	focus.border_color=GOLD
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(5)
	slider.add_theme_stylebox_override("focus",focus)
	slider.value_changed.connect(func(value: float) -> void: setting_requested.emit(key,value))
	overlay.add_child(slider)
	var percent:=_label(overlay,"%d%%" % int(preferences.values[key]),Rect2(992,y,90,36),20,GOLD,true)
	percent.name="Value_"+key

func _boolean_row(key: String,label_key: String,y: float) -> void:
	_label(overlay,I18n.text(label_key),Rect2(270,y,310,40),19)
	var button:=_button(overlay,I18n.text("ON" if bool(preferences.values[key]) else "OFF"),Rect2(600,y-3,230,49),func() -> void: setting_requested.emit(key,not bool(preferences.values[key])))
	button.name="Toggle_"+key
	if key=="fullscreen": button.tooltip_text="F11"
	if key=="reduced_motion": button.tooltip_text=I18n.text("MOTION_HINT")

func _controls_screen() -> void:
	if not preferences: return
	_label(overlay,I18n.text("KEYBOARD_CONTROLS"),Rect2(384,91,512,66),34,CREAM,true,true)
	var hint:=I18n.text("KEYBOARD_HINT")
	if not pending_action.is_empty(): hint=I18n.text("PRESS_NEW_KEY") % I18n.text(Preferences.ACTION_LABELS[pending_action])
	if not binding_notice.is_empty(): hint=I18n.text(binding_notice)
	_label(overlay,hint,Rect2(130,174,1020,31),16,GOLD,true)
	var first: Button
	var i:=0
	for action in Preferences.PRIMARY:
		var y:=211+i*47
		_label(overlay,I18n.text(Preferences.ACTION_LABELS[action]),Rect2(309,y,345,40),18)
		var text: String="..." if pending_action==action else preferences.binding_name(action)
		var button:=_button(overlay,text,Rect2(692,y,272,43),func() -> void: _start_binding(action),pending_action==action)
		button.add_theme_font_size_override("font_size",17)
		button.size.y=43
		button.name="Bind_"+action
		if i==0: first=button
		i+=1
	var reset:=_button(overlay,I18n.text("RESET_BINDINGS"),Rect2(326,608,300,56),func() -> void: bindings_reset_requested.emit())
	reset.name="ResetBindings"
	_button(overlay,I18n.text("BACK"),Rect2(656,608,300,56),_back_controls)
	_label(overlay,I18n.text("ESC_CANCEL"),Rect2(160,677,960,27),14,CREAM,true)
	if first: first.grab_focus()

func _title_screen() -> void:
	if I18n.text("TITLE") != "Mosslight":
		_label(overlay, "M O S S L I G H T", Rect2(360, 94, 560, 35), 18, GOLD, true)
	_label(overlay, I18n.text("TITLE"), Rect2(302, 143, 676, 100), 72, CREAM, true, true)
	_label(overlay, I18n.text("TAGLINE"), Rect2(210, 273, 860, 42), 24, CREAM, true)
	_label(overlay, I18n.text("CHAPTER_%d" % (selected_stage/4+1)), Rect2(180, 311, 920, 36), 17, GOLD, true)
	var begin := _button(overlay, I18n.text("CONTINUE" if has_journey else "START"), Rect2(457, 380, 366, 69), func() -> void: start_requested.emit(), true)
	_button(overlay, I18n.text("LEVEL_SELECT"), Rect2(477, 462, 326, 59), show_map)
	_button(overlay, I18n.text("SETTINGS"), Rect2(377,533,252,59),show_settings)
	_button(overlay, I18n.text("LANGUAGE_BUTTON"), Rect2(651,533,252,59),show_language)
	_button(overlay, I18n.text("CREDITS"), Rect2(377,603,252,51),func() -> void: credits_requested.emit())
	_button(overlay, I18n.text("QUIT"), Rect2(651,603,252,51),func() -> void: quit_requested.emit())
	if best_seconds > 0:
		_label(overlay, I18n.text("BEST") + "  " + _time(best_seconds), Rect2(250, 346, 780, 26), 14, GOLD, true)
	_label(overlay, I18n.text("PRESS_START"), Rect2(160, 661, 960, 31), 16, CREAM, true)
	begin.grab_focus()

func _pause_screen() -> void:
	_label(overlay, I18n.text("PAUSED"), Rect2(432, 128, 416, 64), 38, CREAM, true, true)
	if not pause_reason_key.is_empty(): _label(overlay,I18n.text(pause_reason_key),Rect2(155,197,970,32),17,GOLD,true)
	var resume := _button(overlay, I18n.text("RESUME"), Rect2(450, 241, 380, 64), func() -> void: resume_requested.emit(), true)
	_button(overlay, I18n.text("RESTART"), Rect2(466, 318, 348, 58), func() -> void: restart_requested.emit())
	_button(overlay,I18n.text("SETTINGS"),Rect2(466,389,348,58),show_settings)
	_button(overlay,I18n.text("LANGUAGE_BUTTON"),Rect2(466,460,348,58),show_language)
	_button(overlay,I18n.text("TITLE_SCREEN"),Rect2(466,531,348,58),func() -> void: menu_requested.emit())
	_label(overlay,_key("move_left")+" / "+_key("move_right")+" · "+I18n.text("MOVE")+"     "+_key("jump")+" · "+I18n.text("JUMP"),Rect2(190,605,900,35),16,CREAM,true)
	_label(overlay,I18n.text("HOLD_JUMP"),Rect2(190,644,900,31),16,CREAM,true)
	resume.grab_focus()

func _complete_screen() -> void:
	_label(overlay, I18n.text("VICTORY"), Rect2(185, 154, 910, 76), 53, CREAM, true, true)
	_label(overlay, I18n.text("VICTORY_NOTE"), Rect2(155, 235, 970, 46), 20, CREAM, true)
	var values := ["%02d / %02d" % [run_coins, run_total], _time(run_elapsed), str(run_deaths)]
	var keys := ["LIGHTS", "TIME", "FALLS"]
	for i in range(3):
		_label(overlay, values[i], Rect2(384 + i * 186, 315, 140, 43), 27, CREAM, true)
		_label(overlay, I18n.text(keys[i]), Rect2(369 + i * 186, 365, 170, 35), 16, GOLD, true)
	if new_best or assisted:
		var badge:=I18n.text("ASSISTED_RUN") if assisted else I18n.text("NEW_BEST")
		if assisted and new_best: badge+=" · "+I18n.text("NEW_BEST")
		_label(overlay,badge,Rect2(220,418,840,35),24,GOLD,true)
	var again := _button(overlay, I18n.text("ENDING" if selected_stage==11 else "NEXT_LEVEL"), Rect2(453, 476, 374, 65), func() -> void: next_requested.emit(), true)
	_button(overlay, I18n.text("RESTART"), Rect2(377, 555, 252, 58), func() -> void: restart_requested.emit())
	_button(overlay, I18n.text("TITLE_SCREEN"), Rect2(651, 555, 252, 58), func() -> void: menu_requested.emit())
	again.grab_focus()

func _map_screen() -> void:
	_label(overlay,I18n.text("LEVEL_SELECT"),Rect2(384,91,512,66),37,CREAM,true,true)
	_label(overlay,I18n.text("MAP_HINT"),Rect2(120,178,1040,35),16,CREAM,true)
	var focus: Button
	for i in range(campaign_entries.size()):
		var entry: Dictionary = campaign_entries[i]
		var button := _button(overlay,"",Rect2(211+(i%3)*286,224+(i/3)*90,264,80),func() -> void: stage_requested.emit(i))
		button.name="Stage_%02d" % i
		button.disabled = not entry["unlocked"]
		if button.disabled: button.modulate = Color(.65,.7,.7)
		_label(button,"%02d · %s" % [i+1,I18n.text(entry["name"])],Rect2(16,8,232,32),17,CREAM,true)
		var record: Dictionary=entry["record"]
		var status := I18n.text("LOCKED") if not entry["unlocked"] else I18n.text("AVAILABLE")
		if record.get("completed",false):
			var normal: float=record.get("best_time",0)
			status="◆ %d / 3    %s" % [int(record.get("relics",0)),_time(normal if normal>0 else float(record.get("assist_time",0)))]
			if normal<=0: status+=" · "+I18n.text("ASSIST_SHORT")
		elif int(record.get("relics",0))>0: status="◆ %d / 3 · %s" % [int(record.get("relics",0)),I18n.text("AVAILABLE")]
		_label(button,status,Rect2(16,44,232,26),13,GOLD,true)
		if i==selected_stage and entry["unlocked"]: focus=button
	_button(overlay,I18n.text("BACK"),Rect2(500,612,280,59),func() -> void: menu_requested.emit())
	if focus: focus.grab_focus()

func _story_screen(credits: bool) -> void:
	_label(overlay,I18n.text("CREDITS" if credits else "ENDING"),Rect2(384,91,512,66),37,CREAM,true,true)
	var body := _label(overlay,"",Rect2(190,218,900,310),22,CREAM,true)
	body.name="StoryBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text=I18n.text("CREDITS_BODY" if credits else ("ENDING_ALL" if ending_seeds>=36 else "ENDING_BODY"))
	if not credits: _label(overlay,I18n.text("SEEDS_TOTAL") % ending_seeds,Rect2(190,183,900,30),17,GOLD,true)
	var back := _button(overlay,I18n.text("TITLE_SCREEN"),Rect2(453,574,374,62),func() -> void: menu_requested.emit(),true)
	if not credits: _button(overlay,I18n.text("CREDITS"),Rect2(477,498,326,59),func() -> void: credits_requested.emit())
	back.grab_focus()

func _language_screen() -> void:
	_label(overlay, I18n.text("LANGUAGE"), Rect2(384, 91, 512, 66), 37, CREAM, true, true)
	_label(overlay, I18n.text("LANGUAGE_HINT"), Rect2(160, 182, 960, 37), 17, CREAM, true)
	var active_button: Button
	for i in range(I18n.locales.size()):
		var code: String = I18n.locales[i]
		var active: bool = code == I18n.current
		var text: String = ("◆  " if active else "") + I18n.native_names[i]
		var rect := Rect2(326 + (i % 2) * 330, 234 + (i / 2) * 61, 300, 54)
		var choose := _button(overlay, text, rect, func() -> void: I18n.set_language(code), active)
		choose.name = "Language_" + code
		if active:
			active_button = choose
	_button(overlay, I18n.text("BACK"), Rect2(500, 570, 280, 59), _leave_language)
	if active_button:
		active_button.grab_focus()

func _key_hint(key: String, action: String, x: float, key_width: float) -> float:
	key_width=maxf(key_width,I18n.CJK_FONT.get_string_size(key,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+16)
	var cap := Panel.new()
	cap.position = Vector2(x, 673)
	cap.size = Vector2(key_width, 27)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("475b48")
	style.border_color = Color("c8b882")
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	cap.add_theme_stylebox_override("panel", style)
	key_hints.add_child(cap)
	_label(cap, key, Rect2(0, 1, key_width, 23), 13, CREAM, true)
	_label(key_hints, I18n.text(action), Rect2(x + key_width + 9, 671, 325, 30), 15)
	return x+key_width+I18n.CJK_FONT.get_string_size(I18n.text(action),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+39

func _art(parent: Node, kind: String) -> Control:
	var decoration := Art.new()
	decoration.scene_kind = kind
	decoration.muted = muted
	decoration.reduced_motion=bool(preferences.values["reduced_motion"]) if preferences else false
	decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(decoration)
	return decoration

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color = CREAM, centered: bool = false, title: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	var font: Font = I18n.font(title)
	while font_size > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 8:
		font_size -= 1
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.07, 0.13, 0.1, 0.75))
	label.add_theme_color_override("font_outline_color", SHADOW)
	label.add_theme_constant_override("outline_size", 5 if title else 3)
	label.add_theme_constant_override("shadow_offset_y", 4 if title else 2)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _panel(parent: Node, rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _wood_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)

func _button(parent: Node, text: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	var font: Font = I18n.CJK_FONT
	var font_size := 23 if primary else 20
	while font_size > 15 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 48:
		font_size -= 1
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, CREAM)
	button.add_theme_color_override("font_outline_color", Color("332b21"))
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_stylebox_override("normal", _wood_style(Color(1.2, 1.12, 0.94) if primary else Color.WHITE))
	button.add_theme_stylebox_override("hover", _wood_style(Color(1.3, 1.25, 1.05)))
	button.add_theme_stylebox_override("pressed", _wood_style(Color(0.85, 0.9, 0.8)))
	button.add_theme_stylebox_override("disabled",_wood_style(Color(.6,.65,.6)))
	var focus := StyleBoxTexture.new()
	focus.texture = FOCUS
	focus.set_texture_margin_all(13)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _icon_button(parent: Node, kind: String, rect: Rect2, action: Callable) -> Button:
	var button := _button(parent, "", rect, action)
	# Gameplay controls use their actions; clicking a HUD icon must not capture jump.
	if parent==game_hud: button.focus_mode=Control.FOCUS_NONE
	var icon := Art.new()
	icon.scene_kind = "icon_" + kind
	icon.position = Vector2(15, 12)
	icon.size = Vector2(34, 32)
	icon.muted = muted
	button.add_child(icon)
	return button

func _audio_button(parent: Node, kind: String, rect: Rect2) -> Button:
	var action: Callable = func() -> void: music_requested.emit()
	if kind != "music":
		action = func() -> void: mute_requested.emit()
	var button := _icon_button(parent, kind, rect, action)
	button.name = "MusicToggle" if kind == "music" else "SfxToggle"
	button.set_meta("audio_kind", kind)
	_update_audio_button(button)
	return button

func _wood_style(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = WOOD
	style.set_texture_margin_all(15)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 7
	style.content_margin_bottom = 10
	style.modulate_color = tint
	return style

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _fit_text(label: Label, text: String, font_size: int) -> void:
	var font := label.get_theme_font("font")
	while font_size > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > label.size.x - 8:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	label.text = text
