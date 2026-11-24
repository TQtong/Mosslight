extends SceneTree
const Catalog=preload("res://scripts/campaign.gd")
## Checks complete translations, bundled glyph coverage, layout and live switching.
var game
var i18n
var failures: int = 0
var checks: int = 0
var original_language_path: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	i18n = root.get_node("I18n")
	var initial_locale: String = i18n.current
	original_language_path=i18n.preferences_path
	i18n.preferences_path="user://qa_localization_language.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://qa_localization_test.json"
	game.settings_path="user://qa_localization_test_settings.cfg"
	root.add_child(game)
	game.audio.muted = true
	await frames(3)
	check(i18n.locales.size() == 10, "Ten languages are available")
	var keys: Dictionary = i18n.catalog["messages"]
	var lessons: Array=[]
	var lesson_kinds: Array=[]
	for index in range(Catalog.COUNT):
		for lesson in Catalog.stage(index)["lessons"]:
			if not lesson["kind"] in lesson_kinds:
				lesson_kinds.append(lesson["kind"])
				lessons.append(lesson)
	for code in i18n.locales:
		i18n.set_language(code, false)
		await frames(2)
		var complete := true
		var expected_font: String={"zh_TW":"tc","ja":"jp","ko":"kr"}.get(code,"sc")
		check(i18n.CJK_FONT.resource_path=="res://assets/fonts/NotoSansCJK%s-Regular.otf" % expected_font,code+": the correct regional font is selected")
		check(game.hud.root.theme.default_font==i18n.CJK_FONT,code+": the rebuilt HUD uses the selected font")
		var missing := ""
		for key in keys:
			var translated: String = i18n.text(key)
			if translated.is_empty() or translated == key:
				complete = false
			for c in translated:
				if not i18n.CJK_FONT.has_char(c.unicode_at(0)) and not c.strip_edges().is_empty():
					missing += c
		for native_name in i18n.native_names:
			for c in native_name:
				if not i18n.CJK_FONT.has_char(c.unicode_at(0)) and not c.strip_edges().is_empty():
					missing += c
		check(complete, code + ": every translation key resolves")
		check(missing.is_empty(), code + ": bundled font covers all UI characters (missing: " + missing + ")")
		game.show_title()
		await frames(2)
		check(layout_fits(game.hud.root), code + ": title layout fits")
		game.hud.show_map()
		await frames(2)
		check(layout_fits(game.hud.root),code+": campaign map fits")
		game.show_credits()
		await frames(2)
		check(layout_fits(game.hud.root),code+": credits fit")
		for kind in ["backup","defaults"]:
			game.hud.show_load_notice(kind)
			await frames(2)
			check(layout_fits(game.hud.root),code+": "+kind+" recovery notice fits")
		check("\nTQ\n" in i18n.text("CREDITS_BODY"),code+": producer is credited as TQ")
		game.hud.show_ending()
		await frames(2)
		check(layout_fits(game.hud.root),code+": story ending fits")
		game.hud.show_ending(36)
		await frames(2)
		check(layout_fits(game.hud.root),code+": complete collection ending fits")
		for chapter in range(3):
			game.hud.show_chapter(chapter)
			await frames(2)
			check(layout_fits(game.hud.root),code+": chapter %d story fits" % (chapter+1))
		game.hud.show_rekindling()
		await frames(2)
		check(layout_fits(game.hud.root),code+": beacon sequence text fits")
		game.show_title()
		game.hud.show_language()
		await frames(2)
		check(layout_fits(game.hud.root), code + ": language layout fits")
		check(game.hud.overlay.find_child("Language_" + code, true, false) != null, code + ": selectable language button exists")
		game.show_title()
		game.hud.show_settings()
		await frames(2)
		check(layout_fits(game.hud.root),code+": settings layout fits")
		game.hud._show_controls()
		await frames(2)
		check(layout_fits(game.hud.root),code+": keyboard controls fit")
		game.hud._start_binding("music")
		await frames(2)
		check(layout_fits(game.hud.root),code+": key capture prompt fits")
		game.hud.binding_result(ERR_ALREADY_IN_USE)
		await frames(2)
		check(layout_fits(game.hud.root),code+": duplicate key warning fits")
		game.hud._back_controls()
		game.hud.clear_overlay()
		for lesson in lessons:
			game.hud.show_guide(lesson["title"],lesson["body"],lesson["actions"])
			await frames(2)
			check(layout_fits(game.hud.root),code+": "+lesson["kind"]+" guidance fits")
		game.hud.clear_guide()
		game.start_run()
		await frames(3)
		check(layout_fits(game.hud.root), code + ": gameplay layout fits")
		game.hud.set_checkpoint(true)
		game.hud.notify("CHECKPOINT_TOAST")
		await frames(2)
		check(layout_fits(game.hud.root), code + ": checkpoint prompts fit")
		game.pause_run()
		await frames(2)
		check(layout_fits(game.hud.root), code + ": pause layout fits")
		for reason in ["FOCUS_PAUSED","CONTROLLER_PAUSED"]:
			game.hud.show_pause(reason)
			await frames(2)
			check(layout_fits(game.hud.root),code+": "+reason+" notice fits")
		game.hud.show_complete(18, 23, 123.0, 2, true)
		await frames(2)
		check(layout_fits(game.hud.root), code + ": victory layout fits")
		game.hud.set_assisted(true)
		game.hud.show_complete(18,23,123.0,2,true)
		await frames(2)
		check(layout_fits(game.hud.root),code+": assisted victory fits")
		game.hud.set_assisted(false)
	game.start_run()
	await frames(4)
	game._on_checkpoint_reached()
	game.pause_run()
	var elapsed_before: float = game.elapsed
	var at_before: Vector2 = game.player.position
	game.hud.show_language()
	var language_button = game.hud.overlay.find_child("Language_en", true, false)
	language_button.pressed.emit()
	await frames(3)
	check(i18n.current == "en" and game.hud.screen == "language", "Language button switches locale in place")
	check(game.mode == "paused" and game.elapsed == elapsed_before and game.player.position == at_before, "Language change preserves paused run state")
	check(game.hud.objective.text == i18n.text("CHECKPOINT_OBJECTIVE"), "Checkpoint objective retranslates")
	check(game.hud.toast.text == i18n.text("CHECKPOINT_TOAST"), "Checkpoint notification retranslates")
	var config := ConfigFile.new()
	config.load(i18n.preferences_path)
	check(config.get_value("language", "locale", "") == "en", "Language preference is persisted")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await frames(2)
	check(game.hud.screen == "paused" and game.mode == "paused", "Escape returns from language menu without resuming")
	game.resume_run()
	await frames(3)
	check(game.mode == "playing" and game.hud.screen == "playing", "Resume works after switching language")
	check(i18n.resolve_locale("zh-Hant-HK") == "zh_TW" and i18n.resolve_locale("pt_PT") == "pt_BR" and i18n.resolve_locale("xx_YY") == "en", "Locale normalization and fallback work")
	i18n.set_language(initial_locale, false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(i18n.preferences_path))
	i18n.preferences_path=original_language_path
	print("LOCALIZATION RESULT: %d/%d passed" % [checks - failures, checks])
	game.queue_free()
	await frames(3)
	OS.delay_msec(180)
	await frames(3)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_localization_test.json" + suffix))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_localization_test_settings.cfg"+suffix))
	quit(1 if failures else 0)

func layout_fits(node: Node) -> bool:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if node is Button or node is Label:
			if rect.position.x < -1 or rect.position.y < -1 or rect.end.x > 1281 or rect.end.y > 721:
				print("OUTSIDE VIEWPORT: ", node.text, " ", rect)
				return false
			var font: Font = node.get_theme_font("font")
			var size: int = node.get_theme_font_size("font_size")
			var text_size: Vector2 = font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			var wrapped: bool=node is Label and node.autowrap_mode!=TextServer.AUTOWRAP_OFF
			if wrapped:
				if node.get_line_count()*font.get_height(size)>rect.size.y+2:
					print("PARAGRAPH OVERFLOW: ",node.text)
					return false
			elif text_size.x > rect.size.x + 1 or text_size.y > rect.size.y + 2:
				print("TEXT OVERFLOW: ", node.text, " text=", text_size, " box=", rect.size)
				return false
	for child in node.get_children():
		if not layout_fits(child):
			return false
	return true

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS " if condition else "FAIL ") + description)
