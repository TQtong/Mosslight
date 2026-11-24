extends SceneTree
const QA=preload("res://scripts/qa_navigation.gd")
const PATH="user://qa_navigation_journey.json"
const SETTINGS="user://qa_navigation_settings.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_clean()
	var game=load("res://scenes/main.tscn").instantiate()
	game.profile_path=PATH
	game.settings_path=SETTINGS
	root.add_child(game)
	await QA.frames(self,4)
	var result: Dictionary=await QA.run(game)
	game.audio.stop_all()
	game.queue_free()
	await QA.frames(self,4)
	OS.delay_msec(250)
	_clean()
	quit(1 if result["failures"] else 0)

func _clean() -> void:
	for path in [PATH,SETTINGS,"user://qa_navigation_language.cfg"]:
		assert(path.begins_with("user://qa_"))
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
