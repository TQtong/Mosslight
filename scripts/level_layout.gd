extends RefCounted
## Level editor: coordinates are pixels, with Y increasing downward.
## Rect2(x, top_y, width, depth). Jump height is about 121px, range about 230px.
## Keep upward steps <= 65px and horizontal gaps <= 120px for a forgiving route.

const WIDTH: int = 4400
const SPAWN: Vector2 = Vector2(180, 560)
const CHECKPOINT: Vector2 = Vector2(1650, 515)
const FINISH: Vector2 = Vector2(4160, 475)
const MOVING_ISLAND: Rect2 = Rect2(3130, 425, 120, 160)
const MOVING_TRAVEL: float = 45.0
const SPIKES: Array[Vector2] = [Vector2(495, 560), Vector2(2760, 460)]

static func islands() -> Array[Rect2]:
	return [
		Rect2(-100, 560, 800, 210),
		Rect2(790, 510, 220, 160),
		Rect2(1100, 455, 240, 190),
		Rect2(1430, 515, 440, 190),
		Rect2(1980, 460, 200, 170),
		Rect2(2260, 400, 200, 170),
		Rect2(2550, 460, 450, 180),
		Rect2(3340, 390, 240, 180),
		Rect2(3690, 475, 650, 220),
	]

static func coins() -> Array[Vector2]:
	return [
		Vector2(300, 514), Vector2(395, 514), Vector2(530, 470),
		Vector2(820, 468), Vector2(915, 460),
		Vector2(1140, 413), Vector2(1240, 413),
		Vector2(1480, 473), Vector2(1580, 473), Vector2(1770, 473),
		Vector2(2020, 418), Vector2(2120, 418),
		Vector2(2300, 358), Vector2(2400, 358),
		Vector2(2590, 418), Vector2(2795, 370), Vector2(2930, 418),
		Vector2(3135, 362),
		Vector2(3380, 348), Vector2(3490, 348),
		Vector2(3730, 433), Vector2(3840, 433), Vector2(3970, 433),
	]
