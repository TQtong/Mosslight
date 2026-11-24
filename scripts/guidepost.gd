extends Node2D
## A world sign carries an icon; the nearby HUD supplies localized, rebound text.
var kind: String="jump"
var highlighted: bool=false

func _draw() -> void:
	draw_line(Vector2(0,-4),Vector2(0,-105),Color("665a3e"),7,true)
	draw_line(Vector2(-3,-10),Vector2(-3,-103),Color("a79161"),2,true)
	draw_set_transform(Vector2(0,-30))
	var board:=PackedVector2Array([Vector2(-31,-84),Vector2(25,-84),Vector2(36,-65),Vector2(25,-46),Vector2(-31,-46)])
	draw_colored_polygon(board,Color("5a5238"))
	draw_polyline(board+PackedVector2Array([board[0]]),Color("e4c58b") if highlighted else Color("b49a64"),2,true)
	var ink:=Color("ffe5a2") if highlighted else Color("d8cf9d")
	if kind=="relic":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-79),Vector2(9,-65),Vector2(0,-51),Vector2(-9,-65)]),ink)
	elif kind=="checkpoint":
		draw_line(Vector2(-8,-52),Vector2(-8,-78),ink,3,true)
		draw_colored_polygon(PackedVector2Array([Vector2(-6,-78),Vector2(14,-73),Vector2(-6,-65)]),ink)
	elif kind=="moth":
		draw_circle(Vector2(0,-65),5,ink)
		draw_colored_polygon(PackedVector2Array([Vector2(-3,-63),Vector2(-20,-76),Vector2(-17,-56)]),ink)
		draw_colored_polygon(PackedVector2Array([Vector2(3,-63),Vector2(20,-76),Vector2(17,-56)]),ink)
	elif kind=="crumble":
		draw_line(Vector2(-21,-55),Vector2(21,-55),ink,3,true)
		draw_polyline(PackedVector2Array([Vector2(3,-78),Vector2(-3,-69),Vector2(4,-65),Vector2(-2,-55)]),ink,3,true)
	elif kind in ["dash","move","mover"]:
		draw_line(Vector2(-18,-65),Vector2(17,-65),ink,3,true)
		draw_polyline(PackedVector2Array([Vector2(7,-75),Vector2(19,-65),Vector2(7,-55)]),ink,3,true)
	else:
		draw_line(Vector2(0,-53),Vector2(0,-76),ink,3,true)
		draw_polyline(PackedVector2Array([Vector2(-10,-67),Vector2(0,-78),Vector2(10,-67)]),ink,3,true)
		if kind in ["double","spring"]: draw_line(Vector2(-12,-53),Vector2(12,-53),ink,2,true)
	draw_set_transform(Vector2.ZERO)
