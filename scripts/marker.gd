extends Area2D
## Both markers use player-layer overlap. The main scene owns their game rules.

signal reached
var is_goal: bool = false
var active: bool = false
var clock: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(58, 100) if is_goal else Vector2(48, 76)
	collider.shape = rectangle
	collider.position.y = -40
	add_child(collider)
	body_entered.connect(func(body: Node2D) -> void:
		if body.get("controls_enabled") and not body.get("dead") and not active:
			active = true
			reached.emit()
			queue_redraw()
	)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if is_goal:
		draw_rect(Rect2(-42, -7, 84, 7), Color("657f71"))
		draw_line(Vector2(-28, -4), Vector2(-28, -79), Color("83998a"), 15, true)
		draw_line(Vector2(28, -4), Vector2(28, -79), Color("83998a"), 15, true)
		draw_arc(Vector2(0, -78), 28, PI, TAU, 24, Color("83998a"), 15, true)
		draw_arc(Vector2(0, -78), 28, PI, TAU, 24, Color("bdc9a5"), 3, true)
		draw_rect(Rect2(-19, -80, 38, 75), Color(0.93, 0.84, 0.52, 0.15 + sin(clock * 2) * 0.04))
		for i in range(5):
			var y := fposmod(clock * 18 + i * 17, 80)
			draw_circle(Vector2(sin(i * 3.3) * 15, -y - 8), 2, Color("f7dea0"))
	else:
		draw_line(Vector2.ZERO, Vector2(0, -78), Color("8b9a85"), 5, true)
		var sway := sin(clock * 3) * 4
		var cloth := Color("f5cf86") if active else Color("b0c9b6")
		draw_colored_polygon(PackedVector2Array([Vector2(3, -75), Vector2(39, -69 + sway), Vector2(31, -55 + sway), Vector2(3, -54)]), cloth)
		draw_circle(Vector2(0, -81), 5, Color("f6dfa1"))
		draw_circle(Vector2(0, -81), 12, Color(1, 0.85, 0.5, 0.12))
