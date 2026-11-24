extends SceneTree

var game
var failures: int = 0
var checks: int = 0
var had_save: bool = false
var original_save: PackedByteArray

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	had_save = FileAccess.file_exists("user://qa_smoke_test_settings.cfg")
	if had_save:
		original_save = FileAccess.get_file_as_bytes("user://qa_smoke_test_settings.cfg")
	game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://qa_smoke_test.json"
	game.settings_path="user://qa_smoke_test_settings.cfg"
	root.add_child(game)
	await frames(3)
	check(game.mode == "menu" and not game.player.controls_enabled, "Title screen gates movement")
	game.start_run()
	await frames(6)
	check(game.player.is_on_floor() and absf(game.player.position.y - 560) < 2, "Player lands on starting island")
	Input.action_press("move_right")
	await frames(24)
	Input.action_release("move_right")
	check(game.player.position.x > 270, "Horizontal input moves player")
	await frames(15)
	var full_height := await measure_jump(false)
	var short_height := await measure_jump(true)
	check(full_height > 100 and full_height < 125, "Full jump matches level budget: %.1fpx" % full_height)
	check(short_height < full_height * 0.7 and short_height > 20, "Tap jump is shorter: %.1fpx" % short_height)
	game.player.respawn(Vector2(180, 545))
	game.player.velocity.y = 200
	await frames(1)
	Input.action_press("jump")
	await frames(7)
	check(game.player.velocity.y < 0, "Buffered press before landing jumps on landing")
	Input.action_release("jump")
	game.player.respawn(Vector2(670, 560))
	await frames(4)
	Input.action_press("move_right")
	await frames(15)
	var off_edge: bool = game.player.position.x > 712 and not game.player.is_on_floor()
	Input.action_press("jump")
	await frames(2)
	check(off_edge and game.player.velocity.y < 0, "Coyote jump works after leaving edge")
	Input.action_release("jump")
	Input.action_release("move_right")
	var prior_coins: int = game.coins
	game.player.respawn(Vector2(915, 482))
	await frames(6)
	check(game.coins == prior_coins + 1, "Coin overlap increments score exactly once")
	await frames(10)
	check(game.coins == prior_coins + 1, "Collected coin cannot be counted again")
	game.player.respawn(Vector2(525, 560))
	await frames(4)
	check(game.player.dead and game.deaths == 1, "Spikes cause one death")
	await frames(32)
	check(not game.player.dead and absf(game.player.position.x - 180) < 2, "Death respawns at initial spawn")
	game.player.respawn(Vector2(1650, 515))
	await frames(5)
	check(game.checkpoint_active and game.respawn_at.x == 1680, "Checkpoint overlap changes spawn")
	game.player.position.y = 840
	await frames(4)
	await frames(32)
	check(not game.player.dead and absf(game.player.position.x - 1680) < 2 and game.deaths == 2, "Void death returns to checkpoint")
	var before: Vector2 = game.player.position
	var old_time: float = game.elapsed
	game.pause_run()
	Input.action_press("move_right")
	await frames(20)
	check(game.player.position.is_equal_approx(before) and game.elapsed == old_time, "Pause freezes physics and run timer")
	game.resume_run()
	await frames(10)
	check(game.player.position.x > before.x, "Resume restores controls")
	Input.action_release("move_right")
	var moving = game.world.get_node("MovingIsland")
	moving.clock = 0
	await frames(2)
	game.player.respawn(Vector2(moving.position.x + 60, 424))
	await frames(10)
	var relative_x: float = game.player.position.x - moving.position.x
	var old_platform_x: float = moving.position.x
	await frames(50)
	check(absf(moving.position.x - old_platform_x) > 15 and absf(game.player.position.x - moving.position.x - relative_x) < 6, "Moving platform carries standing player")
	game.player.respawn(Vector2(4160, 475))
	await frames(5)
	check(game.mode == "complete" and not game.player.controls_enabled, "Goal opens completion screen")
	check(game.best_seconds > 0, "Completion records best time")
	var saved = load("res://scripts/profile.gd").new(game.profile_path)
	saved.load_profile(12)
	check(float(saved.level_record(0).get("best_time", 0)) > 0, "Best time is persisted to disk")
	game.start_run()
	await frames(4)
	check(game.coins == 0 and game.deaths == 0 and not game.checkpoint_active and game.mode == "playing", "Restart resets run state")
	game.show_title()
	await frames(3)
	check(game.mode == "menu" and not game.player.controls_enabled, "Return to title stops gameplay")
	if had_save:
		var file := FileAccess.open("user://qa_smoke_test_settings.cfg", FileAccess.WRITE)
		file.store_buffer(original_save)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_smoke_test_settings.cfg"))
	print("RESULT: %d/%d checks passed" % [checks - failures, checks])
	game.queue_free()
	await frames(3)
	# Fast fixed-FPS tests finish before the audio mixing thread drains playback.
	OS.delay_msec(180)
	await frames(3)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_smoke_test.json" + suffix))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_smoke_test_settings.cfg"+suffix))
	quit(1 if failures else 0)

func measure_jump(short_press: bool) -> float:
	Input.action_release("jump")
	game.player.respawn(Vector2(200, 560))
	await frames(5)
	Input.action_press("jump")
	var min_y: float = 560
	for i in range(55):
		await frames(1)
		min_y = minf(min_y, game.player.position.y)
		if short_press and i == 2:
			Input.action_release("jump")
	Input.action_release("jump")
	return 560 - min_y

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS " if condition else "FAIL ") + description)
