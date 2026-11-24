extends Area2D
var clock: float = 0
var cooldown: float = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44,12)
	shape.shape = rect
	shape.position.y = -6
	add_child(shape)
	body_entered.connect(_bounce)

func _bounce(body: Node2D) -> void:
	if cooldown > 0 or not body.get("controls_enabled") or body.get("dead") or body.velocity.y < -50:
		return
	body.velocity.y = -800
	body.air_jump_left = true
	body.dash_ready = true
	cooldown = .25

func _process(delta: float) -> void:
	clock += delta
	cooldown = maxf(0,cooldown-delta)
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-12,-2),Vector2(12,-2),Color("5d7b6f"),5,true)
	draw_line(Vector2(-10,-5),Vector2(8,-9),Color("d2dbb0"),3,true)
	draw_line(Vector2(8,-9),Vector2(-8,-13),Color("d2dbb0"),3,true)
	draw_colored_polygon(PackedVector2Array([Vector2(-25,-16),Vector2(-10,-27),Vector2(13,-27),Vector2(25,-16)]),Color("b6d2a4"))
