extends RefCounted
## Validated settings share the legacy ConfigFile, preserving existing records.
const DEFAULT_PATH := "user://mosslight.cfg"
const DEFAULTS := {"music_volume":75.0,"sfx_volume":90.0,"music_muted":false,"muted":false,"fullscreen":false,"vsync":true,"assist":false,"reduced_motion":false}
const PRIMARY := {"move_left":KEY_A,"move_right":KEY_D,"jump":KEY_SPACE,"dash":KEY_SHIFT,"retry":KEY_R,"pause":KEY_ESCAPE,"mute":KEY_M,"music":KEY_N}
const SECONDARY := {"move_left":[KEY_LEFT],"move_right":[KEY_RIGHT],"jump":[KEY_W,KEY_UP],"dash":[KEY_X],"pause":[KEY_ESCAPE]}
const ACTION_LABELS := {"move_left":"MOVE_LEFT","move_right":"MOVE_RIGHT","jump":"JUMP","dash":"DASH","retry":"RETRY","pause":"PAUSE","mute":"SOUND_TOGGLE","music":"MUSIC_TOGGLE"}
var path: String
var config := ConfigFile.new()
var values: Dictionary = DEFAULTS.duplicate()
var bindings: Dictionary = PRIMARY.duplicate()
var last_error: Error = OK
var recovered_backup: bool = false
var used_defaults_after_damage: bool = false

func _init(settings_path: String = DEFAULT_PATH) -> void:
	path=settings_path

func load_settings() -> void:
	recovered_backup=false
	used_defaults_after_damage=false
	config=ConfigFile.new()
	var result:=config.load(path)
	if result!=OK:
		config=ConfigFile.new()
		recovered_backup=config.load(path+".bak")==OK
		used_defaults_after_damage=not recovered_backup and (FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak"))
	values=DEFAULTS.duplicate()
	for key in DEFAULTS:
		var value=config.get_value("settings",key,DEFAULTS[key])
		if DEFAULTS[key] is bool:
			values[key]=value if value is bool else DEFAULTS[key]
		elif (value is float or value is int) and is_finite(float(value)):
			values[key]=clampf(float(value),0,100)
		config.set_value("settings",key,values[key])
	bindings=PRIMARY.duplicate()
	var used: Array=[]
	for action in PRIMARY:
		var raw=config.get_value("bindings",action,PRIMARY[action])
		var valid: bool=(raw is int or raw is float) and is_finite(float(raw)) and float(raw)>0 and float(raw)<10000000
		var keycode: int=int(raw) if valid else int(PRIMARY[action])
		if OS.get_keycode_string(keycode).is_empty() or keycode in used or keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_F11] or (keycode==KEY_ESCAPE and action!="pause"): keycode=PRIMARY[action]
		if keycode in used:
			# A damaged binding section falls back as a whole, avoiding hidden collisions.
			bindings=PRIMARY.duplicate()
			break
		bindings[action]=keycode
		used.append(keycode)
	for action in bindings: config.set_value("bindings",action,bindings[action])

func set_option(key: String, value: Variant) -> Error:
	if not DEFAULTS.has(key): return ERR_INVALID_PARAMETER
	if DEFAULTS[key] is bool:
		if not value is bool: return ERR_INVALID_PARAMETER
		values[key]=value
	else:
		if not (value is float or value is int) or not is_finite(float(value)): return ERR_INVALID_PARAMETER
		values[key]=clampf(float(value),0,100)
	config.set_value("settings",key,values[key])
	return save_settings()

func save_settings() -> Error:
	last_error=config.save(path+".tmp")
	if last_error!=OK: return last_error
	if FileAccess.file_exists(path):
		var previous:=ConfigFile.new()
		if previous.load(path)==OK:
			last_error=DirAccess.copy_absolute(path,path+".bak")
			if last_error!=OK: return last_error
	last_error=DirAccess.rename_absolute(path+".tmp",path)
	return last_error

func rebind(action: String, keycode: int) -> Error:
	if not PRIMARY.has(action) or keycode<=0 or OS.get_keycode_string(keycode).is_empty(): return ERR_INVALID_PARAMETER
	if keycode in [KEY_ESCAPE,KEY_ENTER,KEY_KP_ENTER,KEY_F11]: return ERR_UNAVAILABLE
	for other in bindings:
		if other!=action and int(bindings[other])==keycode: return ERR_ALREADY_IN_USE
	bindings[action]=keycode
	config.set_value("bindings",action,keycode)
	var error:=save_settings()
	apply_input_map()
	return error

func reset_bindings() -> Error:
	bindings=PRIMARY.duplicate()
	for action in bindings: config.set_value("bindings",action,bindings[action])
	var error:=save_settings()
	apply_input_map()
	return error

func binding_name(action: String) -> String:
	return _display_key(int(bindings.get(action,PRIMARY.get(action,0))))

func binding_prompt(action: String) -> String:
	var names: Array[String]=[binding_name(action)]
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var name:=_display_key(event.physical_keycode)
			if not name in names and names.size()<2: names.append(name)
	return " / ".join(names)

func _display_key(physical: int) -> String:
	var logical: int=physical
	if DisplayServer.get_name()!="headless":
		var mapped:=DisplayServer.keyboard_get_keycode_from_physical(physical)
		if mapped!=0: logical=mapped
	return OS.get_keycode_string(logical)

func apply_input_map() -> void:
	for action in PRIMARY:
		if not InputMap.has_action(action): InputMap.add_action(action,.2)
		Input.action_release(action)
		InputMap.action_erase_events(action)
		_add_key(action,int(bindings[action]))
		for keycode in SECONDARY.get(action,[]):
			var owned_elsewhere:=false
			for other in bindings:
				if other!=action and int(bindings[other])==keycode: owned_elsewhere=true
			if not owned_elsewhere and keycode!=int(bindings[action]): _add_key(action,keycode)
	# Escape remains a menu safety key even after rebinding pause.
	if int(bindings["pause"])!=KEY_ESCAPE: _add_key("pause",KEY_ESCAPE)
	if not InputMap.has_action("begin"): InputMap.add_action("begin")
	InputMap.action_erase_events("begin")
	_add_key("begin",KEY_ENTER)
	for pair in [["move_left",JOY_BUTTON_DPAD_LEFT],["move_right",JOY_BUTTON_DPAD_RIGHT],["jump",JOY_BUTTON_A],["dash",JOY_BUTTON_X],["retry",JOY_BUTTON_Y],["pause",JOY_BUTTON_START],["begin",JOY_BUTTON_A]]:
		var event:=InputEventJoypadButton.new()
		event.device=-1
		event.button_index=pair[1]
		InputMap.action_add_event(pair[0],event)
	# Godot's default UI map has D-pad travel but no controller confirm/cancel.
	for pair in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B]]:
		var event:=InputEventJoypadButton.new()
		event.device=-1
		event.button_index=pair[1]
		if not InputMap.action_has_event(pair[0],event): InputMap.action_add_event(pair[0],event)
	for direction in [-1.0,1.0]:
		var event:=InputEventJoypadMotion.new()
		event.device=-1
		event.axis=JOY_AXIS_LEFT_X
		event.axis_value=direction
		InputMap.action_add_event("move_left" if direction<0 else "move_right",event)

func _add_key(action: String, keycode: int) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=keycode
	InputMap.action_add_event(action,event)
