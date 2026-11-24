extends Node
## Native Godot translations, loaded from an editable, UTF-8 JSON catalog.
## Language has its own preferences file so game-record saves cannot overwrite it.

signal changed
const PREFERENCES := "user://mosslight-language.cfg"
var preferences_path: String=PREFERENCES
var CJK_FONT: Font
var TITLE_FONT: Font
const REGIONAL_FONTS={"zh_TW":"NotoSansCJKtc-Regular.otf","ja":"NotoSansCJKjp-Regular.otf","ko":"NotoSansCJKkr-Regular.otf"}
var regional_fonts: Dictionary={}
var locales: PackedStringArray = []
var native_names: PackedStringArray = []
var catalog: Dictionary = {}
var current: String = "zh_CN"

func _ready() -> void:
	# Runtime loading also lets a fresh editor import scan compile this autoload.
	CJK_FONT = _regional_font("zh_CN")
	TITLE_FONT = load("res://assets/fonts/NotoSerif-Variable.ttf")
	ThemeDB.fallback_font = CJK_FONT
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://localization/strings.json"))
	if not parsed is Dictionary:
		push_error("Cannot read localization catalog")
		return
	catalog = parsed
	locales = PackedStringArray(catalog["locales"])
	native_names = PackedStringArray(catalog["native_names"])
	for i in range(locales.size()):
		var translation := Translation.new()
		translation.locale = locales[i]
		for key in catalog["messages"]:
			var row: Array = catalog["messages"][key]
			if row.size() != locales.size():
				push_error("Incomplete localization row: " + key)
				continue
			translation.add_message(key, str(row[i]))
		TranslationServer.add_translation(translation)
	var settings := ConfigFile.new()
	settings.load(preferences_path)
	set_language(str(settings.get_value("language", "locale", resolve_locale(OS.get_locale()))), false)

func resolve_locale(requested: String) -> String:
	var normalized := requested.replace("-", "_")
	if normalized in locales:
		return normalized
	if normalized.begins_with("zh"):
		return "zh_TW" if "TW" in normalized or "HK" in normalized or "Hant" in normalized else "zh_CN"
	if normalized.begins_with("pt"):
		return "pt_BR"
	var base := normalized.get_slice("_", 0)
	return base if base in locales else "en"

func set_language(code: String, persist: bool = true) -> void:
	current = resolve_locale(code)
	CJK_FONT = _regional_font(current)
	ThemeDB.fallback_font = CJK_FONT
	TranslationServer.set_locale(current)
	if persist:
		var settings := ConfigFile.new()
		settings.set_value("language", "locale", current)
		var result := settings.save(preferences_path)
		if result != OK:
			push_warning("Could not save language preference: " + error_string(result))
	changed.emit()

func _regional_font(code: String) -> Font:
	var filename: String=REGIONAL_FONTS.get(code,"NotoSansCJKsc-Regular.otf")
	if not regional_fonts.has(filename):
		regional_fonts[filename]=load("res://assets/fonts/"+filename)
	return regional_fonts[filename]

func text(key: String) -> String:
	return TranslationServer.translate(key)

func font(title: bool = false) -> Font:
	if title and not current.begins_with("zh") and current not in ["ja", "ko"]:
		return TITLE_FONT
	return CJK_FONT
