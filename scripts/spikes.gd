extends Area2D

var width: float = 70.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(width - 12, 16)
	collider.shape = rectangle
	collider.position = Vector2(width / 2, -8)
	add_child(collider)
	body_entered.connect(func(body: Node2D) -> void:
		if body.has_method("die"):
			body.die()
	)
	queue_redraw()

func _draw() -> void:
	var count := int(width / 18)
	for i in range(count):
		var x := i * width / count
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 9, -24), Vector2(x + 18, 0)]), Color("8b6060"))
		draw_line(Vector2(x + 9, -22), Vector2(x + 16, -2), Color("d9a08b"), 2, true)
