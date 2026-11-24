extends Area2D

signal collected(at: Vector2)
var clock: float = 0.0
var taken: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15
	collider.shape = circle
	add_child(collider)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if taken or not body.get("controls_enabled") or body.get("dead"):
		return
	taken = true
	collected.emit(global_position)
	queue_free()

func _draw() -> void:
	var offset := Vector2(0, sin(clock * 3.2 + position.x) * 4)
	draw_circle(offset, 19, Color(1.0, 0.85, 0.49, 0.08))
	draw_circle(offset, 12, Color("b98a49"))
	draw_circle(offset + Vector2(0, -1), 10.5, Color("f6d48b"))
	draw_arc(offset + Vector2(0, -1), 7, -2.5, 0.5, 20, Color("fff0b9"), 1.5, true)
	draw_colored_polygon(PackedVector2Array([offset + Vector2(0, -7), offset + Vector2(4, -1), offset + Vector2(0, 5), offset + Vector2(-4, -1)]), Color("b88348"))
