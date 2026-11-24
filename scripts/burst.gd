extends Node2D
## Small deterministic particles, drawn without an external texture.

var age: float = 0.0
var tint: Color = Color("f7d58d")

func _process(delta: float) -> void:
	age += delta
	if age > 0.55:
		queue_free()
	queue_redraw()

func _draw() -> void:
	for i in range(9):
		var direction := Vector2.from_angle(i * TAU / 9.0)
		var at := direction * age * (60 + i * 7) + Vector2(0, age * age * 90)
		var color := tint
		color.a = maxf(0, 1.0 - age / 0.55)
		draw_circle(at, maxf(1, 3.2 - age * 4), color)
